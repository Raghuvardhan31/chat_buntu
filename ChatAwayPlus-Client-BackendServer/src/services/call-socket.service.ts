import { Server, Socket } from "socket.io";
import { generateAgoraToken } from "./agora.service";

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
    calleeId: string; 
    callType: "voice" | "video";
    channelName: string;
  }) => {
    const { callId, calleeId, callType, channelName } = data;
    
    console.log(`📞 [CALL-INIT] From: ${socket.id} to: ${calleeId}, channel: ${channelName}`);

    // Store call metadata
    activeCalls.set(callId, {
      callerId: socket.id,
      calleeId,
      channelName,
      callType
    });

    // Check if callee is online (joined their room)
    const calleeRoom = io.sockets.adapter.rooms.get(calleeId);
    if (!calleeRoom || calleeRoom.size === 0) {
      console.log(`📵 [CALL] Callee ${calleeId} is offline`);
      socket.emit("call-unavailable", { callId });
      activeCalls.delete(callId);
      return;
    }

    // Generate Agora tokens for both parties
    const callerToken = generateAgoraToken(channelName, 0);
    const calleeToken = generateAgoraToken(channelName, 0);

    // Tell caller it's ringing (include their token)
    socket.emit("call-ringing", { 
      callId, 
      agoraToken: callerToken 
    });

    // Send incoming-call signal to callee (include their token)
    socket.to(calleeId).emit("call-incoming", {
      callId,
      callerId: socket.id,
      callerName: "Friend", // In production, fetch from DB
      callType,
      channelName,
      agoraToken: calleeToken
    });

    console.log(`📡 [CALL-RINGING] Sent to caller ${socket.id}`);
    console.log(`📡 [CALL-INCOMING] Sent to callee ${calleeId}`);
  });

  // Handle call acceptance (Callee -> Server)
  socket.on("call-accept", (data: { callId: string; callerId: string }) => {
    const { callId, callerId } = data;
    console.log(`✅ [CALL-ACCEPT] Call ${callId} accepted by callee`);
    
    const callMetadata = activeCalls.get(callId);
    let callerToken = "";
    
    if (callMetadata) {
      // Regenerate token to ensure it's fresh for the caller
      callerToken = generateAgoraToken(callMetadata.channelName, 0);
    }
    
    socket.to(callerId).emit("call-accepted", {
      callId: callId,
      agoraToken: callerToken
    });
  });

  // Handle call rejection
  socket.on("call-reject", (data: { callId: string; callerId: string }) => {
    console.log(`❌ [CALL-REJECT] Call ${data.callId} rejected`);
    activeCalls.delete(data.callId);
    socket.to(data.callerId).emit("call-rejected", { callId: data.callId });
  });

  // Handle end call
  socket.on("call-end", (data: { callId: string; otherUserId: string }) => {
    console.log(`🔚 [CALL-END] Call ${data.callId} ended`);
    activeCalls.delete(data.callId);
    
    // The other party could be identified by socket.id or by their userId room
    socket.to(data.otherUserId).emit("call-ended", { callId: data.callId });
  });

  // Handle socket disconnect - clean up active calls if needed
  socket.on("disconnect", () => {
    // In a real app, you'd iterate and end calls where this socket was a participant
  });
};
