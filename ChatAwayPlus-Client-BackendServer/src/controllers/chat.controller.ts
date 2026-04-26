import { Request, Response } from "express";
import { Op } from "sequelize";
import { Server as SocketIOServer, Socket } from "socket.io";
import jwt from "jsonwebtoken";
import Chat from "../db/models/chat.model";
import User from "../db/models/user.model";
import StarredMessage from "../db/models/starred-message.model";
import { sendDataMessage, sendStoriesChangedToUser, sendChatPictureLikeToUser, sendStatusLikeToUser, sendReactionNotificationToUser, sendIncomingCallToUser } from "../services/fcm.service";
import { getById } from "../services/user.service";
import blockController from "./block.controller";
import { config } from "../config";
import Contact from "../db/models/contact.model";
import BlockedUser from "../db/models/blocked-user.model";
import {
  toggleChatPictureLike,
  getChatPictureLikeCount,
  hasUserLikedChatPicture,
  getUsersWhoLikedChatPicture,
} from "../services/chat-picture-like.service";
import { validateS3Key, getS3ObjectStreamWithMetaData } from "../utils/s3.util";
import PollVote from "../db/models/poll-vote.model";
import * as storyService from "../services/story.service";
import CallLog from "../db/models/call-log.model";
/**
 * ChatController - WhatsApp-like Real-time Chat System
 *
 * Message Status Flow (Like WhatsApp):
 * 1. SENT (single gray checkmark ✓): Message saved to server
 * 2. DELIVERED (double gray checkmarks ✓✓): Message delivered to receiver's device
 * 3. READ (double blue checkmarks ✓✓): Message read by receiver
 *
 * Socket Events:
 * - authenticate: User connects and authenticates
 * - typing: Real-time typing indicators
 * - private-message: Send a message
 * - update-message-status: Update message status (delivered/read/both)
 * - disconnect: User goes offline
 *
 * Client Listeners:
 * - authenticated: Connection established
 * - user-status-changed: User went online/offline
 * - user-typing: Someone is typing
 * - new-message: Received a new message
 * - message-sent: Your message was sent to server
 * - message-status-update: Message status changed (delivered/read)
 * - message-deleted: Message was deleted
 * - force-disconnect: Connected from another device
 */
class ChatController {
  private io: SocketIOServer;
  private connectedUsers: Map<string, string> = new Map(); // userId -> socketId
  private activeChats: Map<string, string> = new Map(); // userId -> otherUserId (who they're chatting with)
  private lastChatPartner: Map<string, string> = new Map(); // userId -> lastChattedWith (for reconnection restoration)

  /**
   * Separate presence tracking from socket connection.
   * A user is only "online" when they explicitly call set-user-presence with isOnline: true.
   * This prevents FCM wake-ups from incorrectly reporting users as online.
   *
   * Key rule: WebSocket connected ≠ User is online
   * - socketConnected: User has an active WebSocket connection (for message delivery)
   * - isOnline: User has app in foreground (explicitly set via set-user-presence)
   */
  private userPresence: Map<string, { isOnline: boolean; lastSeen: Date }> =
    new Map();

  // Call signaling: track active call timeouts and which users are in active calls
  private callTimeouts: Map<string, NodeJS.Timeout> = new Map(); // callId -> timeout
  private activeCallUsers: Map<string, string> = new Map(); // userId -> callId (tracks who is in a call)

  constructor(io: SocketIOServer) {
    this.io = io;
    this.setupSocketHandlers();
    this.setupPeriodicCleanup();
  }

  /**
   * Notify socket users about message status changes (called from Mobile API)
   */
  public notifyMessageStatusUpdate(
    chatId: string,
    senderId: string,
    status: "delivered" | "read",
  ) {
    const senderSocketId = this.connectedUsers.get(senderId);
    if (senderSocketId) {
      this.io.to(senderSocketId).emit("message-status-update", {
        chatId,
        status,
        updatedAt: new Date().toISOString(),
      });
      console.log(
        `📡 Notified sender ${senderId} about status: ${status} for message ${chatId}`,
      );
    } else {
      console.log(`⚠️ Cannot notify sender ${senderId} - not connected`);
    }
  }

  /**
   * Notify socket users about message status changes WITH full message object (called from Mobile API when receiver is offline)
   */
  public notifyMessageStatusUpdateWithObject(
    chatId: string,
    senderId: string,
    status: "delivered" | "read",
    messageObject: any,
  ) {
    const senderSocketId = this.connectedUsers.get(senderId);
    if (senderSocketId) {
      this.io.to(senderSocketId).emit("message-status-update", {
        chatId,
        status,
        updatedAt:
          status === "delivered"
            ? messageObject.deliveredAt
            : messageObject.readAt,
        messageObject: messageObject,
      });
      console.log(
        `📡 Sent full message object with '${status}' status to sender ${senderId} (socket: ${senderSocketId})`,
      );
    } else {
      console.log(`⚠️ Cannot notify sender ${senderId} - not connected`);
    }
  }

  /**
   * Notify socket users about message deletion (called from Mobile API)
   */
  public notifyMessageDeletion(
    chatId: string,
    senderId: string,
    receiverId: string,
    deleteType: string,
  ) {
    const senderSocketId = this.connectedUsers.get(senderId);
    const receiverSocketId = this.connectedUsers.get(receiverId);

    const deletionData = {
      chatId,
      senderId,
      receiverId,
      deletedAt: new Date(),
      deleteType,
      deletedBy: senderId,
    };

    // Notify sender
    if (senderSocketId) {
      this.io.to(senderSocketId).emit("message-deleted", deletionData);
    }

    // Notify receiver
    if (deleteType === "everyone") {
      if (receiverSocketId) {
        this.io.to(receiverSocketId).emit("message-deleted", deletionData);
      }
    }
  }

  /**
   * Get connected users for external access
   */
  public getConnectedUsers() {
    return this.connectedUsers;
  }

  /**
   * Get active chat for a user (called from Mobile API)
   */
  public getActiveChatFor(userId: string): string | undefined {
    return this.activeChats.get(userId);
  }

  /**
   * Emit event to a specific socket (called from Mobile API)
   */
  public emitToSocket(socketId: string, event: string, data: any): void {
    this.io.to(socketId).emit(event, data);
  }

  /**
   * Emit chat activity update (for chat list preview)
   * Used when reactions or other activities happen on the latest message
   */
  public emitChatActivityUpdate(userId: string, data: any): void {
    const socketId = this.connectedUsers.get(userId);
    if (socketId) {
      this.io.to(socketId).emit("chat-activity-updated", data);
      console.log(`📨 Emitted chat-activity-updated to user ${userId}`);
    }
  }

  /**
   * Emit reaction update to both sender and receiver
   */
  public emitReactionUpdate(
    senderId: string,
    receiverId: string,
    data: any,
  ): void {
    const senderSocketId = this.connectedUsers.get(senderId);
    const receiverSocketId = this.connectedUsers.get(receiverId);

    if (senderSocketId) {
      this.io.to(senderSocketId).emit("reaction-updated", data);
      // Also emit specialized event for specific requirements
      this.io.to(senderSocketId).emit("reaction_added", {
        messageId: data.messageId,
        userId: data.userId,
        reaction: data.emoji
      });
    }
    if (receiverSocketId) {
      this.io.to(receiverSocketId).emit("reaction-updated", data);
      this.io.to(receiverSocketId).emit("reaction_added", {
        messageId: data.messageId,
        userId: data.userId,
        reaction: data.emoji
      });
    }
    console.log(
      `💬 Emitted reaction-updated/reaction_added to sender ${senderId} and receiver ${receiverId}`,
    );
  }

  /**
   * Emit a new in-app notification to the receiver
   */
  public emitNewNotification(receiverId: string, notification: any): void {
    const receiverSocketId = this.connectedUsers.get(receiverId);
    if (receiverSocketId) {
      this.io.to(receiverSocketId).emit("new_notification", notification);
      console.log(`📨 Emitted new_notification to user ${receiverId}`);
    }
  }

  /**
   * Broadcast user online/offline status to their contacts (WhatsApp style)
   * - isOnline: true + lastSeen: null = "Online"
   * - isOnline: false + lastSeen: timestamp = "last seen today at 10:15 AM"
   *
   * IMPORTANT: This should ONLY be called from:
   * 1. set-user-presence event (explicit foreground/background state)
   * 2. disconnect event (user goes offline)
   *
   * DO NOT call this from:
   * - authenticate event (WebSocket connection ≠ online)
   * - message-received-ack (FCM delivery ack ≠ online)
   * - enter-chat/leave-chat (chat state ≠ online state)
   */
  private broadcastUserStatus(userId: string, status: "online" | "offline") {
    const isOnline = status === "online";
    const now = new Date();
    const lastSeen = isOnline ? null : now.toISOString();

    // Update presence tracking
    this.userPresence.set(userId, { isOnline, lastSeen: now });

    if (!isOnline) {
      // Persist lastSeen for WhatsApp-style behavior
      this.updateLastSeenInMetadata(userId, now);
    }

    // Get active chat info for richer status
    const isInChatWith = this.activeChats.get(userId);

    // WhatsApp format with additional context
    this.io.emit("user-status-changed", {
      userId,
      isOnline,
      status: isOnline ? "online" : "offline",
      isInChat: !!isInChatWith,
      chattingWith: isInChatWith || null,
      lastSeen, // null when online, ISO timestamp when offline
      timestamp: now.toISOString(),
    });

    console.log(
      `📡 Broadcasted presence: ${userId} is ${isOnline ? "ONLINE" : "OFFLINE"}${lastSeen ? ` (lastSeen: ${lastSeen})` : ""}`,
    );
  }

  private async updateLastSeenInMetadata(userId: string, lastSeen: Date) {
    try {
      const user = await getById(userId);
      if (!user) {
        return;
      }

      let metadata: any = {};
      try {
        metadata = JSON.parse((user as any).metadata || "{}");
      } catch (error) {
        console.error("❌ Error parsing user metadata for lastSeen:", {
          userId,
          error,
        });
      }

      const updatedMetadata = {
        ...metadata,
        lastSeen: lastSeen.toISOString(),
      };

      await User.update(
        { metadata: updatedMetadata },
        { where: { id: userId } },
      );
    } catch (error) {
      console.error("❌ Error updating lastSeen in metadata:", {
        userId,
        error,
      });
    }
  }

  /**
   * Check if both users are actively in the same chat screen
   */
  private areBothUsersInSameChat(userId1: string, userId2: string): boolean {
    const user1ChatWith = this.activeChats.get(userId1);
    const user2ChatWith = this.activeChats.get(userId2);
    return user1ChatWith === userId2 && user2ChatWith === userId1;
  }

  /**
   * Setup periodic cleanup of stale connections
   * Runs every 30 seconds to detect and remove ghost connections
   */
  private setupPeriodicCleanup() {
    setInterval(() => {
      this.cleanupStaleConnections();
    }, 30000); // Every 30 seconds

    // console.log('🧹 Periodic connection cleanup initialized (30s interval)');
  }

  /**
   * Clean up stale/dead socket connections
   */
  private cleanupStaleConnections() {
    const staleUsers: string[] = [];

    this.connectedUsers.forEach((socketId, userId) => {
      const socket = this.io.sockets.sockets.get(socketId);
      if (!socket || !socket.connected) {
        staleUsers.push(userId);
      }
    });

    if (staleUsers.length > 0) {
      console.log(`🧹 Cleaning up ${staleUsers.length} stale connection(s)`);

      staleUsers.forEach((userId) => {
        console.log(`  └─ Removing stale user: ${userId}`);
        this.connectedUsers.delete(userId);
        this.activeChats.delete(userId);
        this.broadcastUserStatus(userId, "offline");
      });
    }
  }

  //===================================web socket events======================
  private setupSocketHandlers() {
    this.io.on("connection", (socket: Socket) => {
      console.log("🔌 New socket connection:", socket.id);

      let authenticatedUserId: string | null = null;

      // Handle user authentication
      socket.on(
        "authenticate",
        async (data: {
          userId: string;
          loadHistory: boolean;
          token?: string;
        }) => {
          try {
            console.log("🔐 Authentication attempt:", { userId: data.userId });

            // Check if user exists
            const user = await getById(data.userId);
            if (!user) {
              console.log("❌ User not found:", data.userId);
              socket.emit("authentication_error", { error: "User not found" });
              socket.disconnect();
              return;
            }

            console.log("✅ User authenticated:", user.firstName);

            // Remove old socket if user reconnects from another device
            const oldSocketId = this.connectedUsers.get(data.userId);
            if (oldSocketId && oldSocketId !== socket.id) {
              console.log(
                `⚠️ User ${data.userId} connected from new device, disconnecting old socket: ${oldSocketId}`,
              );

              this.io.to(oldSocketId).emit("force-disconnect", {
                reason: "Connected from another device",
              });

              // Force disconnect the old socket
              const oldSocket = this.io.sockets.sockets.get(oldSocketId);
              if (oldSocket) {
                oldSocket.disconnect(true);
              }
            }

            this.connectedUsers.set(data.userId, socket.id);
            authenticatedUserId = data.userId;

            console.log(
              `✅ User ${data.userId} registered with socket ${socket.id}`,
            );
            console.log(
              `📊 Total connected users: ${this.connectedUsers.size}`,
            );
            console.log(
              `📋 Connected users map:`,
              Array.from(this.connectedUsers.entries()).map(([uid, sid]) => ({
                userId: uid,
                socketId: sid,
              })),
            );

            // Restore active chat if they were chatting before disconnect
            const lastPartner = this.lastChatPartner.get(data.userId);
            if (lastPartner) {
              this.activeChats.set(data.userId, lastPartner);
              console.log(
                `🔄 Restored active chat for ${data.userId} with ${lastPartner}`,
              );
            }

            // DO NOT broadcast online status here!
            // WebSocket connection ≠ User is online
            // User must explicitly call 'set-user-presence' with isOnline: true
            // This prevents FCM wake-ups from incorrectly reporting users as online
            console.log(
              `🔌 Socket connected for ${data.userId} - waiting for explicit presence update`,
            );

            // Acknowledge successful authentication
            socket.emit("authenticated", {
              success: true,
              userId: data.userId,
              socketId: socket.id,
            });
          } catch (error) {
            console.error("❌ Authentication error:", error);
            socket.emit("authentication_error", {
              error: "Authentication failed",
              details: error instanceof Error ? error.message : "Unknown error",
            });
            socket.disconnect();
          }
        },
      );

      // Handle user entering a chat screen
      socket.on(
        "enter-chat",
        (data: { userId: string; otherUserId: string }) => {
          console.log("📥 User entering chat:", {
            userId: data.userId,
            otherUserId: data.otherUserId,
            socketId: socket.id,
            authenticated: data.userId === authenticatedUserId,
            timestamp: new Date().toISOString(),
          });

          if (data.userId === authenticatedUserId) {
            this.activeChats.set(data.userId, data.otherUserId);
            this.lastChatPartner.set(data.userId, data.otherUserId); // Track for reconnection

            console.log(
              `✅ User ${data.userId} entered chat with ${data.otherUserId}`,
            );

            // Check if both users are in the same chat
            const otherUserActiveChat = this.activeChats.get(data.otherUserId);

            if (otherUserActiveChat === data.userId) {
              console.log(
                `💬 Both users now in same chat: ${data.userId} ↔️ ${data.otherUserId}`,
              );
            }
          } else {
            console.log(
              `⚠️ Unauthorized enter-chat attempt: ${data.userId} (authenticated: ${authenticatedUserId})`,
            );
          }
        },
      );

      // Handle user leaving a chat screen
      socket.on("leave-chat", (data: { userId: string }) => {
        console.log("📤 User leaving chat:", {
          userId: data.userId,
          socketId: socket.id,
          authenticated: data.userId === authenticatedUserId,
          timestamp: new Date().toISOString(),
        });

        if (data.userId === authenticatedUserId) {
          const wasChattingWith = this.activeChats.get(data.userId);
          this.activeChats.delete(data.userId);

          if (wasChattingWith) {
            console.log(
              `✅ User ${data.userId} left chat with ${wasChattingWith}`,
            );
          } else {
            console.log(
              `ℹ️ User ${data.userId} left chat (was not in active chat)`,
            );
          }
        } else {
          console.log(
            `⚠️ Unauthorized leave-chat attempt: ${data.userId} (authenticated: ${authenticatedUserId})`,
          );
        }
      });

      // Handle request for user online status
      socket.on("get-user-status", async (data: { userId: string }) => {
        const socketId = this.connectedUsers.get(data.userId);
        const presence = this.userPresence.get(data.userId);

        // User is online ONLY if they explicitly set presence to online
        // Socket connection alone doesn't mean online (could be FCM wake-up)
        let isOnline = presence?.isOnline === true;

        if (socketId) {
          // Verify the socket is actually connected
          const userSocket = this.io.sockets.sockets.get(socketId);
          const socketConnected = userSocket?.connected === true;

          // Clean up stale entry if socket is dead
          if (!socketConnected) {
            console.log(
              `🧹 Cleaning up stale connection for user ${data.userId} (dead socket)`,
            );
            this.connectedUsers.delete(data.userId);
            this.activeChats.delete(data.userId);
            this.userPresence.delete(data.userId);
            isOnline = false;
            // Broadcast offline status to other users
            this.broadcastUserStatus(data.userId, "offline");
          }
        } else {
          // No socket connection means definitely offline
          isOnline = false;
        }

        const isInChatWith = this.activeChats.get(data.userId);

        let lastSeen: string | null = null;
        try {
          const user = await getById(data.userId);
          if (user && (user as any).metadata) {
            try {
              const metadata = JSON.parse((user as any).metadata || "{}");
              if (metadata.lastSeen) {
                lastSeen = metadata.lastSeen;
              }
            } catch (error) {
              console.error(
                "❌ Error parsing metadata while fetching lastSeen:",
                {
                  userId: data.userId,
                  error,
                },
              );
            }
          }
        } catch (error) {
          console.error("❌ Error fetching user for get-user-status:", {
            userId: data.userId,
            error,
          });
        }

        // Send status response back to requester (WhatsApp format)
        socket.emit("user-status-response", {
          userId: data.userId,
          isOnline: isOnline,
          lastSeen: isOnline ? null : lastSeen, // null when online, timestamp when offline
          isInChat: !!isInChatWith,
          chattingWith: isInChatWith || null,
        });
      });

      /**
       * Handle explicit presence updates from frontend (app foreground/background)
       *
       * THIS IS THE ONLY WAY TO SET A USER AS ONLINE.
       *
       * Frontend should call this:
       * - When app comes to foreground: { isOnline: true }
       * - When app goes to background: { isOnline: false }
       *
       * DO NOT rely on WebSocket connection for online status.
       * FCM can wake up the app and create a WebSocket connection
       * just to send a delivery acknowledgment - this doesn't mean
       * the user is actively using the app.
       */
      socket.on(
        "set-user-presence",
        async (data: {
          userId: string;
          isOnline: boolean;
          timestamp?: string;
        }) => {
          // Validate that user is authenticated and matches the presence update
          if (!authenticatedUserId || authenticatedUserId !== data.userId) {
            console.warn(
              `⚠️ Unauthorized presence update attempt: ${data.userId} (authenticated: ${authenticatedUserId})`,
            );
            return;
          }

          console.log(
            `📱 Explicit presence update from ${data.userId}: ${data.isOnline ? "FOREGROUND (online)" : "BACKGROUND (offline)"}`,
          );

          // Use the centralized broadcast method which updates userPresence map
          this.broadcastUserStatus(
            data.userId,
            data.isOnline ? "online" : "offline",
          );

          // Acknowledge the presence update
          socket.emit("presence-acknowledged", {
            userId: data.userId,
            isOnline: data.isOnline,
            timestamp: new Date().toISOString(),
          });
        },
      );

      // Handle typing indicator
      socket.on(
        "typing",
        (data: { senderId: string; receiverId: string; isTyping: boolean }) => {
          const receiverSocketId = this.connectedUsers.get(data.receiverId);
          if (receiverSocketId) {
            this.io.to(receiverSocketId).emit("user-typing", {
              userId: data.senderId,
              isTyping: data.isTyping,
            });
          } else {
          }
        },
      ); // Handle private messages
      socket.on(
        "private-message",
        async (data: {
          senderId: string;
          receiverId: string;
          message?: string;
          messageType: string;
          fileUrl?: string;
          mimeType?: string;
          contactPayload?: { name: string; phone: string }[];
          fileMetadata?: {
            fileName: string;
            fileSize: number;
            pageCount?: number;
          };
          isFollowUp?: boolean;
          pollPayload?: {
            question: string;
            options: { id: string; text: string }[];
          };
          audioDuration?: number;
          videoThumbnailUrl?: string;
          videoDuration?: number;
          replyToMessageId?: string;
        }) => {
          try {
            const {
              senderId,
              receiverId,
              messageType,
              message,
              fileUrl,
              mimeType,
              contactPayload,
              fileMetadata,
              isFollowUp = false,
              pollPayload,
              audioDuration,
              videoThumbnailUrl,
              videoDuration,
              replyToMessageId,
            } = data;

            // Validate sender is authenticated
            if (senderId !== authenticatedUserId) {
              socket.emit("message-error", {
                error: "Unauthorized: sender ID mismatch",
              });
              return;
            }

            if (!messageType) {
              socket.emit("message-error", {
                error: "Message type missing",
              });
              return;
            }

            if (
              messageType === "text" &&
              (!message || message.trim().length === 0)
            ) {
              return socket.emit("message-error", {
                error: "Message cannot be empty",
              });
            }

            if (
              (messageType === "image" ||
                messageType === "pdf" ||
                messageType === "video" ||
                messageType === "audio") &&
              !fileUrl
            ) {
              return socket.emit("message-error", {
                error: "File URL missing",
              });
            }

            if (
              (messageType === "contact" && !contactPayload) ||
              (contactPayload && contactPayload.length === 0)
            ) {
              return socket.emit("message-error", {
                error: "Contact payload missing",
              });
            }

            if (messageType === "poll" && !pollPayload) {
              return socket.emit("message-error", {
                error: "Poll payload missing",
              });
            }

            if (
              messageType === "poll" &&
              pollPayload &&
              pollPayload?.options?.length > 5
            ) {
              return socket.emit("message-error", {
                error: "Poll options cannot be more than 5",
              });
            }

            // Check if receiver exists
            const user = await getById(receiverId);
            if (!user) {
              socket.emit("message-error", {
                error: "Receiver not found",
              });
              return;
            }

            // Check if either user has blocked the other
            const isBlocked = await blockController.checkIfBlocked(
              senderId,
              receiverId,
            );
            if (isBlocked) {
              socket.emit("message-error", {
                error:
                  "You cannot send messages to this user. They may have blocked you or you may have blocked them.",
              });
              return;
            }

            const senderDetails = await getById(senderId);
            let userMetadata: any = {};
            try {
              userMetadata = JSON.parse(user?.metadata || "{}");
            } catch (error) {
              console.error("❌ Error parsing receiver metadata for FCM:", {
                receiverId,
                error,
              });
              userMetadata = {};
            }

            // Implicitly mark sender as in chat with receiver
            this.activeChats.set(senderId, receiverId);
            this.lastChatPartner.set(senderId, receiverId);

            // Auto-populate reply preview fields if replying to a message
            let replyToMessageText: string | null = null;
            let replyToMessageSenderId: string | null = null;
            let replyToMessageType: 'text' | 'image' | 'pdf' | 'video' | 'audio' | 'contact' | 'poll' | 'location' | null = null;

            if (replyToMessageId) {
              try {
                const repliedMessage = await Chat.findByPk(replyToMessageId, {
                  attributes: ['message', 'senderId', 'messageType']
                });
                if (repliedMessage) {
                  replyToMessageText = repliedMessage.message;
                  replyToMessageSenderId = repliedMessage.senderId;
                  replyToMessageType = repliedMessage.messageType;
                }
              } catch (error) {
                console.error('❌ Error fetching replied message:', error);
              }
            }

            // Save message to database
            const chat = await Chat.create(
              {
                senderId,
                receiverId,
                message: message || null,
                messageType,
                fileUrl: fileUrl || null,
                mimeType: mimeType || null,
                contactPayload: contactPayload || null,
                fileMetadata: fileMetadata || null,
                messageStatus: "sent",
                isRead: false,
                isFollowUp,
                pollPayload:
                  messageType === "poll"
                    ? {
                      question: pollPayload?.question || "",
                      options: pollPayload?.options || [],
                    }
                    : null,
                audioDuration: messageType === "audio" && audioDuration ? audioDuration : null,
                videoThumbnailUrl: messageType === "video" && videoThumbnailUrl ? videoThumbnailUrl : null,
                videoDuration: messageType === "video" && videoDuration ? videoDuration : null,
                replyToMessageId: replyToMessageId || null,
                replyToMessageText: replyToMessageText,
                replyToMessageSenderId: replyToMessageSenderId,
                replyToMessageType: replyToMessageType,
                deliveryChannel: "socket", // Message sent via WebSocket
              },
              {
                raw: true,
              },
            );

            // Get receiver's socket id
            // const receiverSocketId = this.connectedUsers.get(receiverId) || false;
            //

            // // Send message to receiver if online
            // if (!receiverSocketId) {
            //
            //   await sendDataMessage(userMetadata?.fcmToken, {
            //     senderId: senderId,
            //     senderFirstName: senderDetails?.firstName || '',
            //     senderProfilePic: senderDetails?.profile_pic || '',
            //     senderMobileNo: senderDetails?.mobileNo || '',
            //     body: message,
            //     title: '', // Empty - let client decide
            //   });
            // }
            // if (receiverSocketId) {
            //   this.io.to(receiverSocketId).emit('new-message', {
            //     chatId: chat.id,
            //     senderId,
            //     message,
            //     createdAt: chat.createdAt
            //   });
            // }

            // Check if receiver is online
            const receiverSocketId = this.connectedUsers.get(receiverId);
            const chatId = chat.get("id");

            // Check if both users are in same chat screen
            const bothInSameChat = this.areBothUsersInSameChat(
              senderId,
              receiverId,
            );

            // Check if receiver is in active chat with sender
            const receiverInChatWithSender =
              this.activeChats.get(receiverId) === senderId;

            // Send confirmation to sender immediately (single checkmark - sent to server)
            // New messages won't have reactions yet, so include empty array
            socket.emit("message-sent", {
              chatId: chatId,
              receiverId,
              messageType: messageType,
              message: message || null,
              fileUrl: fileUrl || null,
              mimeType: mimeType || null,
              contactPayload: contactPayload || null,
              fileMetadata: fileMetadata || null,
              messageStatus: "sent",
              deliveryChannel: "socket", // Indicate this message was sent via socket
              createdAt: chat.createdAt,
              isFollowUp,
              pollPayload,
              audioDuration: messageType === "audio" ? audioDuration || null : null,
              videoThumbnailUrl: messageType === "video" ? videoThumbnailUrl || null : null,
              videoDuration: messageType === "video" ? videoDuration || null : null,
              replyToMessageId: replyToMessageId || null,
              replyToMessageText: replyToMessageText,
              replyToMessageSenderId: replyToMessageSenderId,
              replyToMessageType: replyToMessageType,
              reactions: [], // New message has no reactions yet
            });

            if (receiverSocketId) {
              // User is online - send via socket
              this.io.to(receiverSocketId).emit("new-message", {
                chatId: chatId,
                senderId,
                receiverId,
                messageType: messageType,
                message: message || null,
                fileUrl: fileUrl || null,
                mimeType: mimeType || null,
                contactPayload: contactPayload || null,
                fileMetadata: fileMetadata || null,
                messageStatus: "sent",
                deliveryChannel: "socket", // How sender sent (always socket)
                receiverDeliveryChannel: null, // Will be set when message is delivered
                createdAt: chat.createdAt,
                isFollowUp,
                pollPayload,
                audioDuration: messageType === "audio" ? audioDuration || null : null,
                videoThumbnailUrl: messageType === "video" ? videoThumbnailUrl || null : null,
                videoDuration: messageType === "video" ? videoDuration || null : null,
                replyToMessageId: replyToMessageId || null,
                replyToMessageText: replyToMessageText,
                replyToMessageSenderId: replyToMessageSenderId,
                replyToMessageType: replyToMessageType,
                reactions: [], // New message has no reactions yet
              });

              // Automatically mark as delivered and send acknowledgment to sender
              // This happens because receiver is online and got the message via socket
              try {
                await Chat.update(
                  {
                    messageStatus: "delivered",
                    deliveredAt: new Date(),
                    receiverDeliveryChannel: "socket", // Receiver got it via socket
                  },
                  {
                    where: {
                      id: chatId,
                      messageStatus: "sent",
                    },
                  },
                );

                // Send full message object back to sender with delivered status
                // Import MessageReaction model for including reactions
                const MessageReaction =
                  require("../db/models/message-reaction.model").default;

                const updatedMessage = await Chat.findOne({
                  where: { id: chatId },
                  attributes: [
                    "id",
                    "senderId",
                    "receiverId",
                    "message",
                    "messageType",
                    "fileUrl",
                    "contactPayload",
                    "fileMetadata",
                    "mimeType",
                    "messageStatus",
                    "deliveryChannel",
                    "receiverDeliveryChannel",
                    "deliveredAt",
                    "createdAt",
                    "isFollowUp",
                    "pollPayload",
                    "audioDuration",
                    "videoThumbnailUrl",
                    "videoDuration",
                    "replyToMessageId",
                    "replyToMessageText",
                    "replyToMessageSenderId",
                    "replyToMessageType",
                  ],
                  include: [
                    {
                      model: MessageReaction,
                      as: "reactions",
                      attributes: ["id", "userId", "emoji", "createdAt"],
                      include: [
                        {
                          model: User,
                          as: "user",
                          attributes: [
                            "id",
                            "firstName",
                            "lastName",
                            "chat_picture",
                          ],
                        },
                      ],
                      required: false,
                    },
                  ],
                });

                if (updatedMessage) {
                  const messageData = updatedMessage.toJSON();
                  socket.emit("message-status-update", {
                    chatId: messageData.id,
                    status: "delivered",
                    updatedAt: messageData.deliveredAt,
                    messageObject: {
                      chatId: messageData.id,
                      senderId: messageData.senderId,
                      receiverId: messageData.receiverId,
                      message: messageData.message,
                      messageType: messageData.messageType,
                      fileUrl: messageData.fileUrl,
                      mimeType: messageData.mimeType,
                      contactPayload: messageData.contactPayload,
                      fileMetadata: messageData.fileMetadata,
                      messageStatus: messageData.messageStatus,
                      deliveryChannel: messageData.deliveryChannel,
                      receiverDeliveryChannel:
                        messageData.receiverDeliveryChannel,
                      deliveredAt: messageData.deliveredAt,
                      createdAt: messageData.createdAt,
                      isFollowUp: messageData.isFollowUp,
                      pollPayload: messageData.pollPayload,
                      audioDuration: messageData.audioDuration || null,
                      videoThumbnailUrl: messageData.videoThumbnailUrl || null,
                      videoDuration: messageData.videoDuration || null,
                      replyToMessageId: messageData.replyToMessageId || null,
                      replyToMessageText: messageData.replyToMessageText || null,
                      replyToMessageSenderId: messageData.replyToMessageSenderId || null,
                      replyToMessageType: messageData.replyToMessageType || null,
                      reactions: messageData.reactions || [],
                    },
                  });

                  console.log(
                    `📡 Sent 'delivered' status with full message object to sender ${senderId} (socket: ${socket.id})`,
                  );
                  console.log(
                    `✅ Message ${chatId} marked as delivered (receiverDeliveryChannel: socket)`,
                  );
                }
              } catch (error) {
                console.error("❌ Error auto-updating delivery status:", error);
              }

              // Send FCM notification only if both users are NOT in the same active chat
              // If both are in active chat, receiver already got the message via socket - no need for FCM
              if (!bothInSameChat) {
                try {
                  if (userMetadata?.fcmToken) {
                    // console.log('📨 Attempting FCM delivery to online user (not in active chat with sender)', {
                    //   receiverId,
                    //   chatId,
                    //   inActiveChatWithSender: receiverInChatWithSender,
                    //   bothInSameChat: bothInSameChat,
                    //   tokenPreview: userMetadata.fcmToken.substring(0, 20)
                    // });

                    const fcmResult = await sendDataMessage(
                      userMetadata.fcmToken,
                      {
                        senderId: senderId,
                        chatId: chatId,
                        senderFirstName: senderDetails?.firstName || "",
                        sender_chat_picture: senderDetails?.chat_picture || "",
                        sender_mobile_number: senderDetails?.mobileNo || "",
                        body: JSON.stringify({
                          message: message || null,
                          messageType: messageType,
                          fileUrl: fileUrl || null,
                          mimeType: mimeType || null,
                          contactPayload: contactPayload || null,
                        }),
                        title: "", // Empty - let client decide
                      },
                    );

                    if (fcmResult.success) {
                      console.log(
                        `✅ FCM sent to online user ${receiverId} for message ${chatId}`,
                      );
                    } else if (fcmResult.reason === "invalid_token") {
                      // console.warn(`⚠️ Invalid FCM token for user ${receiverId}, notification skipped (message ${chatId})`);
                    } else {
                      console.error(
                        `❌ FCM send failed for online user ${receiverId}, message ${chatId}:`,
                        fcmResult.reason,
                      );
                    }
                  } else {
                    console.log(
                      `ℹ️ No FCM token for online user ${receiverId}, cannot deliver message ${chatId}`,
                    );
                  }
                } catch (fcmError) {
                  console.error("❌ Error sending FCM to online user:", {
                    receiverId,
                    chatId,
                    error: fcmError,
                  });
                }
              } else {
                console.log(
                  `✅ Both users in same active chat - skipping FCM notification for online user ${receiverId} (message ${chatId})`,
                );
              }
            } else {
              // User is offline - send FCM push notification
              try {
                if (userMetadata?.fcmToken) {
                  console.log("📨 Attempting FCM delivery to offline user", {
                    receiverId,
                    chatId,
                    tokenPreview: userMetadata.fcmToken.substring(0, 20),
                  });

                  const fcmResult = await sendDataMessage(
                    userMetadata.fcmToken,
                    {
                      senderId: senderId,
                      chatId: chatId,
                      senderFirstName: senderDetails?.firstName || "",
                      sender_chat_picture: senderDetails?.chat_picture || "",
                      sender_mobile_number: senderDetails?.mobileNo || "",
                      body: JSON.stringify({
                        message: message || null,
                        messageType: messageType,
                        fileUrl: fileUrl || null,
                        mimeType: mimeType || null,
                        contactPayload: contactPayload || null,
                      }),
                      title: "", // Empty - let client decide
                    },
                  );

                  if (fcmResult.success) {
                    console.log(
                      `✅ FCM sent to offline user ${receiverId} for message ${chatId}`,
                    );
                  } else if (fcmResult.reason === "invalid_token") {
                    // console.warn(`⚠️ Invalid FCM token for offline user ${receiverId}, notification skipped (message ${chatId})`);
                  } else {
                    console.error(
                      `❌ FCM send failed for offline user ${receiverId}, message ${chatId}:`,
                      fcmResult.reason,
                    );
                  }
                } else {
                  console.log(
                    `ℹ️ No FCM token for offline user ${receiverId}, cannot deliver message ${chatId}`,
                  );
                }
              } catch (fcmError) {
                console.error("❌ Error sending FCM notification:", {
                  receiverId,
                  chatId,
                  error: fcmError,
                });
              }
            }
          } catch (error) {
            console.error("Error sending message:", error);
            socket.emit("message-error", { error: "Failed to send message" });
          }
        },
      );

      socket.on(
        "poll-add-vote",
        async (data: { pollMessageId: string; optionId: string }) => {
          try {
            const userId = authenticatedUserId;
            const { pollMessageId, optionId } = data;

            // 1. Load poll
            const pollMessage = await Chat.findByPk(pollMessageId, {
              raw: true,
            });
            console.log(pollMessage);
            if (!pollMessage || pollMessage?.messageType !== "poll") {
              return socket.emit("poll-error", { message: "Invalid poll" });
            }

            // delete the existing vote for this user
            await PollVote.destroy({
              where: {
                pollMessageId,
                userId,
              },
            });

            //create new vote
            await PollVote.create({
              pollMessageId,
              userId,
              optionId,
            });

            // 5. Get updated results
            const votes = await PollVote.findAll({ where: { pollMessageId } });

            // 6. Emit updated results
            socket.emit("poll-vote-data", { votes });

            const receiverSocketId = this.connectedUsers.get(
              pollMessage.receiverId,
            );
            if (receiverSocketId) {
              this.io.to(receiverSocketId).emit("poll-vote-data", { votes });
            }
          } catch (err) {
            console.error(err);
            socket.emit("poll-error", { message: "Failed to vote" });
          }
        },
      );

      socket.on("poll-remove-vote", async (data: { pollMessageId: string }) => {
        try {
          const userId = authenticatedUserId;
          const { pollMessageId } = data;

          // 1. Load poll
          const pollMessage = await Chat.findByPk(pollMessageId, { raw: true });

          if (!pollMessage || pollMessage.messageType !== "poll") {
            return socket.emit("poll-error", { message: "Invalid poll" });
          }

          // delete the existing vote for this user
          await PollVote.destroy({
            where: {
              pollMessageId,
              userId,
            },
          });

          // 5. Get updated results
          const votes = await PollVote.findAll({ where: { pollMessageId } });

          // 6. Emit updated results
          socket.emit("poll-vote", { votes });

          const receiverSocketId = this.connectedUsers.get(
            pollMessage.receiverId,
          );
          if (receiverSocketId) {
            this.io.to(receiverSocketId).emit("poll-vote-data", { votes });
          }
        } catch (err) {
          console.error(err);
          socket.emit("poll-error", { message: "Failed to remove vote" });
        }
      });

      // ================== Chat Stories (Socket-first) ==================
      socket.on("stories:create", async (data: any) => {
        const { requestId, mediaUrl, mediaType, caption, duration, thumbnailUrl, videoDuration } = data || {};

        if (!authenticatedUserId) {
          return socket.emit("stories:ack", {
            action: "create",
            requestId,
            success: false,
            message: "User not authenticated",
          });
        }

        if (!requestId) {
          return socket.emit("stories:ack", {
            action: "create",
            requestId: null,
            success: false,
            message: "requestId is required",
          });
        }

        if (!mediaUrl) {
          return socket.emit("stories:ack", {
            action: "create",
            requestId,
            success: false,
            message: "mediaUrl is required",
          });
        }

        if (!mediaType || !["image", "video"].includes(mediaType)) {
          return socket.emit("stories:ack", {
            action: "create",
            requestId,
            success: false,
            message: "Invalid mediaType",
          });
        }

        // For video stories, use actual video duration as display duration if available
        const parsedDuration = mediaType === "video" && videoDuration
          ? Math.ceil(videoDuration)
          : (typeof duration === "number" && duration > 0 ? duration : 5);

        try {
          const story = await storyService.createStory(
            authenticatedUserId,
            mediaUrl,
            mediaType,
            caption,
            parsedDuration,
            undefined, // backgroundColor
            24, // expiresInHours
            thumbnailUrl || null,
            videoDuration || null,
          );

          socket.emit("stories:ack", {
            action: "create",
            requestId,
            success: true,
            story,
          });

          await this.notifyContactsAboutNewStory(authenticatedUserId, {
            storyId: story.id,
            mediaUrl: story.mediaUrl,
            mediaType: story.mediaType,
            thumbnailUrl: story.thumbnailUrl,
            videoDuration: story.videoDuration,
            createdAt: story.createdAt,
          });
        } catch (error: any) {
          console.error("❌ Error creating story via socket:", error);
          socket.emit("stories:ack", {
            action: "create",
            requestId,
            success: false,
            message: error?.message || "Failed to create story",
          });
        }
      });

      socket.on("stories:get-contacts", async (data: any) => {
        const { requestId } = data || {};

        if (!authenticatedUserId) {
          return socket.emit("stories:ack", {
            action: "get-contacts",
            requestId,
            success: false,
            message: "User not authenticated",
          });
        }

        try {
          const stories = await storyService.getContactsStories(authenticatedUserId);
          socket.emit("stories:ack", {
            action: "get-contacts",
            requestId,
            success: true,
            stories,
          });
        } catch (error: any) {
          socket.emit("stories:ack", {
            action: "get-contacts",
            requestId,
            success: false,
            message: error?.message || "Failed to fetch stories",
          });
        }
      });

      socket.on("stories:get-my", async (data: any) => {
        const { requestId } = data || {};

        if (!authenticatedUserId) {
          return socket.emit("stories:ack", {
            action: "get-my",
            requestId,
            success: false,
            message: "User not authenticated",
          });
        }

        try {
          const stories = await storyService.getMyStories(authenticatedUserId);
          socket.emit("stories:ack", {
            action: "get-my",
            requestId,
            success: true,
            stories,
          });
        } catch (error: any) {
          socket.emit("stories:ack", {
            action: "get-my",
            requestId,
            success: false,
            message: error?.message || "Failed to fetch my stories",
          });
        }
      });

      socket.on("stories:get-user", async (data: any) => {
        const { requestId, userId } = data || {};

        if (!authenticatedUserId) {
          return socket.emit("stories:ack", {
            action: "get-user",
            requestId,
            success: false,
            message: "User not authenticated",
          });
        }

        if (!userId) {
          return socket.emit("stories:ack", {
            action: "get-user",
            requestId,
            success: false,
            message: "userId is required",
          });
        }

        try {
          const stories = await storyService.getUserStories(userId, authenticatedUserId);
          socket.emit("stories:ack", {
            action: "get-user",
            requestId,
            success: true,
            stories,
          });
        } catch (error: any) {
          socket.emit("stories:ack", {
            action: "get-user",
            requestId,
            success: false,
            message: error?.message || "Failed to fetch user stories",
          });
        }
      });

      socket.on("stories:mark-viewed", async (data: any) => {
        const { requestId, storyId } = data || {};

        if (!authenticatedUserId) {
          return socket.emit("stories:ack", {
            action: "mark-viewed",
            requestId,
            success: false,
            message: "User not authenticated",
          });
        }

        if (!storyId) {
          return socket.emit("stories:ack", {
            action: "mark-viewed",
            requestId,
            success: false,
            message: "storyId is required",
          });
        }

        try {
          const result = await storyService.markStoryAsViewed(storyId, authenticatedUserId);

          socket.emit("stories:ack", {
            action: "mark-viewed",
            requestId,
            ...result,
          });

          if ((result as any).success && (result as any).isNewView) {
            await this.notifyStoryOwnerAboutView(storyId, authenticatedUserId);
          }
        } catch (error: any) {
          socket.emit("stories:ack", {
            action: "mark-viewed",
            requestId,
            success: false,
            message: error?.message || "Failed to mark viewed",
          });
        }
      });

      socket.on("stories:get-viewers", async (data: any) => {
        const { requestId, storyId } = data || {};

        if (!authenticatedUserId) {
          return socket.emit("stories:ack", {
            action: "get-viewers",
            requestId,
            success: false,
            message: "User not authenticated",
          });
        }

        if (!storyId) {
          return socket.emit("stories:ack", {
            action: "get-viewers",
            requestId,
            success: false,
            message: "storyId is required",
          });
        }

        try {
          const result = await storyService.getStoryViewers(storyId, authenticatedUserId);
          socket.emit("stories:ack", {
            action: "get-viewers",
            requestId,
            ...result,
          });
        } catch (error: any) {
          socket.emit("stories:ack", {
            action: "get-viewers",
            requestId,
            success: false,
            message: error?.message || "Failed to fetch viewers",
          });
        }
      });

      socket.on("stories:delete", async (data: any) => {
        const { requestId, storyId } = data || {};

        if (!authenticatedUserId) {
          return socket.emit("stories:ack", {
            action: "delete",
            requestId,
            success: false,
            message: "User not authenticated",
          });
        }

        if (!storyId) {
          return socket.emit("stories:ack", {
            action: "delete",
            requestId,
            success: false,
            message: "storyId is required",
          });
        }

        try {
          const result = await storyService.deleteStory(storyId, authenticatedUserId);

          socket.emit("stories:ack", {
            action: "delete",
            requestId,
            ...result,
          });

          if ((result as any).success) {
            await this.notifyContactsAboutDeletedStory(authenticatedUserId, storyId);
          }
        } catch (error: any) {
          socket.emit("stories:ack", {
            action: "delete",
            requestId,
            success: false,
            message: error?.message || "Failed to delete story",
          });
        }
      });

      // Handle message acknowledgment from receiver
      socket.on(
        "message-received-ack",
        async (data: { chatId: string; receiverDeliveryChannel?: string }) => {
          try {
            const { chatId, receiverDeliveryChannel } = data;
            const receiverId = authenticatedUserId;

            if (!receiverId) {
              socket.emit("ack-error", { error: "User not authenticated" });
              return;
            }

            if (!chatId) {
              socket.emit("ack-error", { error: "Message ID is required" });
              return;
            }

            console.log(
              `📨 Message acknowledgment from ${receiverId} for message ${chatId}`,
            );

            // Update the message with receiver delivery channel and mark as delivered
            const [updatedCount] = await Chat.update(
              {
                messageStatus: "delivered",
                deliveredAt: new Date(),
                receiverDeliveryChannel: receiverDeliveryChannel || "socket",
              },
              {
                where: {
                  id: chatId,
                  receiverId: receiverId,
                  messageStatus: "sent",
                },
              },
            );

            if (updatedCount > 0) {
              // Fetch the updated message with reactions
              const MessageReaction =
                require("../db/models/message-reaction.model").default;

              const message = await Chat.findOne({
                where: { id: chatId },
                attributes: [
                  "id",
                  "senderId",
                  "receiverId",
                  "message",
                  "messageType",
                  "fileUrl",
                  "mimeType",
                  "messageStatus",
                  "deliveryChannel",
                  "receiverDeliveryChannel",
                  "deliveredAt",
                  "createdAt",
                ],
                include: [
                  {
                    model: MessageReaction,
                    as: "reactions",
                    attributes: ["id", "userId", "emoji", "createdAt"],
                    include: [
                      {
                        model: User,
                        as: "user",
                        attributes: [
                          "id",
                          "firstName",
                          "lastName",
                          "chat_picture",
                        ],
                      },
                    ],
                    required: false,
                  },
                ],
              });

              if (message) {
                const messageData = message.toJSON();
                // Send full message object back to sender
                const senderSocketId = this.connectedUsers.get(
                  messageData.senderId,
                );
                if (senderSocketId) {
                  this.io.to(senderSocketId).emit("message-status-update", {
                    chatId: messageData.id,
                    status: "delivered",
                    updatedAt: messageData.deliveredAt,
                    messageObject: {
                      chatId: messageData.id,
                      senderId: messageData.senderId,
                      receiverId: messageData.receiverId,
                      message: messageData.message,
                      messageType: messageData.messageType,
                      fileUrl: messageData.fileUrl,
                      mimeType: messageData.mimeType,
                      messageStatus: messageData.messageStatus,
                      deliveryChannel: messageData.deliveryChannel,
                      reactions: messageData.reactions || [],
                      receiverDeliveryChannel: message.receiverDeliveryChannel,
                      deliveredAt: message.deliveredAt,
                      createdAt: message.createdAt,
                    },
                  });

                  console.log(
                    `📡 Sent full message object with 'delivered' status to sender ${message.senderId}`,
                  );
                } else {
                  console.log(`⚠️ Sender ${message.senderId} is not connected`);
                }

                // Acknowledge to receiver
                socket.emit("ack-acknowledged", {
                  chatId: chatId,
                  status: "delivered",
                });
              }
            } else {
              console.log(
                `⚠️ Message ${chatId} not found or already delivered`,
              );
              socket.emit("ack-error", {
                error: "Message not found or already delivered",
              });
            }
          } catch (error) {
            console.error("❌ Error processing message acknowledgment:", error);
            socket.emit("ack-error", {
              error: "Failed to process acknowledgment",
            });
          }
        },
      );

      // Handle unified message status update (delivered, read, or both)
      socket.on("update-message-status", async (data: any) => {
        try {
          // Support both formats: chatId (singular) and chatIds (array)
          let chatIds: string[];
          if (data.chatId) {
            chatIds = [data.chatId]; // Convert single ID to array
          } else if (data.chatIds) {
            chatIds = Array.isArray(data.chatIds)
              ? data.chatIds
              : [data.chatIds];
          } else {
            chatIds = [];
          }

          // Use authenticated user ID from socket session (no need for client to send it)
          const userId = authenticatedUserId;
          const status = data.status;
          const receiverChannel = data.receiverDeliveryChannel || "socket"; // Default to 'socket' if not provided

          // Validate authenticated
          if (!userId) {
            socket.emit("status-update-error", {
              error: "User not authenticated",
            });

            return;
          }

          // Check if data is missing
          if (!chatIds || chatIds.length === 0 || !status) {
            socket.emit("status-update-error", {
              error: "Missing required fields: chatId/chatIds or status",
              received: { chatIds, status },
            });
            return;
          }

          const now = new Date();
          let updateFields: any = {};
          let whereCondition: any = {
            id: { [Op.in]: chatIds },
            receiverId: userId,
          };

          console.log("📊 Update status attempt:", {
            authenticatedUserId: userId,
            chatIds,
            status,
            whereCondition,
          });

          // Determine what to update based on status
          if (status === "delivered") {
            updateFields = {
              messageStatus: "delivered",
              deliveredAt: now,
              receiverDeliveryChannel: receiverChannel, // Track how receiver got the message
            };
            whereCondition.messageStatus = "sent"; // Only update if currently 'sent'
          } else if (status === "read") {
            updateFields = {
              messageStatus: "read",
              isRead: true,
              readAt: now,
              receiverDeliveryChannel: receiverChannel, // Track how receiver opened the message
            };
            // Also set deliveredAt if not set (in case message went straight to read)
            whereCondition.isRead = false; // Only update if not already read
          } else if (status === "both") {
            // Both users in chat screen - mark as delivered AND read at once
            // This is the WhatsApp behavior: when you're in chat, messages go straight to blue checkmarks
            updateFields = {
              messageStatus: "read",
              isRead: true,
              deliveredAt: now,
              readAt: now,
              receiverDeliveryChannel: receiverChannel, // Track how receiver opened the message
            };
            // No messageStatus condition - update regardless of current status
          }

          // Update messages in database
          const [updatedCount] = await Chat.update(updateFields, {
            where: whereCondition,
          });

          console.log("📊 Update result:", {
            updatedCount,
            updateFields,
            finalWhereCondition: whereCondition,
          });

          if (updatedCount > 0) {
            // Fetch updated messages to notify senders
            const messages = await Chat.findAll({
              where: { id: { [Op.in]: chatIds } },
              attributes: [
                "id",
                "senderId",
                "messageStatus",
                "deliveredAt",
                "readAt",
              ],
              raw: true,
            });

            console.log(
              `✅ Status updated for ${updatedCount} message(s). Notifying senders...`,
            );

            // Notify sender(s) about status change
            messages.forEach((msg: any) => {
              const senderSocketId = this.connectedUsers.get(msg.senderId);

              console.log(`📤 Broadcasting status to sender:`, {
                chatId: msg.id,
                senderId: msg.senderId,
                senderSocketId: senderSocketId || "NOT_CONNECTED",
                status: status,
                messageStatus: msg.messageStatus,
              });

              if (senderSocketId) {
                console.log(
                  `✅ Sender ${msg.senderId} is CONNECTED. Broadcasting status update...`,
                );

                // Determine the final status to emit
                // For 'both': skip 'delivered', go straight to 'read' (WhatsApp behavior - instant blue ticks when both in chat)
                const finalStatus = status === "both" ? "read" : status;
                const updatedAt =
                  status === "both" || status === "read"
                    ? msg.readAt
                    : msg.deliveredAt;

                this.io.to(senderSocketId).emit("message-status-update", {
                  chatId: msg.id,
                  status: finalStatus,
                  updatedAt: updatedAt,
                });
                console.log(
                  `📡 Emitted '${finalStatus}' status to ${msg.senderId} (socket: ${senderSocketId})`,
                );
              } else {
                console.warn(
                  `⚠️ Sender ${msg.senderId} is NOT CONNECTED. Cannot broadcast status update for message ${msg.id}`,
                );
              }
            });
          } else {
            console.warn(`⚠️ No messages updated. Check conditions:`, {
              chatIds,
              status,
              userId,
              whereCondition,
              reason:
                "Messages may already be in the requested status or user is not the receiver",
            });
          }

          // Acknowledge the status update
          socket.emit("status-update-acknowledged", {
            chatIds,
            status,
            updatedCount,
          });
        } catch (error) {
          console.error("❌ Error updating message status:", error);
          socket.emit("status-update-error", {
            error: "Failed to update message status",
          });
        }
      });

      // Chat Picture Like WebSocket Events (DEPRECATED - use REST API instead)
      // These are kept for backward compatibility but REST API /api/chat-picture-likes/toggle is preferred
      socket.on(
        "toggle-chat-picture-like",
        async (data: {
          likedUserId: string;
          target_chat_picture_id: string;
        }) => {
          try {
            if (!authenticatedUserId) {
              socket.emit("chat-picture-like-error", {
                error: "Not authenticated",
              });
              return;
            }

            if (!data.target_chat_picture_id) {
              socket.emit("chat-picture-like-error", {
                error: "target_chat_picture_id is required",
              });
              return;
            }

            const result = await toggleChatPictureLike(
              authenticatedUserId,
              data.likedUserId,
              data.target_chat_picture_id,
            );

            // Emit to the user who clicked
            socket.emit("chat-picture-like-toggled", {
              action: result.action,
              likeCount: result.likeCount,
              likeId: result.likeId,
              target_chat_picture_id: result.target_chat_picture_id,
              likedUserId: data.likedUserId,
            });

            // Send notification via the centralized notification system (handles WebSocket/FCM)
            if (result.action === "liked" && result.likeId) {
              await this.sendChatPictureLikeNotification({
                likeId: result.likeId,
                fromUserId: authenticatedUserId,
                toUserId: data.likedUserId,
                target_chat_picture_id: result.target_chat_picture_id,
              });
            }
          } catch (error) {
            console.error("Error toggling chat picture like:", error);
            socket.emit("chat-picture-like-error", {
              error: (error as Error).message,
            });
          }
        },
      );

      socket.on(
        "get-chat-picture-like-count",
        async (data: {
          likedUserId: string;
          target_chat_picture_id?: string;
        }) => {
          try {
            const count = await getChatPictureLikeCount(
              data.likedUserId,
              data.target_chat_picture_id,
            );

            socket.emit("chat-picture-like-count", {
              likedUserId: data.likedUserId,
              target_chat_picture_id: data.target_chat_picture_id || null,
              likeCount: count,
            });
          } catch (error) {
            console.error("Error getting chat picture like count:", error);
            socket.emit("chat-picture-like-error", {
              error: "Failed to get like count",
            });
          }
        },
      );

      socket.on(
        "check-chat-picture-like-status",
        async (data: {
          likedUserId: string;
          target_chat_picture_id: string;
        }) => {
          try {
            if (!authenticatedUserId) {
              socket.emit("chat-picture-like-error", {
                error: "Not authenticated",
              });
              return;
            }

            if (!data.target_chat_picture_id) {
              socket.emit("chat-picture-like-error", {
                error: "target_chat_picture_id is required",
              });
              return;
            }

            const isLiked = await hasUserLikedChatPicture(
              authenticatedUserId,
              data.likedUserId,
              data.target_chat_picture_id,
            );

            socket.emit("chat-picture-like-status", {
              likedUserId: data.likedUserId,
              target_chat_picture_id: data.target_chat_picture_id,
              isLiked,
            });
          } catch (error) {
            console.error("Error checking chat picture like status:", error);
            socket.emit("chat-picture-like-error", {
              error: "Failed to check like status",
            });
          }
        },
      );

      socket.on(
        "get-users-who-liked",
        async (data: {
          likedUserId: string;
          target_chat_picture_id?: string;
          limit?: number;
        }) => {
          try {
            const users = await getUsersWhoLikedChatPicture(
              data.likedUserId,
              data.target_chat_picture_id,
              data.limit || 50,
            );

            socket.emit("users-who-liked", {
              likedUserId: data.likedUserId,
              target_chat_picture_id: data.target_chat_picture_id || null,
              likeCount: users.length,
              users,
            });
          } catch (error) {
            console.error("Error getting users who liked:", error);
            socket.emit("chat-picture-like-error", {
              error: "Failed to get users who liked",
            });
          }
        },
      );
      socket.on("toggle-status-like", async (data: { statusId: string }) => {
        try {
          if (!authenticatedUserId) {
            socket.emit("status-like-error", { error: "Not authenticated" });
            return;
          }

          if (!data.statusId) {
            socket.emit("status-like-error", {
              error: "statusId is required",
            });
            return;
          }

          const { toggleStatusLike } = require("../services/status.service");
          const result = await toggleStatusLike(
            data.statusId,
            authenticatedUserId,
          );

          // Emit to the user who clicked
          socket.emit("status-like-toggled", {
            action: result.action,
            likeCount: result.likeCount,
            likeId: result.likeId,
            statusId: result.statusId,
          });

          // Send notification via the centralized notification system (handles WebSocket/FCM)
          if (
            result.action === "liked" &&
            result.likeId &&
            result.statusOwnerId &&
            result.statusText
          ) {
            await this.sendStatusLikeNotification({
              likeId: result.likeId,
              fromUserId: authenticatedUserId,
              toUserId: result.statusOwnerId,
              statusId: result.statusId,
              statusText: result.statusText,
            });
          }
        } catch (error) {
          console.error("Error toggling status like:", error);

          // Handle deleted status gracefully
          if ((error as Error).message === "STATUS_DELETED") {
            socket.emit("status-deleted", {
              statusId: data.statusId,
              message: "This status has been deleted",
            });
          } else {
            socket.emit("status-like-error", {
              error: (error as Error).message,
            });
          }
        }
      });

      socket.on("unlike-status", async (data: { statusId: string }) => {
        try {
          if (!authenticatedUserId) {
            socket.emit("status-like-error", { error: "Not authenticated" });
            return;
          }

          if (!data.statusId) {
            socket.emit("status-like-error", {
              error: "statusId is required",
            });
            return;
          }

          const { unlikeStatus } = require("../services/status.service");
          const likeCount = await unlikeStatus(
            data.statusId,
            authenticatedUserId,
          );

          // Emit to the user who clicked
          socket.emit("status-unliked", {
            statusId: data.statusId,
            likeCount,
          });
        } catch (error) {
          console.error("Error unliking status:", error);
          socket.emit("status-like-error", {
            error: (error as Error).message,
          });
        }
      });

      socket.on("get-status-like-count", async (data: { statusId: string }) => {
        try {
          if (!data.statusId) {
            socket.emit("status-like-error", {
              error: "statusId is required",
            });
            return;
          }

          const { getStatusLikeCount } = require("../services/status.service");
          const count = await getStatusLikeCount(data.statusId);

          socket.emit("status-like-count", {
            statusId: data.statusId,
            likeCount: count,
          });
        } catch (error) {
          console.error("Error getting status like count:", error);
          socket.emit("status-like-error", {
            error: "Failed to get like count",
          });
        }
      });

      socket.on(
        "check-status-like-status",
        async (data: { statusId: string }) => {
          try {
            if (!authenticatedUserId) {
              socket.emit("status-like-error", { error: "Not authenticated" });
              return;
            }

            if (!data.statusId) {
              socket.emit("status-like-error", {
                error: "statusId is required",
              });
              return;
            }

            const {
              hasUserLikedStatus,
            } = require("../services/status.service");
            const isLiked = await hasUserLikedStatus(
              data.statusId,
              authenticatedUserId,
            );

            socket.emit("status-like-status", {
              statusId: data.statusId,
              isLiked,
            });
          } catch (error) {
            console.error("Error checking status like status:", error);
            socket.emit("status-like-error", {
              error: "Failed to check like status",
            });
          }
        },
      );

      socket.on(
        "get-users-who-liked-status",
        async (data: { statusId: string; limit?: number }) => {
          try {
            if (!data.statusId) {
              socket.emit("status-like-error", {
                error: "statusId is required",
              });
              return;
            }

            const { getStatusLikes } = require("../services/status.service");
            const likes = await getStatusLikes(data.statusId);

            // Limit the results if specified
            const limitedLikes = data.limit
              ? likes.slice(0, data.limit)
              : likes;

            // Extract user information
            const users = limitedLikes.map((like: any) => ({
              id: like.User?.id,
              firstName: like.User?.firstName,
              lastName: like.User?.lastName,
              profile_pic: like.User?.profile_pic,
              likedAt: like.createdAt,
            }));

            socket.emit("users-who-liked-status", {
              statusId: data.statusId,
              likeCount: likes.length,
              users,
            });
          } catch (error) {
            console.error("Error getting users who liked status:", error);
            socket.emit("status-like-error", {
              error: "Failed to get users who liked",
            });
          }
        },
      );
      // ============================================
      // MESSAGE REACTIONS (WhatsApp-style)
      // ============================================

      /**
       * Add or update a reaction to a message
       * Event: 'add-reaction'
       * Data: { messageId: string, emoji: string }
       *
       * WhatsApp behavior:
       * - Same emoji = toggle (remove)
       * - Different emoji = update
       * - First time = add
       */
      socket.on(
        "add-reaction",
        async (data: { messageId: string; emoji: string }) => {
          try {
            const { messageId, emoji } = data;

            if (!authenticatedUserId) {
              socket.emit("reaction-error", {
                error: "User not authenticated",
              });
              return;
            }

            if (!messageId || !emoji) {
              socket.emit("reaction-error", {
                error: "messageId and emoji are required",
              });
              return;
            }

            // Import reaction service
            const messageReactionService = require("../services/message-reaction.service");

            try {
              // Add or update reaction
              const reaction = await messageReactionService.addOrUpdateReaction(
                messageId,
                authenticatedUserId,
                emoji,
              );

              // Get updated reactions
              const messageReactions =
                await messageReactionService.getMessageReactions(
                  messageId,
                  authenticatedUserId,
                );

              // Get the message to find sender and receiver
              const message = await Chat.findByPk(messageId);
              if (!message) {
                socket.emit("reaction-error", { error: "Message not found" });
                return;
              }

              const reactionData = {
                messageId,
                userId: authenticatedUserId,
                emoji,
                action: "added",
                reactions: messageReactions,
                timestamp: new Date().toISOString(),
              };

              // Notify the user who added the reaction
              socket.emit("reaction-updated", reactionData);

              // Notify the other user (sender or receiver)
              const otherUserId =
                message.senderId === authenticatedUserId
                  ? message.receiverId
                  : message.senderId;

              const otherSocketId = this.connectedUsers.get(otherUserId);
              if (otherSocketId) {
                this.io
                  .to(otherSocketId)
                  .emit("reaction-updated", reactionData);
                console.log(
                  `📱 Reaction notification sent to user ${otherUserId}`,
                );
              } else {
                // Other user is offline — send FCM push notification
                try {
                  const reactor = await getById(authenticatedUserId);
                  const reactorName = reactor
                    ? `${reactor.firstName || ""} ${reactor.lastName || ""}`.trim()
                    : "Someone";
                  await sendReactionNotificationToUser({
                    receiverId: otherUserId,
                    reactorId: authenticatedUserId,
                    reactorName,
                    emoji,
                    messageText: message.message || "",
                    messageId,
                    isYou: false,
                  });
                } catch (fcmErr) {
                  console.error("⚠️ Failed to send reaction FCM:", fcmErr);
                }
              }

              // Emit chat-activity-updated so chat list reflects the reaction
              const activityData = {
                type: "reaction",
                messageId,
                emoji,
                action: "added",
                userId: authenticatedUserId,
                otherUserId,
                timestamp: new Date().toISOString(),
              };
              this.emitChatActivityUpdate(authenticatedUserId, activityData);
              this.emitChatActivityUpdate(otherUserId, activityData);

              console.log(
                `✅ Reaction ${emoji} added to message ${messageId} by user ${authenticatedUserId}`,
              );
            } catch (error: any) {
              // Handle toggle (remove) case
              if (error.message === "REACTION_REMOVED") {
                const messageReactions =
                  await messageReactionService.getMessageReactions(
                    messageId,
                    authenticatedUserId,
                  );

                const message = await Chat.findByPk(messageId);
                if (message) {
                  const reactionData = {
                    messageId,
                    userId: authenticatedUserId,
                    emoji,
                    action: "removed",
                    reactions: messageReactions,
                    timestamp: new Date().toISOString(),
                  };

                  // Notify the user who removed the reaction
                  socket.emit("reaction-updated", reactionData);

                  // Notify the other user
                  const otherUserId =
                    message.senderId === authenticatedUserId
                      ? message.receiverId
                      : message.senderId;

                  const otherSocketId = this.connectedUsers.get(otherUserId);
                  if (otherSocketId) {
                    this.io
                      .to(otherSocketId)
                      .emit("reaction-updated", reactionData);
                  }

                  // Emit chat-activity-updated so chat list reflects the removal
                  const activityData = {
                    type: "reaction",
                    messageId,
                    emoji,
                    action: "removed",
                    userId: authenticatedUserId,
                    otherUserId,
                    timestamp: new Date().toISOString(),
                  };
                  this.emitChatActivityUpdate(authenticatedUserId, activityData);
                  this.emitChatActivityUpdate(otherUserId, activityData);

                  console.log(
                    `✅ Reaction ${emoji} removed from message ${messageId} by user ${authenticatedUserId}`,
                  );
                }
              } else {
                throw error;
              }
            }
          } catch (error) {
            console.error("Error adding reaction:", error);
            socket.emit("reaction-error", { error: "Failed to add reaction" });
          }
        },
      );

      /**
       * Remove a reaction from a message
       * Event: 'remove-reaction'
       * Data: { messageId: string }
       */
      socket.on("remove-reaction", async (data: { messageId: string }) => {
        try {
          const { messageId } = data;

          if (!authenticatedUserId) {
            socket.emit("reaction-error", { error: "User not authenticated" });
            return;
          }

          if (!messageId) {
            socket.emit("reaction-error", { error: "messageId is required" });
            return;
          }

          const messageReactionService = require("../services/message-reaction.service");

          const removed = await messageReactionService.removeReaction(
            messageId,
            authenticatedUserId,
          );

          if (!removed) {
            socket.emit("reaction-error", { error: "Reaction not found" });
            return;
          }

          // Get updated reactions
          const messageReactions =
            await messageReactionService.getMessageReactions(
              messageId,
              authenticatedUserId,
            );

          // Get the message to find sender and receiver
          const message = await Chat.findByPk(messageId);
          if (message) {
            const reactionData = {
              messageId,
              userId: authenticatedUserId,
              action: "removed",
              reactions: messageReactions,
              timestamp: new Date().toISOString(),
            };

            // Notify the user who removed the reaction
            socket.emit("reaction-updated", reactionData);

            // Notify the other user
            const otherUserId =
              message.senderId === authenticatedUserId
                ? message.receiverId
                : message.senderId;

            const otherSocketId = this.connectedUsers.get(otherUserId);
            if (otherSocketId) {
              this.io.to(otherSocketId).emit("reaction-updated", reactionData);
            }

            // Emit chat-activity-updated so chat list reflects the removal
            const activityData = {
              type: "reaction",
              messageId,
              action: "removed",
              userId: authenticatedUserId,
              otherUserId,
              timestamp: new Date().toISOString(),
            };
            this.emitChatActivityUpdate(authenticatedUserId, activityData);
            this.emitChatActivityUpdate(otherUserId, activityData);

            console.log(
              `✅ Reaction removed from message ${messageId} by user ${authenticatedUserId}`,
            );
          }
        } catch (error) {
          console.error("Error removing reaction:", error);
          socket.emit("reaction-error", { error: "Failed to remove reaction" });
        }
      });

      /**
       * Get reactions for a specific message
       * Event: 'get-message-reactions'
       * Data: { messageId: string }
       */
      socket.on(
        "get-message-reactions",
        async (data: { messageId: string }) => {
          try {
            const { messageId } = data;

            if (!messageId) {
              socket.emit("reaction-error", { error: "messageId is required" });
              return;
            }

            const messageReactionService = require("../services/message-reaction.service");

            const reactions = await messageReactionService.getMessageReactions(
              messageId,
              authenticatedUserId,
            );

            socket.emit("message-reactions", {
              messageId,
              reactions,
            });
          } catch (error) {
            console.error("Error getting message reactions:", error);
            socket.emit("reaction-error", { error: "Failed to get reactions" });
          }
        },
      );

      // Delete message websocket
      socket.on(
        "delete-message",
        async (data: { chatId: string; deleteType: string }) => {
          try {
            const { chatId, deleteType } = data; // deleteType: 'me' or 'everyone

            // deleteType is me, receiverId will be null
            if (!authenticatedUserId) {
              socket.emit("delete-message-error", {
                error: "User not authenticated",
              });
              return;
            }

            if (!chatId) {
              socket.emit("delete-message-error", {
                error: "Chat ID is required",
              });
              return;
            }

            // Find the message
            const message = await Chat.findByPk(chatId, { raw: true });

            if (!message) {
              // Idempotent: if message doesn't exist, treat as already deleted (success)
              socket.emit("message-deleted", {
                chatId,
                senderId: authenticatedUserId,
                receiverId: null,
                deleteType,
                deletedAt: new Date(),
                deletedBy: authenticatedUserId,
              });
              return;
            }
            // Check if the user is the sender of the message
            if (message.senderId !== authenticatedUserId) {
              socket.emit("delete-message-error", {
                error: "You can only delete your own messages",
              });
              return;
            }

            if (deleteType === "everyone") {
              if (
                new Date(message.createdAt) <
                new Date(Date.now() - 60 * 60 * 1000)
              ) {
                // cant delete after one hour of sending
                socket.emit("delete-message-error", {
                  error: "You can only delete messages sent in the last hour",
                });
                return;
              }
            }

            // Delete the message
            if (deleteType === "me") {
              await Chat.update(
                {
                  deletedForSender: true,
                  deletedAt: new Date(),
                },
                {
                  where: {
                    id: chatId,
                    senderId: authenticatedUserId,
                  },
                },
              );
            } else {
              await Chat.update(
                {
                  deletedForSender: true,
                  deletedForReceiver: true,
                  deletedAt: new Date(),
                  message: null,
                  fileUrl: null,
                  mimeType: null,
                },
                {
                  where: {
                    id: chatId,
                    senderId: authenticatedUserId,
                  },
                },
              );
            }
            // Notify via WebSocket if available
            const senderSocketId = this.connectedUsers.get(authenticatedUserId);

            const deletionData = {
              chatId,
              senderId: authenticatedUserId,
              receiverId: message.receiverId,
              deleteType,
              deletedAt: new Date(),
              deletedBy: authenticatedUserId,
            };

            // Notify sender
            if (senderSocketId) {
              this.io.to(senderSocketId).emit("message-deleted", deletionData);
            }

            // if delete type is everyone, notify receiver
            if (deleteType === "everyone") {
              const receiverSocketId = this.connectedUsers.get(
                message.receiverId,
              );
              if (receiverSocketId) {
                this.io
                  .to(receiverSocketId)
                  .emit("message-deleted", deletionData);
              }
            }
          } catch (error) {
            console.error("Error deleting message:", error);
            socket.emit("delete-message-error", {
              error: "Failed to delete message",
            });
            return;
          }
        },
      );

      // Edit message websocket (WhatsApp style)
      socket.on(
        "edit-message",
        async (data: { chatId: string; newMessage: string }) => {
          try {
            const { chatId, newMessage } = data;

            if (!authenticatedUserId) {
              socket.emit("edit-message-error", {
                error: "User not authenticated",
              });
              return;
            }

            if (!chatId) {
              socket.emit("edit-message-error", {
                error: "Chat ID is required",
              });
              return;
            }

            if (!newMessage || newMessage.trim().length === 0) {
              socket.emit("edit-message-error", {
                error: "New message cannot be empty",
              });
              return;
            }

            // Find the message
            const message = await Chat.findByPk(chatId, { raw: true });

            if (!message) {
              socket.emit("edit-message-error", {
                error: "Message not found",
              });
              return;
            }

            // Check if the user is the sender
            if (message.senderId !== authenticatedUserId) {
              socket.emit("edit-message-error", {
                error: "You can only edit your own messages",
              });
              return;
            }

            // WhatsApp allows editing text messages and captions on media
            // For media (image/video/pdf), we edit the caption (message field)
            // Text messages and media with captions can be edited
            if (
              message.messageType !== "text" &&
              message.messageType !== "image" &&
              message.messageType !== "video" &&
              message.messageType !== "pdf"
            ) {
              socket.emit("edit-message-error", {
                error: "Only text messages and media captions can be edited",
              });
              return;
            }

            // For media files, check if there's a caption to edit
            if (
              message.messageType !== "text" &&
              (!message.message || message.message.trim().length === 0)
            ) {
              socket.emit("edit-message-error", {
                error: "This media has no caption to edit",
              });
              return;
            }

            // Check if message was deleted
            if (message.deletedForSender || message.deletedForReceiver) {
              socket.emit("edit-message-error", {
                error: "Cannot edit deleted message",
              });
              return;
            }

            // WhatsApp allows editing within 15 minutes
            const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);
            if (new Date(message.createdAt) < fifteenMinutesAgo) {
              socket.emit("edit-message-error", {
                error: "Messages can only be edited within 15 minutes",
              });
              return;
            }

            // Update the message
            const editedAt = new Date();
            await Chat.update(
              {
                message: newMessage.trim(),
                isEdited: true,
                editedAt: editedAt,
              },
              {
                where: { id: chatId },
              },
            );

            console.log(
              `✏️ Message ${chatId} edited by ${authenticatedUserId}`,
            );

            const editData = {
              chatId,
              senderId: message.senderId,
              receiverId: message.receiverId,
              newMessage: newMessage.trim(),
              isEdited: true,
              editedAt: editedAt.toISOString(),
            };

            // Confirm to sender
            socket.emit("message-edited", editData);

            // Notify receiver if online
            const receiverSocketId = this.connectedUsers.get(
              message.receiverId,
            );
            if (receiverSocketId) {
              this.io.to(receiverSocketId).emit("message-edited", editData);
              console.log(
                `📤 Edit notification sent to receiver ${message.receiverId}`,
              );
            }
          } catch (error) {
            console.error("❌ Error editing message:", error);
            socket.emit("edit-message-error", {
              error: "Failed to edit message",
            });
          }
        },
      );

      socket.on("star-message", async (data: { chatId: string }) => {
        const { chatId } = data;

        if (!authenticatedUserId) {
          socket.emit("star-message-error", {
            error: "User not authenticated",
          });
          return;
        }

        if (!chatId) {
          socket.emit("star-message-error", {
            error: "Chat ID is required",
          });
          return;
        }

        const chat = await Chat.findOne({
          where: {
            id: chatId,
            [Op.or]: [
              { senderId: authenticatedUserId },
              { receiverId: authenticatedUserId },
            ],
          },
        });

        if (!chat) {
          socket.emit("star-message-error", {
            error: "Not authorized to star this message",
          });
          return;
        }

        try {
          const [star, created] = await StarredMessage.findOrCreate({
            where: {
              userId: authenticatedUserId,
              chatId,
            },
          });

          socket.emit("message-starred", {
            chatId,
            starred: true,
            alreadyStarred: !created,
          });
        } catch (error) {
          console.error("Error starring message:", error);
          socket.emit("star-message-error", {
            error: "Failed to star message",
          });
        }
      });

      socket.on("unstar-message", async (data: { chatId: string }) => {
        const { chatId } = data;

        if (!authenticatedUserId) {
          socket.emit("unstar-message-error", {
            error: "User not authenticated",
          });
          return;
        }

        if (!chatId) {
          socket.emit("unstar-message-error", {
            error: "Chat ID is required",
          });
          return;
        }

        try {
          await StarredMessage.destroy({
            where: {
              userId: authenticatedUserId,
              chatId,
            },
          });
          socket.emit("message-unstarred", {
            chatId,
            starred: false,
          });
        } catch (error) {
          console.error("Error unstarring message:", error);
          socket.emit("unstar-message-error", {
            error: "Failed to unstar message",
          });
        }
      });

      // Client-side heartbeat: Flutter sends ping-check to detect dead connections
      socket.on("ping-check", () => {
        socket.emit("pong-check");
      });

      // ============================================
      // AUDIO/VIDEO CALL SIGNALING (WhatsApp-style)
      // ============================================

      /**
       * Caller initiates a call
       * Event: 'call-initiate'
       * Data: { callId, calleeId, callType, channelName }
       */
      socket.on(
        "call-initiate",
        async (data: {
          callId: string;
          calleeId: string;
          callType: "voice" | "video";
          channelName: string;
        }) => {
          try {
            const { callId, calleeId, callType, channelName } = data;

            if (!authenticatedUserId) {
              socket.emit("call-error", {
                callId,
                message: "User not authenticated",
              });
              return;
            }

            if (!callId || !calleeId || !callType || !channelName) {
              socket.emit("call-error", {
                callId,
                message: "callId, calleeId, callType, and channelName are required",
              });
              return;
            }

            // Don't allow calling yourself
            if (authenticatedUserId === calleeId) {
              socket.emit("call-error", {
                callId,
                message: "Cannot call yourself",
              });
              return;
            }

            // Check if callee is already in an active call
            const calleeActiveCallId = this.activeCallUsers.get(calleeId);
            if (calleeActiveCallId) {
              socket.emit("call-rejected", { callId });
              console.log(
                `📞 Callee ${calleeId} is busy in call ${calleeActiveCallId}, rejecting ${callId}`,
              );
              return;
            }

            // Mark both users as in active call
            this.activeCallUsers.set(authenticatedUserId, callId);
            this.activeCallUsers.set(calleeId, callId);

            // Save call log to database
            try {
              await CallLog.create({
                callId,
                callerId: authenticatedUserId,
                calleeId,
                callType,
                channelName,
                status: "initiated",
                startedAt: new Date(),
              });
              console.log(`💾 Call log saved: ${callId}`);
            } catch (dbError) {
              console.error("❌ Failed to save call log:", dbError);
              // Continue with call even if DB save fails
            }

            // Get caller details for the callee's incoming call screen
            const callerUser = await getById(authenticatedUserId);
            const callerName = callerUser
              ? `${callerUser.firstName || ""} ${callerUser.lastName || ""}`.trim()
              : "Unknown";
            const callerProfilePic = callerUser?.chat_picture || null;

            // Static authentication - no tokens needed
            console.log(`🎫 Using static authentication for channel: ${channelName}`);

            // Check if callee is connected via WebSocket
            const calleeSocketId = this.connectedUsers.get(calleeId);

            if (calleeSocketId) {
              // Callee is online — send call-incoming via WebSocket
              this.io.to(calleeSocketId).emit("call-incoming", {
                callId,
                callerId: authenticatedUserId,
                callerName,
                callerProfilePic,
                callType,
                channelName,
              });

              // Update call log to ringing
              await CallLog.update(
                { status: "ringing" },
                { where: { callId } }
              ).catch((err) => console.error("Failed to update call log:", err));

              // Tell caller the phone is ringing
              socket.emit("call-ringing", { callId });

              console.log(
                `📞 Call ${callId}: ${authenticatedUserId} → ${calleeId} (${callType}) — callee online, ringing`,
              );
            } else {
              // Callee is offline — send FCM push and tell caller
              try {
                const fcmResult = await sendIncomingCallToUser({
                  receiverId: calleeId,
                  callId,
                  callerId: authenticatedUserId,
                  callerName,
                  callerProfilePic: callerProfilePic || "",
                  callType,
                  channelName,
                });

                if (fcmResult.success) {
                  // FCM sent — tell caller to wait (callee may wake up)
                  socket.emit("call-ringing", { callId });

                  // Update call log to ringing
                  await CallLog.update(
                    { status: "ringing" },
                    { where: { callId } }
                  ).catch((err) => console.error("Failed to update call log:", err));

                  console.log(
                    `📞 Call ${callId}: ${authenticatedUserId} → ${calleeId} (${callType}) — callee offline, FCM sent`,
                  );
                } else {
                  // No FCM tokens — callee truly unreachable
                  socket.emit("call-unavailable", { callId });

                  // Update call log to unavailable
                  await CallLog.update(
                    { status: "unavailable", endedAt: new Date() },
                    { where: { callId } }
                  ).catch((err) => console.error("Failed to update call log:", err));

                  // Clean up active call tracking
                  this.activeCallUsers.delete(authenticatedUserId);
                  this.activeCallUsers.delete(calleeId);
                  console.log(
                    `📞 Call ${callId}: callee ${calleeId} unavailable (no FCM tokens)`,
                  );
                  return;
                }
              } catch (fcmErr) {
                console.error("⚠️ Failed to send call FCM:", fcmErr);
                socket.emit("call-unavailable", { callId });

                // Update call log to unavailable
                await CallLog.update(
                  { status: "unavailable", endedAt: new Date() },
                  { where: { callId } }
                ).catch((err) => console.error("Failed to update call log:", err));

                this.activeCallUsers.delete(authenticatedUserId);
                this.activeCallUsers.delete(calleeId);
                return;
              }
            }

            // Capture callerId for use inside setTimeout closure (TypeScript narrowing)
            const callerId = authenticatedUserId;

            // Start 45-second timeout for unanswered call
            const timeout = setTimeout(async () => {
              console.log(`📞 Call ${callId}: 45s timeout — missed call`);

              // Update call log to missed
              await CallLog.update(
                { status: "missed", endedAt: new Date() },
                { where: { callId } }
              ).catch((err) => console.error("Failed to update call log:", err));

              // Notify caller
              const callerSocketId = this.connectedUsers.get(callerId);
              if (callerSocketId) {
                this.io.to(callerSocketId).emit("call-missed", { callId });
              }

              // Notify callee
              const currentCalleeSocketId = this.connectedUsers.get(calleeId);
              if (currentCalleeSocketId) {
                this.io.to(currentCalleeSocketId).emit("call-missed", { callId });
              }

              // Clean up
              this.callTimeouts.delete(callId);
              this.activeCallUsers.delete(callerId);
              this.activeCallUsers.delete(calleeId);
            }, 45000);

            this.callTimeouts.set(callId, timeout);
          } catch (error) {
            console.error("Error initiating call:", error);
            socket.emit("call-error", {
              callId: data?.callId,
              message: "Failed to initiate call",
            });
          }
        },
      );

      /**
       * Callee accepts the incoming call
       * Event: 'call-accept'
       * Data: { callId, callerId }
       */
      socket.on(
        "call-accept",
        async (data: { callId: string; callerId: string }) => {
          try {
            const { callId, callerId } = data;

            if (!authenticatedUserId) {
              socket.emit("call-error", {
                callId,
                message: "User not authenticated",
              });
              return;
            }

            // Cancel the 45s timeout
            const timeout = this.callTimeouts.get(callId);
            if (timeout) {
              clearTimeout(timeout);
              this.callTimeouts.delete(callId);
            }

            // Update call log to accepted with answeredAt timestamp
            const answeredAt = new Date();
            await CallLog.update(
              { status: "accepted", answeredAt },
              { where: { callId } }
            ).catch((err) => console.error("Failed to update call log:", err));

            // Look up channelName from call log for call acceptance
            const callLog = await CallLog.findOne({ where: { callId }, attributes: ["channelName"] });
            const channelName = callLog?.channelName || callId;
            
            console.log(`🎫 Call accepted for channel: ${channelName}`);

            // Notify the caller that the call was accepted
            const callerSocketId = this.connectedUsers.get(callerId);
            if (callerSocketId) {
              console.log(`📡 Emitting call-accepted to caller ${callerId} (socket: ${callerSocketId})`);
              this.io.to(callerSocketId).emit("call-accepted", { callId });
            } else {
              console.warn(`⚠️ Caller ${callerId} not found in connectedUsers during accept`);
            }

            console.log(
              `📞 Call ${callId}: accepted by ${authenticatedUserId}`,
            );
          } catch (error) {
            console.error("Error accepting call:", error);
            socket.emit("call-error", {
              callId: data?.callId,
              message: "Failed to accept call",
            });
          }
        },
      );

      /**
       * Callee rejects the incoming call
       * Event: 'call-reject'
       * Data: { callId, callerId }
       */
      socket.on(
        "call-reject",
        async (data: { callId: string; callerId: string }) => {
          try {
            const { callId, callerId } = data;

            if (!authenticatedUserId) {
              socket.emit("call-error", {
                callId,
                message: "User not authenticated",
              });
              return;
            }

            // Cancel the 45s timeout
            const timeout = this.callTimeouts.get(callId);
            if (timeout) {
              clearTimeout(timeout);
              this.callTimeouts.delete(callId);
            }

            // Update call log to rejected
            await CallLog.update(
              { status: "rejected", endedAt: new Date() },
              { where: { callId } }
            ).catch((err) => console.error("Failed to update call log:", err));

            // Notify the caller that the call was rejected
            const callerSocketId = this.connectedUsers.get(callerId);
            if (callerSocketId) {
              this.io.to(callerSocketId).emit("call-rejected", { callId });
            }

            // Clean up active call tracking
            this.activeCallUsers.delete(authenticatedUserId);
            this.activeCallUsers.delete(callerId);

            console.log(
              `📞 Call ${callId}: rejected by ${authenticatedUserId}`,
            );
          } catch (error) {
            console.error("Error rejecting call:", error);
            socket.emit("call-error", {
              callId: data?.callId,
              message: "Failed to reject call",
            });
          }
        },
      );

      /**
       * Callee is busy (already in another call)
       * Event: 'call-busy'
       * Data: { callId, callerId }
       */
      socket.on(
        "call-busy",
        async (data: { callId: string; callerId: string }) => {
          try {
            const { callId, callerId } = data;

            if (!authenticatedUserId) {
              socket.emit("call-error", {
                callId,
                message: "User not authenticated",
              });
              return;
            }

            // Cancel the 45s timeout
            const timeout = this.callTimeouts.get(callId);
            if (timeout) {
              clearTimeout(timeout);
              this.callTimeouts.delete(callId);
            }

            // Update call log to busy
            await CallLog.update(
              { status: "busy", endedAt: new Date() },
              { where: { callId } }
            ).catch((err) => console.error("Failed to update call log:", err));

            // Notify the caller — treated as rejected from caller's perspective
            const callerSocketId = this.connectedUsers.get(callerId);
            if (callerSocketId) {
              this.io.to(callerSocketId).emit("call-rejected", { callId });
            }

            // Clean up — only remove the caller from active calls (callee is still in their other call)
            this.activeCallUsers.delete(callerId);

            console.log(
              `📞 Call ${callId}: ${authenticatedUserId} is busy, rejected for ${callerId}`,
            );
          } catch (error) {
            console.error("Error handling call-busy:", error);
            socket.emit("call-error", {
              callId: data?.callId,
              message: "Failed to handle busy signal",
            });
          }
        },
      );

      /**
       * Either party ends an active call (or caller cancels before answer)
       * Event: 'call-end'
       * Data: { callId, otherUserId }
       */
      socket.on(
        "call-end",
        async (data: { callId: string; otherUserId: string }) => {
          try {
            const { callId, otherUserId } = data;

            if (!authenticatedUserId) {
              socket.emit("call-error", {
                callId,
                message: "User not authenticated",
              });
              return;
            }

            // Cancel any pending timeout for this call
            const timeout = this.callTimeouts.get(callId);
            if (timeout) {
              clearTimeout(timeout);
              this.callTimeouts.delete(callId);
            }

            // Update call log to ended and calculate duration
            try {
              const callLog = await CallLog.findOne({ where: { callId } });
              if (callLog) {
                const endedAt = new Date();
                let duration = null;

                // Only calculate duration if call was answered
                if (callLog.answeredAt) {
                  duration = Math.floor(
                    (endedAt.getTime() - new Date(callLog.answeredAt).getTime()) / 1000
                  );
                }

                await CallLog.update(
                  {
                    status: "ended",
                    endedAt,
                    duration,
                    endedBy: authenticatedUserId,
                  },
                  { where: { callId } }
                );

                console.log(
                  `💾 Call ${callId} ended - Duration: ${duration ? `${duration}s` : "N/A (not answered)"}`,
                );
              }
            } catch (dbError) {
              console.error("Failed to update call log on end:", dbError);
            }

            // Notify the other party
            const otherSocketId = this.connectedUsers.get(otherUserId);
            if (otherSocketId) {
              this.io.to(otherSocketId).emit("call-ended", { callId });
            }

            // Clean up active call tracking for both users
            this.activeCallUsers.delete(authenticatedUserId);
            this.activeCallUsers.delete(otherUserId);

            console.log(
              `📞 Call ${callId}: ended by ${authenticatedUserId}`,
            );
          } catch (error) {
            console.error("Error ending call:", error);
            socket.emit("call-error", {
              callId: data?.callId,
              message: "Failed to end call",
            });
          }
        },
      );

      /**
       * Get call history for authenticated user
       * Event: 'get-call-history'
       * Data: { limit?, offset?, callType?, status? }
       */
      socket.on(
        "get-call-history",
        async (data: {
          limit?: number;
          offset?: number;
          callType?: "voice" | "video";
          status?: string;
        }) => {
          try {
            if (!authenticatedUserId) {
              socket.emit("call-history-error", {
                message: "User not authenticated",
              });
              return;
            }

            const { limit = 50, offset = 0, callType, status } = data || {};

            // Build filter conditions
            const whereConditions: any = {
              [Op.or]: [
                { callerId: authenticatedUserId },
                { calleeId: authenticatedUserId },
              ],
            };

            if (callType && (callType === "voice" || callType === "video")) {
              whereConditions.callType = callType;
            }

            if (status) {
              whereConditions.status = status;
            }

            const callLogs = await CallLog.findAll({
              where: whereConditions,
              include: [
                {
                  model: User,
                  as: "caller",
                  attributes: [
                    "id",
                    "firstName",
                    "lastName",
                    "chat_picture",
                    "mobileNo",
                  ],
                },
                {
                  model: User,
                  as: "callee",
                  attributes: [
                    "id",
                    "firstName",
                    "lastName",
                    "chat_picture",
                    "mobileNo",
                  ],
                },
              ],
              order: [["startedAt", "DESC"]],
              limit: parseInt(limit.toString()),
              offset: parseInt(offset.toString()),
            });

            // Format response to include call direction
            const formattedLogs = callLogs.map((log: any) => {
              const isOutgoing = log.callerId === authenticatedUserId;
              const otherUser = isOutgoing ? log.callee : log.caller;

              return {
                id: log.id,
                callId: log.callId,
                callType: log.callType,
                status: log.status,
                direction: isOutgoing ? "outgoing" : "incoming",
                otherUser: otherUser
                  ? {
                    id: otherUser.id,
                    firstName: otherUser.firstName,
                    lastName: otherUser.lastName,
                    chat_picture: otherUser.chat_picture,
                    mobileNo: otherUser.mobileNo,
                  }
                  : null,
                startedAt: log.startedAt,
                answeredAt: log.answeredAt,
                endedAt: log.endedAt,
                duration: log.duration,
                createdAt: log.createdAt,
              };
            });

            socket.emit("call-history-response", {
              success: true,
              data: formattedLogs,
              total: callLogs.length,
            });

            console.log(
              `📞 Call history sent to ${authenticatedUserId}: ${formattedLogs.length} calls`,
            );
          } catch (error) {
            console.error("Error fetching call history:", error);
            socket.emit("call-history-error", {
              message: "Failed to fetch call history",
            });
          }
        },
      );

      /**
       * Get missed calls count for authenticated user
       * Event: 'get-missed-calls-count'
       */
      socket.on("get-missed-calls-count", async () => {
        try {
          if (!authenticatedUserId) {
            socket.emit("missed-calls-count-error", {
              message: "User not authenticated",
            });
            return;
          }

          const count = await CallLog.count({
            where: {
              calleeId: authenticatedUserId,
              status: "missed",
            },
          });

          socket.emit("missed-calls-count-response", {
            success: true,
            count,
          });

          console.log(
            `📞 Missed calls count sent to ${authenticatedUserId}: ${count}`,
          );
        } catch (error) {
          console.error("Error fetching missed calls count:", error);
          socket.emit("missed-calls-count-error", {
            message: "Failed to fetch missed calls count",
          });
        }
      });

      /**
       * Get call statistics for authenticated user
       * Event: 'get-call-statistics'
       * Data: { startDate?, endDate? }
       */
      socket.on(
        "get-call-statistics",
        async (data: { startDate?: string; endDate?: string }) => {
          try {
            if (!authenticatedUserId) {
              socket.emit("call-statistics-error", {
                message: "User not authenticated",
              });
              return;
            }

            const { startDate, endDate } = data || {};

            // Build date filter
            const dateFilter: any = {};
            if (startDate) {
              dateFilter[Op.gte] = new Date(startDate);
            }
            if (endDate) {
              dateFilter[Op.lte] = new Date(endDate);
            }

            const whereConditions: any = {
              [Op.or]: [
                { callerId: authenticatedUserId },
                { calleeId: authenticatedUserId },
              ],
            };

            if (Object.keys(dateFilter).length > 0) {
              whereConditions.startedAt = dateFilter;
            }

            // Get all calls
            const allCalls = await CallLog.findAll({
              where: whereConditions,
              attributes: [
                "callType",
                "status",
                "duration",
                "callerId",
                "calleeId",
              ],
            });

            // Calculate statistics
            const stats = {
              totalCalls: allCalls.length,
              voiceCalls: allCalls.filter((c: any) => c.callType === "voice")
                .length,
              videoCalls: allCalls.filter((c: any) => c.callType === "video")
                .length,
              incomingCalls: allCalls.filter(
                (c: any) => c.calleeId === authenticatedUserId,
              ).length,
              outgoingCalls: allCalls.filter(
                (c: any) => c.callerId === authenticatedUserId,
              ).length,
              missedCalls: allCalls.filter((c: any) => c.status === "missed")
                .length,
              answeredCalls: allCalls.filter(
                (c: any) => c.status === "accepted" || c.status === "ended",
              ).length,
              rejectedCalls: allCalls.filter((c: any) => c.status === "rejected")
                .length,
              totalDuration: allCalls.reduce(
                (sum: number, c: any) => sum + (c.duration || 0),
                0,
              ),
              averageDuration:
                allCalls.filter((c: any) => c.duration).length > 0
                  ? Math.round(
                    allCalls.reduce(
                      (sum: number, c: any) => sum + (c.duration || 0),
                      0,
                    ) / allCalls.filter((c: any) => c.duration).length,
                  )
                  : 0,
            };

            socket.emit("call-statistics-response", {
              success: true,
              data: stats,
            });

            console.log(
              `📞 Call statistics sent to ${authenticatedUserId}:`,
              stats,
            );
          } catch (error) {
            console.error("Error fetching call statistics:", error);
            socket.emit("call-statistics-error", {
              message: "Failed to fetch call statistics",
            });
          }
        },
      );

      // Handle disconnect
      socket.on("disconnect", async (reason) => {
        console.log("🔌 Socket disconnected:", {
          socketId: socket.id,
          userId: authenticatedUserId || "unauthenticated",
          reason,
          connectedBefore: authenticatedUserId
            ? this.connectedUsers.has(authenticatedUserId)
            : false,
          timestamp: new Date().toISOString(),
        });

        if (authenticatedUserId) {
          console.log("👤 User disconnected:", authenticatedUserId);

          // Clean up any active call for this user
          const activeCallId = this.activeCallUsers.get(authenticatedUserId);
          if (activeCallId) {
            // Cancel the timeout
            const callTimeout = this.callTimeouts.get(activeCallId);
            if (callTimeout) {
              clearTimeout(callTimeout);
              this.callTimeouts.delete(activeCallId);
            }

            // Update call log - user disconnected during call
            try {
              const callLog = await CallLog.findOne({ where: { callId: activeCallId } });
              if (callLog) {
                const endedAt = new Date();
                let duration = null;

                // Only calculate duration if call was answered
                if (callLog.answeredAt) {
                  duration = Math.floor(
                    (endedAt.getTime() - new Date(callLog.answeredAt).getTime()) / 1000
                  );
                }

                await CallLog.update(
                  {
                    status: "ended",
                    endedAt,
                    duration,
                    endedBy: authenticatedUserId,
                  },
                  { where: { callId: activeCallId } }
                );

                console.log(
                  `💾 Call ${activeCallId} ended (disconnect) - Duration: ${duration ? `${duration}s` : "N/A"}`,
                );
              }
            } catch (dbError) {
              console.error("Failed to update call log on disconnect:", dbError);
            }

            // Find the other user in this call and notify them
            for (const [userId, callId] of this.activeCallUsers.entries()) {
              if (callId === activeCallId && userId !== authenticatedUserId) {
                const otherSocketId = this.connectedUsers.get(userId);
                if (otherSocketId) {
                  this.io.to(otherSocketId).emit("call-ended", { callId: activeCallId });
                }
                this.activeCallUsers.delete(userId);
                break;
              }
            }
            this.activeCallUsers.delete(authenticatedUserId);
            console.log(`  └─ Cleaned up active call: ${activeCallId}`);
          }

          // Remove from connected users
          this.connectedUsers.delete(authenticatedUserId);

          // Remove from active chats (but keep lastChatPartner for reconnection)
          const wasInChatWith = this.activeChats.get(authenticatedUserId);
          if (wasInChatWith) {
            this.activeChats.delete(authenticatedUserId);
            console.log(`  └─ Was in chat with: ${wasInChatWith}`);
          }

          // Clear presence tracking
          this.userPresence.delete(authenticatedUserId);

          // Broadcast user offline status to their contacts
          // This is valid because socket disconnect = definitely offline
          this.broadcastUserStatus(authenticatedUserId, "offline");
          console.log(
            `  └─ Broadcasted offline status for: ${authenticatedUserId}`,
          );
          console.log(`  └─ Last chat partner preserved for reconnection`);
        } else {
        }
      });
    });
  }

  /**
   * Send chat-picture-like notification via WebSocket (if online) or FCM (if offline)
   * Called from chat-picture-like controller after a like is created
   *
   * @param likeData - { likeId, fromUserId, toUserId, target_chat_picture_id }
   * @returns { sentViaWebSocket: boolean, sentViaFCM: boolean }
   */
  public async sendChatPictureLikeNotification(likeData: {
    likeId: string;
    fromUserId: string;
    toUserId: string;
    target_chat_picture_id: string;
  }): Promise<{ sentViaWebSocket: boolean; sentViaFCM: boolean }> {
    try {
      const { likeId, fromUserId, toUserId, target_chat_picture_id } = likeData;

      // Don't send notification if user liked their own profile
      if (fromUserId === toUserId) {
        console.log(
          `ℹ️ User ${fromUserId} liked their own profile, skipping notification`,
        );
        return { sentViaWebSocket: false, sentViaFCM: false };
      }

      // Get liker's details
      const likerUser = await getById(fromUserId);
      if (!likerUser) {
        console.error(`❌ Liker user not found: ${fromUserId}`);
        return { sentViaWebSocket: false, sentViaFCM: false };
      }

      const likerName =
        `${likerUser.firstName || ""} ${likerUser.lastName || ""}`.trim() ||
        "Someone";

      // Check if receiver is online (has active socket AND explicit online presence)
      const receiverSocketId = this.connectedUsers.get(toUserId);
      const receiverPresence = this.userPresence.get(toUserId);
      const isReceiverOnline =
        receiverSocketId && receiverPresence?.isOnline === true;

      const notificationPayload = {
        type: "chat_picture_like",
        likeId,
        fromUserId,
        fromUserName: likerName,
        from_user_chat_picture: likerUser.chat_picture || "",
        toUserId,
        target_chat_picture_id,
        message: `${likerName} liked your picture`,
        timestamp: new Date().toISOString(),
      };

      let sentViaWebSocket = false;
      let sentViaFCM = false;

      if (isReceiverOnline && receiverSocketId) {
        // User is online - send via WebSocket
        this.io.to(receiverSocketId).emit("notification", notificationPayload);
        sentViaWebSocket = true;
        console.log(
          `📡 Sent chat-picture-like notification via WebSocket to ${toUserId} (socket: ${receiverSocketId})`,
        );
      } else {
        // User is offline or not explicitly online - send via multi-device FCM
        try {
          const result = await sendChatPictureLikeToUser({
            receiverId: toUserId,
            likeId,
            fromUserId,
            fromUserName: likerName,
            fromUserChatPicture: likerUser.chat_picture || "",
            targetChatPictureId: target_chat_picture_id,
          });

          if (result.success) {
            sentViaFCM = true;
            console.log(
              `✅ FCM sent for chat-picture-like to user ${toUserId}:`,
              {
                tokenCount: result.tokenCount,
                successCount: result.successCount,
                failureCount: result.failureCount,
                invalidTokenCount: result.invalidTokenCount,
              },
            );
          } else {
            console.warn(
              `⚠️ Failed to send chat-picture-like FCM to user ${toUserId}`,
            );
          }
        } catch (fcmError) {
          console.error(
            "❌ Error sending FCM notification for chat-picture-like:",
            {
              toUserId,
              likeId,
              error: fcmError,
            },
          );
        }
      }

      return { sentViaWebSocket, sentViaFCM };
    } catch (error) {
      console.error("❌ Error in sendChatPictureLikeNotification:", error);
      return { sentViaWebSocket: false, sentViaFCM: false };
    }
  }

  public async emitProfileUpdate(userId: string, updatedFields: any) {
    try {
      const entries = this.connectedUsers.entries();

      const contacts = await Contact.findAll({
        where: { userId },
        attributes: ["contactUserId"],
        raw: true,
      });

      let userIds: string[] = []; // user ids of sent through websocket
      const contactUserIds = new Set(contacts.map((c) => c.contactUserId));
      // Notify only contacts who are connected
      for (const [contactUserId, socketId] of entries) {
        if (contactUserId && socketId && contactUserIds.has(contactUserId)) {
          console.log("Emitting profile update to contact:", contactUserId);
          this.io.to(socketId).emit("profile-updated", {
            userId,
            updatedFields,
          });
          userIds.push(contactUserId);
        }
      }
      // return the userId that i need to send through fcm
      return Array.from(contactUserIds).filter((id) => !userIds.includes(id));
    } catch (error) {
      console.error("Error updating profile:", error);
      return [];
    }
  }

  // REST API endpoints
  async getChatHistory(req: Request, res: Response) {
    try {
      const { userId, otherUserId } = req.params;

      // Import MessageReaction model
      const MessageReaction =
        require("../db/models/message-reaction.model").default;

      const chats = await Chat.findAll({
        where: {
          [Op.and]: [
            {
              [Op.or]: [
                { senderId: userId, receiverId: otherUserId },
                { senderId: otherUserId, receiverId: userId },
              ],
            },
            {
              [Op.or]: [
                // Messages sent by userId should not be deleted for sender
                {
                  senderId: userId,
                  deletedForSender: { [Op.or]: [false, null] },
                },
                // Messages received by userId should not be deleted for receiver
                {
                  receiverId: userId,
                  deletedForReceiver: { [Op.or]: [false, null] },
                },
              ],
            },
          ],
        },
        order: [["createdAt", "ASC"]],
        attributes: [
          "id",
          "senderId",
          "receiverId",
          "message",
          "messageType",
          "fileUrl",
          "mimeType",
          "messageStatus",
          "isRead",
          "deliveredAt",
          "readAt",
          "createdAt",
          "updatedAt",
        ],
        include: [
          { model: User, as: "sender", attributes: ["id", "username"] },
          { model: User, as: "receiver", attributes: ["id", "username"] },
          {
            model: MessageReaction,
            as: "reactions",
            attributes: ["id", "userId", "emoji", "createdAt"],
            include: [
              {
                model: User,
                as: "user",
                attributes: ["id", "firstName", "lastName", "chat_picture"],
              },
            ],
            required: false,
          },
        ],
      });

      res.json(chats);
    } catch (error) {
      console.error("Error fetching chat history:", error);
      res.status(500).json({ error: "Failed to fetch chat history" });
    }
  }

  /**
   * Send status-like notification via WebSocket (if online) or FCM (if offline)
   * Called from status controller after a status is liked
   *
   * @param likeData - { likeId, fromUserId, toUserId, statusId, statusText }
   * @returns { sentViaWebSocket: boolean, sentViaFCM: boolean }
   */
  public async sendStatusLikeNotification(likeData: {
    likeId: string;
    fromUserId: string;
    toUserId: string;
    statusId: string;
    statusText: string;
  }): Promise<{ sentViaWebSocket: boolean; sentViaFCM: boolean }> {
    try {
      const { likeId, fromUserId, toUserId, statusId, statusText } = likeData;

      // Don't send notification if user liked their own status (but allow the like)
      if (fromUserId === toUserId) {
        console.log(
          `ℹ️ User ${fromUserId} liked their own status, skipping notification`,
        );
        return { sentViaWebSocket: false, sentViaFCM: false };
      }

      // Get liker's details
      const likerUser = await getById(fromUserId);
      if (!likerUser) {
        console.error(`❌ Liker user not found: ${fromUserId}`);
        return { sentViaWebSocket: false, sentViaFCM: false };
      }

      const likerName =
        `${likerUser.firstName || ""} ${likerUser.lastName || ""}`.trim() ||
        "Someone";

      // Truncate status text for notification (show first 20 chars)
      const truncatedStatus =
        statusText.length > 20
          ? statusText.substring(0, 20) + "....."
          : statusText;

      // Check if receiver is online (has active socket AND explicit online presence)
      const receiverSocketId = this.connectedUsers.get(toUserId);
      const receiverPresence = this.userPresence.get(toUserId);
      const isReceiverOnline =
        receiverSocketId && receiverPresence?.isOnline === true;

      const notificationPayload = {
        type: "status_like",
        likeId,
        fromUserId,
        fromUserName: likerName,
        fromUserProfilePic: likerUser.chat_picture || "",
        toUserId,
        statusId,
        message: `❤ new Like on your SYVT ${truncatedStatus}`,
        timestamp: new Date().toISOString(),
      };

      let sentViaWebSocket = false;
      let sentViaFCM = false;

      if (isReceiverOnline && receiverSocketId) {
        // User is online - send via WebSocket
        this.io.to(receiverSocketId).emit("notification", notificationPayload);
        sentViaWebSocket = true;
        console.log(
          `📡 Sent status-like notification via WebSocket to ${toUserId} (socket: ${receiverSocketId})`,
        );
      } else {
        // User is offline or not explicitly online - send via multi-device FCM
        try {
          const result = await sendStatusLikeToUser({
            receiverId: toUserId,
            likeId,
            fromUserId,
            fromUserName: likerName,
            fromUserProfilePic: likerUser.chat_picture || "",
            statusId,
            statusText,
          });

          if (result.success) {
            sentViaFCM = true;
            console.log(
              `✅ FCM sent for status-like to user ${toUserId}:`,
              {
                tokenCount: result.tokenCount,
                successCount: result.successCount,
                failureCount: result.failureCount,
                invalidTokenCount: result.invalidTokenCount,
              },
            );
          } else {
            console.warn(
              `⚠️ Failed to send status-like FCM to user ${toUserId}`,
            );
          }
        } catch (fcmError) {
          console.error("❌ Error sending FCM notification for status-like:", {
            toUserId,
            likeId,
            statusId,
            error: fcmError,
          });
        }
      }

      return { sentViaWebSocket, sentViaFCM };
    } catch (error) {
      console.error("❌ Error in sendStatusLikeNotification:", error);
      return { sentViaWebSocket: false, sentViaFCM: false };
    }
  }

  /**
   * Notify contacts when a new story is created
   * Sends real-time notification to all online contacts
   */
  public async notifyContactsAboutNewStory(
    userId: string,
    storyData: {
      storyId: string;
      mediaUrl: string;
      mediaType: string;
      thumbnailUrl?: string | null;
      videoDuration?: number | null;
      createdAt: Date;
    }
  ) {
    try {
      const contacts = await Contact.findAll({
        where: { userId },
        attributes: ['contactUserId'],
        raw: true,
      });

      const contactUserIds = contacts.map((c: any) => c.contactUserId);

      // Filter out users who have been blocked by the story owner
      const blockedUsers = await BlockedUser.findAll({
        where: {
          blockerId: userId, // Story owner has blocked these users
        },
        attributes: ['blockedId'],
        raw: true,
      });

      const blockedUserIds = blockedUsers.map((b: any) => b.blockedId);
      const visibleContactUserIds = contactUserIds.filter(
        (contactId) => !blockedUserIds.includes(contactId)
      );

      if (visibleContactUserIds.length === 0) {
        console.log(`📭 No visible contacts to notify about story from user ${userId}`);
        return;
      }

      const user = await getById(userId);
      if (!user) return;

      const notificationPayload: any = {
        type: 'new_story',
        storyId: storyData.storyId,
        userId,
        userName: `${user.firstName || ''} ${user.lastName || ''}`.trim(),
        userProfilePic: user.chat_picture || '',
        mediaUrl: storyData.mediaUrl,
        mediaType: storyData.mediaType,
        createdAt: storyData.createdAt,
        timestamp: new Date().toISOString(),
      };

      // Include video-specific fields if present
      if (storyData.thumbnailUrl) notificationPayload.thumbnailUrl = storyData.thumbnailUrl;
      if (storyData.videoDuration) notificationPayload.videoDuration = storyData.videoDuration;

      const offlineContactUserIds: string[] = [];
      for (const contactUserId of visibleContactUserIds) {
        const socketId = this.connectedUsers.get(contactUserId);
        if (socketId) {
          this.io.to(socketId).emit('story-created', notificationPayload);
          console.log(`📡 Sent new story notification to contact ${contactUserId}`);
        } else {
          offlineContactUserIds.push(contactUserId);
        }
      }

      if (offlineContactUserIds.length > 0) {
        await Promise.all(
          offlineContactUserIds.map(async (contactUserId) => {
            try {
              await sendStoriesChangedToUser({
                receiverId: contactUserId,
                actorUserId: userId,
                action: 'created',
                storyId: storyData.storyId,
                storyData: {
                  mediaUrl: storyData.mediaUrl,
                  mediaType: storyData.mediaType as 'image' | 'video',
                  thumbnailUrl: storyData.thumbnailUrl || undefined,
                  videoDuration: storyData.videoDuration || undefined,
                  createdAt: storyData.createdAt.toISOString(),
                  userName: `${user.firstName || ''} ${user.lastName || ''}`.trim(),
                  userProfilePic: user.chat_picture || '',
                },
              });
            } catch (error) {
              console.error('❌ Error sending stories_changed FCM (created):', {
                contactUserId,
                storyId: storyData.storyId,
                error,
              });
            }
          }),
        );
      }
    } catch (error) {
      console.error('❌ Error notifying contacts about new story:', error);
    }
  }

  /**
   * Notify story owner when someone views their story
   */
  public async notifyStoryOwnerAboutView(storyId: string, viewerId: string) {
    try {
      const Story = require('../db/models/story.model').default;
      const story = await Story.findByPk(storyId);

      if (!story) return;

      const viewer = await getById(viewerId);
      if (!viewer) return;

      const ownerSocketId = this.connectedUsers.get(story.userId);

      if (ownerSocketId) {
        this.io.to(ownerSocketId).emit('story-viewed', {
          type: 'story_view',
          storyId,
          viewerId,
          viewerName: `${viewer.firstName || ''} ${viewer.lastName || ''}`.trim(),
          viewerProfilePic: viewer.chat_picture || '',
          timestamp: new Date().toISOString(),
        });
        console.log(`📡 Sent story view notification to owner ${story.userId}`);
      } else {
        try {
          await sendStoriesChangedToUser({
            receiverId: story.userId,
            actorUserId: viewerId,
            action: 'viewed',
            storyId,
          });
        } catch (error) {
          console.error('❌ Error sending stories_changed FCM (viewed):', {
            ownerId: story.userId,
            storyId,
            viewerId,
            error,
          });
        }
      }
    } catch (error) {
      console.error('❌ Error notifying story owner about view:', error);
    }
  }

  /**
   * Notify contacts when a story is deleted
   */
  public async notifyContactsAboutDeletedStory(userId: string, storyId: string) {
    try {
      const contacts = await Contact.findAll({
        where: { userId },
        attributes: ['contactUserId'],
        raw: true,
      });

      const contactUserIds = contacts.map((c: any) => c.contactUserId);

      // Filter out users who have been blocked by the story owner
      const blockedUsers = await BlockedUser.findAll({
        where: {
          blockerId: userId, // Story owner has blocked these users
        },
        attributes: ['blockedId'],
        raw: true,
      });

      const blockedUserIds = blockedUsers.map((b: any) => b.blockedId);
      const visibleContactUserIds = contactUserIds.filter(
        (contactId) => !blockedUserIds.includes(contactId)
      );

      if (visibleContactUserIds.length === 0) {
        return;
      }

      const offlineContactUserIds: string[] = [];
      for (const contactUserId of visibleContactUserIds) {
        const socketId = this.connectedUsers.get(contactUserId);
        if (socketId) {
          this.io.to(socketId).emit('story-deleted', {
            type: 'story_deleted',
            storyId,
            userId,
            timestamp: new Date().toISOString(),
          });
          console.log(`📡 Sent story deleted notification to contact ${contactUserId}`);
        } else {
          offlineContactUserIds.push(contactUserId);
        }
      }

      if (offlineContactUserIds.length > 0) {
        await Promise.all(
          offlineContactUserIds.map(async (contactUserId) => {
            try {
              await sendStoriesChangedToUser({
                receiverId: contactUserId,
                actorUserId: userId,
                action: 'deleted',
                storyId,
              });
            } catch (error) {
              console.error('❌ Error sending stories_changed FCM (deleted):', {
                contactUserId,
                storyId,
                error,
              });
            }
          }),
        );
      }
    } catch (error) {
      console.error('❌ Error notifying contacts about deleted story:', error);
    }
  }
}

//==================API's===================

//Upload image or pdf for one - to - one chatting
export const uploadFileController = async (req: Request, res: Response) => {
  try {
    // Handle both single file upload and multiple files (file + thumbnail)
    const files = req.files as { [fieldname: string]: Express.Multer.File[] };
    const file = req.file || (files?.file?.[0]);
    const thumbnailFile = files?.thumbnail?.[0];

    if (!file) {
      return res.status(400).json({ error: "File is required" });
    }

    const fileInfo = file as unknown as {
      key: string;
      mimetype: string;
      location?: string;
    };

    let messageType: "image" | "pdf" | "video" | "audio";

    // Extract image dimensions from request body (sent by frontend after getting dimensions)
    const { imageWidth, imageHeight, audioDuration } = req.body;
    if (fileInfo.mimetype.startsWith("image/")) messageType = "image";
    else if (fileInfo.mimetype.startsWith("video/")) messageType = "video";
    else if (fileInfo.mimetype.startsWith("audio/")) messageType = "audio";
    else messageType = "pdf";

    const response: any = {
      messageType,
      fileUrl: fileInfo.key,
      mimeType: fileInfo.mimetype,
    };

    // Include dimensions for images (for WhatsApp-style dynamic aspect ratio)
    if (messageType === "image" && imageWidth && imageHeight) {
      response.imageWidth = parseInt(imageWidth);
      response.imageHeight = parseInt(imageHeight);
    }

    // Include duration for audio messages (voice notes)
    if (messageType === "audio" && audioDuration) {
      response.audioDuration = parseFloat(audioDuration);
    }

    // Include thumbnail URL for videos if provided
    if (messageType === "video" && thumbnailFile) {
      const thumbInfo = thumbnailFile as unknown as { key: string };
      response.thumbnailUrl = thumbInfo.key;
      console.log('✓ Video thumbnail uploaded for chat');
    }

    return res.json(response);
  } catch (err) {
    console.error("Upload error:", err);
    return res.status(500).json({ error: "Failed to upload file" });
  }
};

export const getFileController = async (req: Request, res: Response) => {
  try {
    const { key } = req.params;

    if (!key) {
      return res.status(400).json({
        success: false,
        message: "Invalid file key",
      });
    }

    if (!validateS3Key(key)) {
      return res.status(400).json({
        success: false,
        message: "Invalid file key",
      });
    }

    // Fetch file from S3
    const s3Response = await getS3ObjectStreamWithMetaData(key);

    if (!s3Response || !s3Response.Body) {
      return res.status(404).json({
        success: false,
        message: "File not found",
      });
    }

    const body: any = s3Response.Body;

    // ✅ Set headers for mobile clients
    res.setHeader(
      "Content-Type",
      s3Response.ContentType || "application/octet-stream",
    );

    res.setHeader("Content-Length", s3Response.ContentLength?.toString() || "");

    // Optional but recommended
    res.setHeader("Cache-Control", "private, max-age=31536000");

    // Stream file
    if (body.pipe && typeof body.pipe === "function") {
      body.pipe(res);
    } else {
      for await (const chunk of body) {
        res.write(chunk);
      }
      res.end();
    }
  } catch (error: any) {
    if (!res.headersSent) {
      res.status(500).json({
        success: false,
        message: error.message,
      });
    }
  }
};

export default ChatController;
