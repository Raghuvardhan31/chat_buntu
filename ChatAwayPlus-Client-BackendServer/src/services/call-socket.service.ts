import { Server, Socket } from "socket.io";
import CallLog from "../db/models/call-log.model";
import User from "../db/models/user.model";

export const setupCallHandlers = (io: Server, socket: Socket) => {
  // Handle call initiation (Caller -> Server)
  socket.on("call-initiate", async (data: { 
    callId: string;
    calleeId: string; 
    callType: "voice" | "video";
    channelName: string;
  }) => {
    const { callId, calleeId, callType, channelName } = data;
    
    // Generate token for the channel
    console.log(`📞 [CALL] ${socket.id} initiating ${callType} call to ${calleeId}`);

    // Check if callee is online (joined their room)
    const calleeRoom = io.sockets.adapter.rooms.get(calleeId);
    if (!calleeRoom || calleeRoom.size === 0) {
      console.log(`📵 [CALL] Callee ${calleeId} is offline`);
      socket.emit("call-unavailable", { callId });
      return;
    }

    console.log(`📞 [CALL] ${socket.id} initiating ${callType} call to ${calleeId}`);

    // Tell caller it's ringing
    socket.emit("call-ringing", { callId });

    // Send incoming-call signal to callee
    // We assume the caller's info is fetched from the DB or session
    socket.to(calleeId).emit("call-incoming", {
      callId,
      callerId: socket.id, // Or better, the actual userId from the socket
      callerName: "Friend", // In production, get user name from DB
      callType,
      channelName
    });
  });

  // Handle call acceptance (Callee -> Server)
  socket.on("call-accept", (data: { callId: string; callerId: string }) => {
    console.log(`✅ [CALL] Accepted: ${data.callId}`);
    socket.to(data.callerId).emit("call-accepted", {
      callId: data.callId
    });
  });

  // Handle call rejection
  socket.on("call-reject", (data: { callId: string; callerId: string }) => {
    console.log(`❌ [CALL] Rejected: ${data.callId}`);
    socket.to(data.callerId).emit("call-rejected", { callId: data.callId });
  });

  // Handle end call
  socket.on("call-end", (data: { callId: string; otherUserId: string }) => {
    console.log(`🔚 [CALL] Ended: ${data.callId}`);
    socket.to(data.otherUserId).emit("call-ended", { callId: data.callId });
  });
};
