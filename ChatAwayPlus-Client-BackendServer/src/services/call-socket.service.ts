import { Server, Socket } from "socket.io";
import { getAgoraAppId } from "./agora.service";
import CallLog from "../db/models/call-log.model";
import User from "../db/models/user.model";
import { Op } from "sequelize";

// =============================================================================
// ACTIVE CALLS MAP — Centralized registry for call state management
// =============================================================================
interface ActiveCall {
  callId: string;
  callerId: string;
  calleeId: string;
  channelName: string;
  callType: "voice" | "video";
  status: "ringing" | "accepted" | "rejected" | "ended" | "missed";
  createdAt: number;     // Unix timestamp ms
  expiresAt: number;     // Unix timestamp ms
  timeoutId?: NodeJS.Timeout;
  retryIntervalId?: NodeJS.Timeout;
  ackReceived: boolean;
}

const activeCalls = new Map<string, ActiveCall>();

// =============================================================================
// PRESENCE MAPS — Support multi-device and lifecycle management
// =============================================================================
const userSockets = new Map<string, Set<string>>(); // userId -> Set<socketId>
const socketToUser = new Map<string, string>();      // socketId -> userId

const CALL_TIMEOUT_MS = 30_000;       // 30s — missed call timeout
const CALL_EXPIRY_MS = 35_000;        // 35s — call invite expires
const INCOMING_RETRY_INTERVAL = 3000; // 3s between retries
const INCOMING_MAX_RETRIES = 3;       // Max retries for call:incoming

// =============================================================================
// HELPERS
// =============================================================================
const debugLog = (msg: string) => console.log(`[CALL] ${msg}`);

const isUserOnline = (userId: string): boolean => {
  const sockets = userSockets.get(userId);
  return !!sockets && sockets.size > 0;
};

const isTerminalState = (status: string): boolean => 
  ["accepted", "rejected", "ended", "missed"].includes(status);

const isCallExpired = (call: ActiveCall): boolean => 
  Date.now() > call.expiresAt;

/**
 * Clear timers but keep registry entry for a cooldown period to ignore stale events
 */
const cleanupCallTimers = (callId: string) => {
  const call = activeCalls.get(callId);
  if (call) {
    if (call.timeoutId) {
      clearTimeout(call.timeoutId);
      call.timeoutId = undefined;
    }
    if (call.retryIntervalId) {
      clearInterval(call.retryIntervalId);
      call.retryIntervalId = undefined;
    }
    
    // Cooldown before final deletion to prevent duplicate initiates or late events from creating ghosts
    setTimeout(() => {
    activeCalls.delete(callId);
    }, 60_000); 
  }
};

const stopRetryLoop = (callId: string) => {
  const call = activeCalls.get(callId);
  if (call?.retryIntervalId) {
    clearInterval(call.retryIntervalId);
    call.retryIntervalId = undefined;
    debugLog(`Stopped retry loop for call ${callId}`);
  }
};

const startRetryLoop = (callId: string, targetUserId: string, signalData: any, io: Server) => {
  let attempts = 0;
  const maxAttempts = 10;
  const interval = setInterval(() => {
    const call = activeCalls.get(callId);
    // If call is gone, or in terminal state, or max attempts reached
    if (!call || isTerminalState(call.status) || attempts >= maxAttempts) {
      clearInterval(interval);
      if (call) call.retryIntervalId = undefined;
      return;
    }
    attempts++;
    debugLog(`Retrying incoming_call for ${targetUserId} (attempt ${attempts})`);
    io.to(targetUserId).emit('call:incoming', signalData);
  }, 3000);

  const call = activeCalls.get(callId);
  if (call) {
    call.retryIntervalId = interval;
  }
};

export const setupCallHandlers = (io: Server, socket: Socket) => {

  // ---------------------------------------------------------------------------
  // PRESENCE: JOIN SIGNALING ROOM
  // ---------------------------------------------------------------------------
  socket.on("join", (userId: string) => {
    if (!userId) return;

    // Clean up old socket associations
    const oldUserId = socketToUser.get(socket.id);
    if (oldUserId && oldUserId !== userId) {
      userSockets.get(oldUserId)?.delete(socket.id);
    }

    // Register new association
    if (!userSockets.has(userId)) {
      userSockets.set(userId, new Set());
    }
    userSockets.get(userId)!.add(socket.id);
    socketToUser.set(socket.id, userId);

    socket.join(userId);
    console.log(`[CALL] join: user=${userId} socket=${socket.id} (total for user: ${userSockets.get(userId)!.size})`);
  });

  // ---------------------------------------------------------------------------
  // CALL:INITIATE — Caller starts a call
  // ---------------------------------------------------------------------------
  socket.on("call:initiate", async (data: {
    callId: string;
    callerId: string;
    calleeId: string;
    callType: "voice" | "video";
    channelName: string;
    callerName?: string;
    callerProfilePic?: string;
  }) => {
    const { callId, callerId, calleeId, callType, channelName } = data;
    const now = Date.now();

    console.log(`[CALL] initiate: callId=${callId} from=${callerId} to=${calleeId}`);

    if (!callerId || !calleeId || !channelName || !callId) {
      socket.emit("call:error", { message: "Invalid call data", callId });
      return;
    }

    // Dedup guard
    if (activeCalls.has(callId)) {
      console.log(`[CALL] initiate IGNORED: duplicate callId=${callId}`);
      return;
    }

    // Busy check
    let isBusy = false;
    for (const [, call] of activeCalls) {
      if ((call.calleeId === calleeId || call.callerId === calleeId) && !isTerminalState(call.status)) {
        isBusy = true;
        break;
      }
    }

    if (isBusy) {
      console.log(`[CALL] initiate: callee ${calleeId} is BUSY`);
      socket.emit("call:busy", { callId });
      await CallLog.findOrCreate({
        where: { callId },
        defaults: { callId, callerId, calleeId, callType, channelName, status: "busy", startedAt: new Date() },
      });
      return;
    }

    // Online check
    if (!isUserOnline(calleeId)) {
      console.log(`[CALL] initiate: callee ${calleeId} is OFFLINE`);
      socket.emit("call:unavailable", { callId });
      await CallLog.findOrCreate({
        where: { callId },
        defaults: { callId, callerId, calleeId, callType, channelName, status: "unavailable", startedAt: new Date(), endedAt: new Date() },
      });
      return;
    }

    const expiresAt = now + CALL_EXPIRY_MS;
    const activeCall: ActiveCall = {
      callId, callerId, calleeId, channelName, callType,
      status: "ringing",
      createdAt: now,
      expiresAt,
      ackReceived: false,
    };

    // Set missed call timeout
    activeCall.timeoutId = setTimeout(async () => {
      const call = activeCalls.get(callId);
      if (call && call.status === "ringing") {
        console.log(`[CALL] timeout: callId=${callId} — marking as MISSED`);
        call.status = "missed";
        
        io.to(callerId).emit("call:missed", { callId, status: "missed", timestamp: Date.now() });
        io.to(calleeId).emit("call:missed", { callId, status: "missed", timestamp: Date.now() });
        
        await CallLog.update({ status: "missed", endedAt: new Date() }, { where: { callId } }).catch(() => {});
        cleanupCallTimers(callId);
      }
    }, CALL_TIMEOUT_MS);

    activeCalls.set(callId, activeCall);

    await CallLog.findOrCreate({
      where: { callId },
      defaults: { callId, callerId, calleeId, callType, channelName, status: "ringing", startedAt: new Date() },
    });

    // Confirm ringing to caller
    socket.emit("call:ringing", { callId, channelName, appId: getAgoraAppId() });

    // Emit incoming to callee (with retries)
    const incomingPayload = {
      callId, callerId,
      callerName: data.callerName || "Someone",
      callerProfilePic: data.callerProfilePic || null,
      callType, channelName,
      appId: getAgoraAppId(),
      createdAt: now,
      expiresAt,
    };

    startRetryLoop(callId, calleeId, incomingPayload, io);
  });

  // ---------------------------------------------------------------------------
  // CALL:INCOMING_ACK — Callee confirms receipt (stops retries)
  // ---------------------------------------------------------------------------
  socket.on("call:incoming_ack", ({ callId }) => {
    const call = activeCalls.get(callId);
    if (call && !isTerminalState(call.status)) {
      debugLog(`ACK received for call ${callId} — stopping retries`);
      stopRetryLoop(callId);
    }
  });

  // ---------------------------------------------------------------------------
  // CALL:ACCEPT — Callee accepts
  // ---------------------------------------------------------------------------
  socket.on("call:accept", async (data: { callId: string; callerId: string; calleeId: string }) => {
    const { callId, callerId, calleeId } = data;
    const call = activeCalls.get(callId);

    if (!call) {
      console.log(`[CALL] accept: callId=${callId} NOT FOUND (stale event)`);
      return;
    }

    if (isTerminalState(call.status)) {
      console.log(`[CALL] accept IGNORED: call ${callId} is already ${call.status}`);
      return;
    }

    console.log(`[CALL] accepted: callId=${callId}`);
    call.status = "accepted";
    cleanupCallTimers(callId);

    const result = { callId, status: "accepted", channelName: call.channelName, timestamp: Date.now() };
    io.to(callerId).emit("call:accepted", result);
    io.to(calleeId).emit("call:accepted", result);

    await CallLog.update({ status: "accepted", answeredAt: new Date() }, { where: { callId } }).catch(() => {});
  });

  // ---------------------------------------------------------------------------
  // CALL:REJECT — Callee rejects
  // ---------------------------------------------------------------------------
  socket.on("call:reject", async (data: { callId: string; callerId: string }) => {
    const { callId, callerId } = data;
    const call = activeCalls.get(callId);

    if (!call || isTerminalState(call.status)) {
      console.log(`[CALL] reject IGNORED: callId=${callId}`);
      return;
    }

    console.log(`[CALL] rejected: callId=${callId}`);
    call.status = "rejected";
    cleanupCallTimers(callId);

    const result = { callId, status: "rejected", timestamp: Date.now() };
    io.to(callerId).emit("call:rejected", result);
    io.to(call.calleeId).emit("call:rejected", result);

    await CallLog.update({ status: "rejected", endedAt: new Date() }, { where: { callId } }).catch(() => {});
  });

  // ---------------------------------------------------------------------------
  // CALL:CANCEL — Caller cancels before accept
  // ---------------------------------------------------------------------------
  socket.on("call:cancel", async (data: { callId: string; calleeId: string }) => {
    const { callId, calleeId } = data;
    const call = activeCalls.get(callId);

    if (!call || isTerminalState(call.status)) {
      console.log(`[CALL] cancel IGNORED: callId=${callId}`);
      return;
    }

    console.log(`[CALL] cancelled: callId=${callId}`);
    call.status = "ended";
    cleanupCallTimers(callId);

    const result = { callId, status: "ended", reason: "cancelled", timestamp: Date.now() };
    io.to(call.callerId).emit("call:ended", result);
    io.to(calleeId).emit("call:ended", result);

    await CallLog.update({ status: "ended", endedAt: new Date() }, { where: { callId } }).catch(() => {});
  });

  // ---------------------------------------------------------------------------
  // CALL:END — Either party ends an ongoing call
  // ---------------------------------------------------------------------------
  socket.on("call:end", async (data: { callId: string; otherUserId: string }) => {
    const { callId, otherUserId } = data;
    const call = activeCalls.get(callId);

    if (!call || call.status === "ended") {
       io.to(otherUserId).emit("call:ended", { callId, status: "ended", timestamp: Date.now() });
       return;
    }

    console.log(`[CALL] ended: callId=${callId}`);
    call.status = "ended";
    cleanupCallTimers(callId);

    const result = { callId, status: "ended", timestamp: Date.now() };
    io.to(call.callerId).emit("call:ended", result);
    io.to(call.calleeId).emit("call:ended", result);

    try {
      const log = await CallLog.findOne({ where: { callId } });
      const endedAt = new Date();
      let duration = 0;
      if (log && log.answeredAt) {
        duration = Math.floor((endedAt.getTime() - log.answeredAt.getTime()) / 1000);
      }
      await CallLog.update(
        { status: "ended", endedAt, duration },
        { where: { callId, status: { [Op.notIn]: ["ended", "rejected", "missed"] } } }
      );
    } catch (error) {}
  });

  // ---------------------------------------------------------------------------
  // CALL:STATE — Reconnection state recovery
  // ---------------------------------------------------------------------------
  socket.on("call:state", (data: { userId: string }) => {
    const { userId } = data;
    let found: ActiveCall | null = null;
    for (const [, call] of activeCalls) {
      if ((call.callerId === userId || call.calleeId === userId) && !isTerminalState(call.status)) {
        found = call;
        break;
      }
    }

    if (found && !isCallExpired(found)) {
      socket.emit("call:state_response", {
        activeCall: {
          callId: found.callId,
          callerId: found.callerId,
          calleeId: found.calleeId,
          channelName: found.channelName,
          callType: found.callType,
          status: found.status,
          createdAt: found.createdAt,
          expiresAt: found.expiresAt,
        }
      });
    } else {
      socket.emit("call:state_response", { activeCall: null });
    }
  });

  // ---------------------------------------------------------------------------
  // HISTORY & STATISTICS
  // ---------------------------------------------------------------------------
  socket.on("get-call-history", async (data: { limit?: number; offset?: number; callType?: string; status?: string }) => {
    try {
      const userId = socketToUser.get(socket.id);
      if (!userId) return;

      const { limit = 50, offset = 0, callType, status } = data;
      const whereClause: any = {
        [Op.or]: [{ callerId: userId }, { calleeId: userId }]
      };
      if (callType) whereClause.callType = callType;
      if (status) whereClause.status = status;

      const logs = await CallLog.findAll({
        where: whereClause,
        limit, offset, order: [['createdAt', 'DESC']],
        include: [
          { model: User, as: 'caller', attributes: ['id', 'firstName', 'lastName', 'chat_picture', 'mobileNo'] },
          { model: User, as: 'callee', attributes: ['id', 'firstName', 'lastName', 'chat_picture', 'mobileNo'] }
        ]
      });

      const transformed = logs.map(log => {
        const d = log.toJSON() as any;
        const isCaller = d.callerId === userId;
        d.direction = isCaller ? 'outgoing' : 'incoming';
        d.otherUser = isCaller ? d.callee : d.caller;
        return d;
      });

      socket.emit("call-history-response", { success: true, data: transformed });
    } catch (e) {
      socket.emit("call-history-error", { message: "Failed" });
    }
  });

  socket.on("get-missed-calls-count", async () => {
    try {
      const userId = socketToUser.get(socket.id);
      if (!userId) return;
      const count = await CallLog.count({ where: { calleeId: userId, status: 'missed' } });
      socket.emit("missed-calls-count-response", { success: true, count });
    } catch (e) {}
  });

  // ---------------------------------------------------------------------------
  // DISCONNECT CLEANUP — Sync across devices and handle drops
  // ---------------------------------------------------------------------------
  socket.on("disconnect", () => {
    const userId = socketToUser.get(socket.id);
    if (!userId) return;

    const sockets = userSockets.get(userId);
    if (sockets) {
      sockets.delete(socket.id);
      if (sockets.size === 0) {
        userSockets.delete(userId);
        console.log(`[CALL] disconnect: user ${userId} is now FULLY OFFLINE`);
      }
    }

    for (const [callId, call] of activeCalls) {
      if ((call.callerId === userId || call.calleeId === userId) && !isTerminalState(call.status)) {
        const isFullyOffline = !userSockets.has(userId);
        const isRinging = call.status === "ringing";

        if (isFullyOffline || (isRinging && call.callerId === userId)) {
          console.log(`[CALL] disconnect: auto-ending callId=${callId} due to ${userId} drop`);
          
          const finalStatus = isRinging ? "missed" : "ended";
          call.status = finalStatus;
          cleanupCallTimers(callId);

          const result = { callId, status: finalStatus, reason: "disconnected", timestamp: Date.now() };
          io.to(call.callerId).emit(`call:${finalStatus}`, result);
          io.to(call.calleeId).emit(`call:${finalStatus}`, result);

          CallLog.update({ status: finalStatus, endedAt: new Date() }, { where: { callId } }).catch(() => {});
        }
      }
    }
    socketToUser.delete(socket.id);
  });
};
