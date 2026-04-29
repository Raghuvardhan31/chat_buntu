import { Server, Socket } from "socket.io";
import { getAgoraAppId } from "./agora.service";
import CallLog from "../db/models/call-log.model";
import User from "../db/models/user.model";
import { Op } from "sequelize";

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVE CALLS MAP — In-memory state for all active/pending calls
// ═══════════════════════════════════════════════════════════════════════════════
interface ActiveCall {
  callId: string;
  callerId: string;
  calleeId: string;
  channelName: string;
  callType: "voice" | "video";
  status: "initiated" | "ringing" | "accepted" | "ended" | "missed" | "rejected";
  createdAt: number;     // Unix timestamp ms
  expiresAt: number;     // Unix timestamp ms
  timeoutId?: NodeJS.Timeout;
  retryCount: number;
  retryTimerId?: NodeJS.Timeout;
  ackReceived: boolean;
}

const activeCalls = new Map<string, ActiveCall>();

// Map socketId → userId so we can clean up on disconnect
const socketUserMap = new Map<string, string>();

const CALL_TIMEOUT_MS = 30_000;       // 30s — missed call timeout
const CALL_EXPIRY_MS = 35_000;        // 35s — call invite expires after this
const INCOMING_RETRY_INTERVAL = 3000; // 3s between retries
const INCOMING_MAX_RETRIES = 3;       // Max retries for call:incoming

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER: Check if a call has expired
// ═══════════════════════════════════════════════════════════════════════════════
function isCallExpired(call: ActiveCall): boolean {
  return Date.now() > call.expiresAt;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER: Check if a call is in a terminal state
// ═══════════════════════════════════════════════════════════════════════════════
function isTerminalState(status: string): boolean {
  return ["ended", "missed", "rejected", "busy", "unavailable"].includes(status);
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER: Clean up call (clear timers, remove from map)
// ═══════════════════════════════════════════════════════════════════════════════
function cleanupCall(callId: string): void {
  const call = activeCalls.get(callId);
  if (!call) return;
  if (call.timeoutId) clearTimeout(call.timeoutId);
  if (call.retryTimerId) clearTimeout(call.retryTimerId);
  activeCalls.delete(callId);
}

export const setupCallHandlers = (io: Server, socket: Socket) => {

  // ═════════════════════════════════════════════════════════════════════════════
  // TRACK USER → SOCKET MAPPING
  // ═════════════════════════════════════════════════════════════════════════════
  socket.on("join", (userId: string) => {
    if (userId) {
      socketUserMap.set(socket.id, userId);
      console.log(`[CALL] socket ${socket.id} registered as user ${userId}`);
    }
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // CALL:INITIATE — Caller starts a call
  // ═════════════════════════════════════════════════════════════════════════════
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

    console.log(`[CALL] initiate callId=${callId} from=${callerId} to=${calleeId} type=${callType} channel=${channelName}`);

    if (!callerId || !calleeId || !channelName || !callId) {
      console.log(`[CALL] initiate REJECTED — invalid data`);
      socket.emit("call:error", { message: "Invalid call data", callId });
      return;
    }

    // Track socket user
    socketUserMap.set(socket.id, callerId);

    // ── Dedup guard ──
    if (activeCalls.has(callId)) {
      console.log(`[CALL] initiate IGNORED — duplicate callId=${callId}`);
      return;
    }

    try {
      // ── Busy check ──
      let isBusy = false;
      for (const [, call] of activeCalls) {
        if ((call.calleeId === calleeId || call.callerId === calleeId) && !isTerminalState(call.status)) {
          isBusy = true;
          break;
        }
      }

      if (isBusy) {
        console.log(`[CALL] initiate — callee ${calleeId} is BUSY`);
        socket.emit("call:busy", { callId });
        await CallLog.findOrCreate({
          where: { callId },
          defaults: { callId, callerId, calleeId, callType, channelName, status: "busy", startedAt: new Date() },
        });
        return;
      }

      // ── Create DB log (idempotent) ──
      const [, created] = await CallLog.findOrCreate({
        where: { callId },
        defaults: { callId, callerId, calleeId, callType, channelName, status: "initiated", startedAt: new Date() },
      });

      if (!created) {
        console.log(`[CALL] initiate IGNORED — DB record already exists for callId=${callId}`);
        return;
      }

      // ── Create active call entry with expiry ──
      const expiresAt = now + CALL_EXPIRY_MS;
      const activeCall: ActiveCall = {
        callId, callerId, calleeId, channelName, callType,
        status: "initiated",
        createdAt: now,
        expiresAt,
        retryCount: 0,
        ackReceived: false,
      };

      // ── Set missed call timeout ──
      activeCall.timeoutId = setTimeout(async () => {
        const call = activeCalls.get(callId);
        if (call && !isTerminalState(call.status)) {
          console.log(`[CALL] timeout callId=${callId} — marking as missed`);
          call.status = "missed";
          await CallLog.update({ status: "missed", endedAt: new Date() }, { where: { callId } }).catch(() => {});
          io.to(callerId).emit("call:missed", { callId });
          io.to(calleeId).emit("call:missed", { callId });
          cleanupCall(callId);
        }
      }, CALL_TIMEOUT_MS);

      activeCalls.set(callId, activeCall);

      // ── Check if callee is online ──
      const calleeRoom = io.sockets.adapter.rooms.get(calleeId);
      if (!calleeRoom || calleeRoom.size === 0) {
        console.log(`[CALL] initiate — callee ${calleeId} is OFFLINE`);
        cleanupCall(callId);
        socket.emit("call:unavailable", { callId });
        await CallLog.update({ status: "unavailable", endedAt: new Date() }, { where: { callId } });
        return;
      }

      // ── Update status to ringing ──
      activeCall.status = "ringing";
      await CallLog.update({ status: "ringing" }, { where: { callId } });

      // ── Send ack to caller ──
      socket.emit("call:ringing", { callId, channelName, appId: getAgoraAppId() });
      console.log(`[CALL] ringing emitted to caller ${callerId}`);

      // ── Build incoming payload (with timestamps) ──
      const incomingPayload = {
        callId,
        callerId,
        callerName: data.callerName || "Someone",
        callerProfilePic: data.callerProfilePic || null,
        callType,
        channelName,
        appId: getAgoraAppId(),
        createdAt: now,
        expiresAt,
      };

      // ── Emit call:incoming to callee (with retry logic) ──
      const emitIncoming = () => {
        const call = activeCalls.get(callId);
        if (!call || isTerminalState(call.status)) return;

        console.log(`[CALL] incoming emitted to callee ${calleeId} (attempt ${(call.retryCount || 0) + 1})`);
        io.to(calleeId).emit("call:incoming", incomingPayload);

        // Schedule retry if no ack
        if (call.retryCount < INCOMING_MAX_RETRIES) {
          call.retryTimerId = setTimeout(() => {
            const c = activeCalls.get(callId);
            if (c && !c.ackReceived && !isTerminalState(c.status)) {
              c.retryCount++;
              console.log(`[CALL] incoming RETRY #${c.retryCount} for callId=${callId}`);
              emitIncoming();
            }
          }, INCOMING_RETRY_INTERVAL);
        }
      };

      emitIncoming();

    } catch (error: any) {
      console.error(`[CALL] initiate ERROR:`, error);
      socket.emit("call:error", { message: "Internal server error", callId, detail: error?.message || String(error) });
    }
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // CALL:INCOMING_ACK — Callee acknowledges receiving the incoming call
  // ═════════════════════════════════════════════════════════════════════════════
  socket.on("call:incoming_ack", (data: { callId: string }) => {
    const { callId } = data;
    const call = activeCalls.get(callId);
    if (call) {
      call.ackReceived = true;
      if (call.retryTimerId) {
        clearTimeout(call.retryTimerId);
        call.retryTimerId = undefined;
      }
      console.log(`[CALL] incoming ack received for callId=${callId}`);
    }
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // CALL:ACCEPT — Callee accepts the call
  // ═════════════════════════════════════════════════════════════════════════════
  socket.on("call:accept", async (data: { callId: string; callerId: string; calleeId: string }) => {
    const { callId, callerId, calleeId } = data;
    const call = activeCalls.get(callId);

    console.log(`[CALL] accepted callId=${callId} callerId=${callerId} calleeId=${calleeId} found=${!!call}`);

    if (call) {
      // ── Guard: already in terminal state ──
      if (isTerminalState(call.status)) {
        console.log(`[CALL] accept REJECTED — call ${callId} is already ${call.status}`);
        socket.emit("call:ended", { callId, reason: `Call already ${call.status}` });
        return;
      }

      // ── Guard: expired ──
      if (isCallExpired(call)) {
        console.log(`[CALL] accept REJECTED — call ${callId} has expired`);
        call.status = "missed";
        cleanupCall(callId);
        await CallLog.update({ status: "missed", endedAt: new Date() }, { where: { callId } }).catch(() => {});
        socket.emit("call:ended", { callId, reason: "Call expired" });
        io.to(callerId).emit("call:missed", { callId });
        return;
      }

      // ── Clear timeout and retry timers ──
      if (call.timeoutId) clearTimeout(call.timeoutId);
      call.timeoutId = undefined;
      if (call.retryTimerId) clearTimeout(call.retryTimerId);
      call.retryTimerId = undefined;

      call.status = "accepted";

      try {
        await CallLog.update({ status: "accepted", answeredAt: new Date() }, { where: { callId } });
        io.to(callerId).emit("call:accepted", { callId, channelName: call.channelName });
        console.log(`[CALL] accepted emitted to caller ${callerId} channel=${call.channelName}`);
      } catch (error) {
        console.error(`[CALL] accept ERROR:`, error);
      }
    } else {
      console.log(`[CALL] accept — no active call for callId=${callId} (may have timed out)`);
      // Still try to notify caller
      io.to(callerId).emit("call:accepted", { callId, channelName: `chan_${callId}` });
    }
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // CALL:REJECT — Callee rejects the call
  // ═════════════════════════════════════════════════════════════════════════════
  socket.on("call:reject", async (data: { callId: string; callerId: string }) => {
    const { callId, callerId } = data;
    const call = activeCalls.get(callId);

    console.log(`[CALL] rejected callId=${callId} by callee`);

    if (call && !isTerminalState(call.status)) {
      call.status = "rejected";
      cleanupCall(callId);
      try {
        await CallLog.update({ status: "rejected", endedAt: new Date() }, { where: { callId } });
      } catch (error) {}
    } else {
      // Still clean up even if not found
      cleanupCall(callId);
    }

    io.to(callerId).emit("call:rejected", { callId });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // CALL:END — Either party ends the call
  // ═════════════════════════════════════════════════════════════════════════════
  socket.on("call:end", async (data: { callId: string; otherUserId: string }) => {
    const { callId, otherUserId } = data;
    const call = activeCalls.get(callId);

    console.log(`[CALL] ended callId=${callId} otherUserId=${otherUserId}`);

    if (call && !isTerminalState(call.status)) {
      call.status = "ended";
    }

    cleanupCall(callId);

    try {
      const log = await CallLog.findOne({ where: { callId } });
      const endedAt = new Date();
      let duration = 0;
      if (log && log.answeredAt) {
        duration = Math.floor((endedAt.getTime() - log.answeredAt.getTime()) / 1000);
      }
      await CallLog.update(
        { status: "ended", endedAt, duration },
        { where: { callId, status: { [Op.notIn]: ["ended", "rejected", "missed", "busy", "unavailable"] } } }
      );
    } catch (error) {}

    // Notify the OTHER user
    io.to(otherUserId).emit("call:ended", { callId });
    console.log(`[CALL] ended emitted to ${otherUserId}`);
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // CALL:STATE — Query current call state (for reconnection recovery)
  // Client sends { userId } and receives current active call info or null
  // ═════════════════════════════════════════════════════════════════════════════
  socket.on("call:state", (data: { userId: string }) => {
    const { userId } = data;
    if (!userId) {
      socket.emit("call:state_response", { activeCall: null });
      return;
    }

    // Find any active call involving this user
    let found: ActiveCall | null = null;
    for (const [, call] of activeCalls) {
      if ((call.callerId === userId || call.calleeId === userId) && !isTerminalState(call.status)) {
        found = call;
        break;
      }
    }

    if (found && !isCallExpired(found)) {
      console.log(`[CALL] state query — found active call ${found.callId} status=${found.status} for user ${userId}`);
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
      // If expired, clean up
      if (found && isCallExpired(found)) {
        console.log(`[CALL] state query — call ${found.callId} expired, cleaning up`);
        cleanupCall(found.callId);
      }
      socket.emit("call:state_response", { activeCall: null });
    }
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // CALL:BUSY — Callee is already in another call
  // ═════════════════════════════════════════════════════════════════════════════
  socket.on("call:busy", async (data: { callId: string; callerId: string }) => {
    const { callId, callerId } = data;
    console.log(`[CALL] busy callId=${callId}`);

    const call = activeCalls.get(callId);
    if (call) {
      call.status = "ended";
      cleanupCall(callId);
    }

    io.to(callerId).emit("call:unavailable", { callId });
    await CallLog.update(
      { status: "busy", endedAt: new Date() },
      { where: { callId, status: { [Op.notIn]: ["ended", "rejected", "missed"] } } }
    ).catch(() => {});
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // HISTORY HANDLERS
  // ═════════════════════════════════════════════════════════════════════════════
  socket.on("get-call-history", async (data: { limit?: number; offset?: number; callType?: string; status?: string }) => {
    try {
      const userId = (socket as any).userId || socketUserMap.get(socket.id);
      if (!userId) return;

      const { limit = 50, offset = 0, callType, status } = data;
      const whereClause: any = {
        [Op.or]: [{ callerId: userId }, { calleeId: userId }]
      };
      if (callType) whereClause.callType = callType;
      if (status) whereClause.status = status;

      const logs = await CallLog.findAll({
        where: whereClause,
        limit,
        offset,
        order: [['createdAt', 'DESC']],
        include: [
          { model: User, as: 'caller', attributes: ['id', 'firstName', 'lastName', 'chat_picture', 'mobileNo'] },
          { model: User, as: 'callee', attributes: ['id', 'firstName', 'lastName', 'chat_picture', 'mobileNo'] }
        ]
      });

      const transformedLogs = logs.map(log => {
        const logData = log.toJSON() as any;
        const isCaller = logData.callerId === userId;
        logData.direction = isCaller ? 'outgoing' : 'incoming';
        logData.otherUser = isCaller ? logData.callee : logData.caller;
        return logData;
      });

      socket.emit("call-history-response", { success: true, data: transformedLogs });
    } catch (error) {
      console.error("[CALL] get-call-history ERROR:", error);
      socket.emit("call-history-error", { message: "Failed to fetch history" });
    }
  });

  socket.on("get-missed-calls-count", async () => {
    try {
      const userId = (socket as any).userId || socketUserMap.get(socket.id);
      if (!userId) return;
      const count = await CallLog.count({
        where: { calleeId: userId, status: 'missed' }
      });
      socket.emit("missed-calls-count-response", { success: true, count });
    } catch (error) {}
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // DISCONNECT CLEANUP — Critical for reliability!
  // ═════════════════════════════════════════════════════════════════════════════
  socket.on("disconnect", () => {
    const userId = socketUserMap.get(socket.id);
    console.log(`[CALL] disconnect socket=${socket.id} user=${userId || 'unknown'}`);

    if (!userId) {
      socketUserMap.delete(socket.id);
      return;
    }

    // Find all active calls involving this user and end them
    const callsToEnd: string[] = [];
    for (const [callId, call] of activeCalls) {
      if ((call.callerId === userId || call.calleeId === userId) && !isTerminalState(call.status)) {
        callsToEnd.push(callId);
      }
    }

    for (const callId of callsToEnd) {
      const call = activeCalls.get(callId);
      if (!call) continue;

      const otherUserId = call.callerId === userId ? call.calleeId : call.callerId;
      console.log(`[CALL] disconnect cleanup — ending call ${callId}, notifying ${otherUserId}`);

      call.status = "ended";
      cleanupCall(callId);

      io.to(otherUserId).emit("call:ended", { callId });

      CallLog.update(
        { status: "ended", endedAt: new Date() },
        { where: { callId, status: { [Op.notIn]: ['ended', 'rejected', 'missed', 'busy', 'unavailable'] } } }
      ).catch(() => {});
    }

    socketUserMap.delete(socket.id);
  });
};
