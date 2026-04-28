import { Server, Socket } from "socket.io";
import { getAgoraAppId } from "./agora.service";
import CallLog from "../db/models/call-log.model";
import User from "../db/models/user.model";
import { Op } from "sequelize";

// Track active calls to store channel names and other metadata
const activeCalls = new Map<string, {
  callerId: string;
  calleeId: string;
  channelName: string;
  callType: "voice" | "video";
  timeoutId?: NodeJS.Timeout;
}>();

const CALL_TIMEOUT_MS = 30000; // 30 seconds timeout for missed call (User Requirement)

export const setupCallHandlers = (io: Server, socket: Socket) => {
  // Handle call initiation (Caller -> Server)
  socket.on("call:initiate", async (data: { 
    callId: string;
    callerId: string;
    calleeId: string; 
    callType: "voice" | "video";
    channelName: string;
    callerName?: string;
  }) => {
    const { callId, callerId, calleeId, callType, channelName } = data;
    
    console.log(`📞 [call:initiate] From: ${callerId} to: ${calleeId}, type: ${callType}, channel: ${channelName}, callId: ${callId}`);

    if (!callerId || !calleeId || !channelName || !callId) {
      console.log(`❌ [call:initiate] Invalid call data received`);
      socket.emit("call:error", { message: "Invalid call data" });
      return;
    }

    try {
      // 0. Dedup guard — if this callId is already tracked, the client sent a duplicate event.
      //    Silently ignore it to prevent SequelizeUniqueConstraintError.
      if (activeCalls.has(callId)) {
        console.log(`⚠️ [call:initiate] Duplicate event for callId ${callId}, ignoring.`);
        return;
      }

      // 1. Check if callee is already in a call (busy)
      let isBusy = false;
      for (const [_, call] of activeCalls) {
        if (call.calleeId === calleeId || call.callerId === calleeId) {
          isBusy = true;
          break;
        }
      }

      if (isBusy) {
        console.log(`📵 [call:initiate] Callee ${calleeId} is busy`);
        socket.emit("call:busy", { callId });
        // Use findOrCreate to be safe against any race where the callId already exists
        await CallLog.findOrCreate({
          where: { callId },
          defaults: {
            callId,
            callerId,
            calleeId,
            callType,
            channelName,
            status: "busy",
            startedAt: new Date(),
          },
        });
        return;
      }

      // 2. Create database log entry (idempotent via findOrCreate)
      const [_log, created] = await CallLog.findOrCreate({
        where: { callId },
        defaults: {
          callId,
          callerId,
          calleeId,
          callType,
          channelName,
          status: "initiated",
          startedAt: new Date(),
        },
      });

      if (!created) {
        // Record already exists — this is a duplicate event after processing started
        console.log(`⚠️ [call:initiate] CallLog for ${callId} already exists, ignoring duplicate event.`);
        return;
      }

      // 3. Set missed call timeout
      const timeoutId = setTimeout(async () => {
        const call = activeCalls.get(callId);
        if (call) {
          console.log(`⏰ [call-timeout] Call ${callId} timed out (missed)`);
          await CallLog.update(
            { status: "missed", endedAt: new Date() },
            { where: { callId } }
          );
          io.to(callerId).emit("call:missed", { callId });
          io.to(calleeId).emit("call:missed", { callId });
          activeCalls.delete(callId);
        }
      }, CALL_TIMEOUT_MS);

      activeCalls.set(callId, {
        callerId,
        calleeId,
        channelName,
        callType,
        timeoutId
      });

      // 4. Check if callee is online
      const calleeRoom = io.sockets.adapter.rooms.get(calleeId);
      if (!calleeRoom || calleeRoom.size === 0) {
        console.log(`📵 [call:initiate] Callee ${calleeId} is offline/unavailable`);
        clearTimeout(timeoutId);
        socket.emit("call:unavailable", { callId });
        await CallLog.update(
          { status: "unavailable", endedAt: new Date() },
          { where: { callId } }
        );
        activeCalls.delete(callId);
        return;
      }

      // 5. Signal the parties
      await CallLog.update({ status: "ringing" }, { where: { callId } });
      socket.emit("call:ringing", { callId, channelName, appId: getAgoraAppId() });
      socket.to(calleeId).emit("call:incoming", {
        callId,
        callerId,
        callerName: data["callerName"] || "Someone", 
        callType,
        channelName,
        appId: getAgoraAppId()
      });
    } catch (error: any) {
      console.error(`❌ [call:initiate] Error:`, error);
      socket.emit("call:error", { 
        message: "Internal server error", 
        detail: error?.message || String(error)
      });
    }
  });

  // Handle call acceptance
  socket.on("call:accept", async (data: { callId: string; callerId: string; calleeId: string }) => {
    const { callId, callerId, calleeId } = data;
    const callMetadata = activeCalls.get(callId);
    if (callMetadata) {
      if (callMetadata.timeoutId) clearTimeout(callMetadata.timeoutId);
      try {
        await CallLog.update({ status: "accepted", answeredAt: new Date() }, { where: { callId } });
        socket.to(callerId).emit("call:accepted", { callId, channelName: callMetadata.channelName });
      } catch (error) {
        console.error(`❌ [call:accept] Error:`, error);
      }
    }
  });

  // Handle call rejection
  socket.on("call:reject", async (data: { callId: string; callerId: string }) => {
    const { callId, callerId } = data;
    const callMetadata = activeCalls.get(callId);
    if (callMetadata?.timeoutId) clearTimeout(callMetadata.timeoutId);
    try {
      await CallLog.update({ status: "rejected", endedAt: new Date() }, { where: { callId } });
    } catch (error) {}
    activeCalls.delete(callId);
    socket.to(callerId).emit("call:rejected", { callId });
  });

  // Handle end call
  socket.on("call:end", async (data: { callId: string; otherUserId: string }) => {
    const { callId, otherUserId } = data;
    const callMetadata = activeCalls.get(callId);
    if (callMetadata?.timeoutId) clearTimeout(callMetadata.timeoutId);
    try {
      const log = await CallLog.findOne({ where: { callId } });
      const endedAt = new Date();
      let duration = 0;
      if (log && log.answeredAt) {
        duration = Math.floor((endedAt.getTime() - log.answeredAt.getTime()) / 1000);
      }
      await CallLog.update({ status: "ended", endedAt, duration }, { where: { callId } });
    } catch (error) {}
    activeCalls.delete(callId);
    socket.to(otherUserId).emit("call:ended", { callId });
  });

  // --- History Handlers ---

  socket.on("get-call-history", async (data: { limit?: number; offset?: number; callType?: string; status?: string }) => {
    try {
      const userId = (socket as any).userId;
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
      console.error("❌ [get-call-history] Error:", error);
      socket.emit("call-history-error", { message: "Failed to fetch history" });
    }
  });

  socket.on("get-missed-calls-count", async () => {
    try {
      const userId = (socket as any).userId;
      if (!userId) return;
      const count = await CallLog.count({
        where: { calleeId: userId, status: 'missed' }
      });
      socket.emit("missed-calls-count-response", { success: true, count });
    } catch (error) {}
  });

  socket.on("disconnect", () => {
    // Optional: Cleanup active calls where this socket was participant
  });
};
