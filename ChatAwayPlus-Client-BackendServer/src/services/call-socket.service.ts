import { Server, Socket } from "socket.io";
import { getAgoraAppId } from "./agora.service";

// Track active calls to store channel names and other metadata
const activeCalls = new Map<string, {
  callerId: string;
  calleeId: string;
  channelName: string;
  callType: string;
}>();

export const setupCallHandlers = (io: Server, socket: Socket) => {
  // Handle call initiation (Caller -> Server)
  socket.on("call-initiate", async (data: { 
    callId: string;
    callerId: string;
    calleeId: string; 
    callType: "voice" | "video";
    channelName: string;
  }) => {
    const { callId, callerId, calleeId, callType, channelName } = data;
    
    console.log(`📞 [call-initiate] From: ${callerId} to: ${calleeId}, type: ${callType}, channel: ${channelName}, callId: ${callId}`);

    if (!callerId || !calleeId || !channelName || !callId) {
      console.log(`❌ [call-initiate] Invalid call data received`);
      socket.emit("call-error", { message: "Invalid call data" });
      return;
    }

    // Store call metadata
    activeCalls.set(callId, {
      callerId,
      calleeId,
      channelName,
      callType
    });

    // Check if callee is online (joined their room)
    const calleeRoom = io.sockets.adapter.rooms.get(calleeId);
    if (!calleeRoom || calleeRoom.size === 0) {
      console.log(`📵 [call-initiate] Callee ${calleeId} is offline/unavailable`);
      socket.emit("call-unavailable", { callId });
      activeCalls.delete(callId);
      return;
    }

    // Tell caller it's ringing
    socket.emit("call-ringing", { 
      callId, 
      channelName,
      appId: getAgoraAppId()
    });
    console.log(`📡 [call-ringing] Emitted to caller: ${callerId}`);

    // Send incoming-call signal to callee
    socket.to(calleeId).emit("incoming-call", {
      callId,
      callerId,
      callerName: data["callerName"] || "Someone", 
      callType,
      channelName,
      appId: getAgoraAppId()
    });
    console.log(`📡 [incoming-call] Emitted to callee: ${calleeId}`);
  });

  // Handle call acceptance (Callee -> Server)
  socket.on("call-accept", (data: { callId: string; callerId: string; calleeId: string }) => {
    const { callId, callerId, calleeId } = data;
    console.log(`✅ [call-accept] Call ${callId} accepted by ${calleeId}`);
    
    const callMetadata = activeCalls.get(callId);
    
    // Notify caller that call was accepted
    socket.to(callerId).emit("call-accepted", {
      callId: callId,
      channelName: callMetadata?.channelName || "",
    });
    console.log(`📡 [call-accepted] Emitted to caller: ${callerId}`);
  });

  // Handle call rejection
  socket.on("call-reject", (data: { callId: string; callerId: string }) => {
    const { callId, callerId } = data;
    console.log(`❌ [call-reject] Call ${callId} rejected by callee`);
    activeCalls.delete(callId);
    socket.to(callerId).emit("call-rejected", { callId });
    console.log(`📡 [call-rejected] Emitted to caller: ${callerId}`);
  });

  // Handle end call
  socket.on("call-end", (data: { callId: string; otherUserId: string }) => {
    const { callId, otherUserId } = data;
    console.log(`🔚 [call-end] Call ${callId} ended. Notifying ${otherUserId}`);
    activeCalls.delete(callId);
    
    socket.to(otherUserId).emit("call-ended", { callId });
    console.log(`📡 [call-ended] Emitted to: ${otherUserId}`);
  });

  // Handle socket disconnect
  socket.on("disconnect", () => {
    // Basic cleanup logic could go here
  });
};

