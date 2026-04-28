import admin from "firebase-admin";
import FcmDeviceToken from "../db/models/fcm-device-token.model";

// Initialize Firebase Admin SDK (serviceAccountKey.json should be in project root)
// Temporarily disabled — service account JSON file not present on this machine
// admin.initializeApp({
//   credential: admin.credential.cert(require("../../chatawayplus-firebase-adminsdk-fbsvc-0742cc9ed4.json"))
// });
// admin.initializeApp({
//   credential: admin.credential.cert({
//     projectId: process.env.FIREBASE_PROJECT_ID,
//     privateKeyId: process.env.FIREBASE_PRIVATE_KEY_ID,
//     privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"), // IMPORTANT!
//     clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
//     clientId: process.env.FIREBASE_CLIENT_ID,
//     authUri: process.env.FIREBASE_AUTH_URI,
//     tokenUri: process.env.FIREBASE_TOKEN_URI,
//     authProviderX509CertUrl: process.env.FIREBASE_AUTH_PROVIDER_CERT_URL,
//     clientC509CertUrl: process.env.FIREBASE_CLIENT_CERT_URL
//   })
// });

export interface FcmCheckResult {
  valid: boolean;
  error?: string;
}

/**
 * Check if an FCM token is valid by sending a silent ping.
 */
export async function checkFcmToken(token: string): Promise<FcmCheckResult> {
  try {
    const message: admin.messaging.Message = {
      token,
      data: { ping: "1" },
      android: {
        priority: "high", // ✅ correct union type
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            "content-available": 1, // ✅ Must be a number and key must be hyphenated in APNs
          },
        },
      },
    };

    await admin.messaging().send(message);
    return { valid: true };
  } catch (err: any) {
    const reason = err.code || "unknown";

    if (reason === "messaging/registration-token-not-registered") {
      return { valid: false, error: "TokenExpired" };
    }
    if (reason === "messaging/invalid-argument") {
      return { valid: false, error: "InvalidToken" };
    }

    return { valid: false, error: reason };
  }
}

/**
 * Send data-only FCM message (chat message, chat picture like, etc.)
 * - Android/iOS client code is fully responsible for building the notification.
 * - This allows native code to use phonebook contact names for the title.
 */
export async function sendDataMessage(token: string, data: Record<string, string>) {
  try {
    let messageData: Record<string, string>;

    // Handle different message types
    if (data.type === 'chat_picture_like') {
      // Chat picture like notification
      messageData = {
        type: 'chat_picture_like',
        likeId: data.likeId || '',
        fromUserId: data.fromUserId || '',
        fromUserName: data.fromUserName || '',
        from_user_chat_picture: data.from_user_chat_picture || '',
        toUserId: data.toUserId || '',
        target_chat_picture_id: data.target_chat_picture_id || '',
        body: data.body || 'Someone liked your picture',
        title: data.title || 'New like',
      };
    } else {
      // Default: chat message
      messageData = {
        type: data.type || 'chat_message',
        senderId: data.senderId || '',
        chatId: data.chatId || '',
        senderFirstName: data.senderFirstName || '',
        sender_chat_picture: data.sender_chat_picture || '',
        sender_mobile_number: data.sender_mobile_number || '',
        messageText: data.body || '',
        chatType: 'private_message'
      };
    }

    const message: admin.messaging.Message = {
      token,
      data: messageData,
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            "content-available": 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log(`✅ FCM message sent to ${token.substring(0, 20)}...:`, response);
    return { success: true, response };
  } catch (err: any) {
    const errorCode = err?.errorInfo?.code || err?.code;

    // Handle invalid/expired tokens gracefully
    if (errorCode === 'messaging/registration-token-not-registered' ||
      errorCode === 'messaging/invalid-registration-token') {
      console.warn(`⚠️ Invalid/expired FCM token detected: ${token.substring(0, 20)}...`);
      return { success: false, reason: 'invalid_token', shouldRemoveToken: true };
    }

    console.error(`❌ Failed to send FCM message to ${token.substring(0, 20)}...:`, errorCode || 'unknown_error');
    return { success: false, reason: errorCode || "send_failed" };
  }
}

export async function sendProfileUpdateNotification(
  token: string,
  data: Record<string, string>
) {
  try {
    const notification: admin.messaging.Message = {
      token,

      data: {
        type: 'profile_update',
        userId: data.userId,
        updatedData: data.updatedData,
      },
      android: {
        priority: "high",
        ttl: 86400000, // 24 hours in milliseconds
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-expiration": String(Math.floor(Date.now() / 1000) + 86400), // 24 hours from now
        },
        payload: {
          aps: {
            "content-available": 1,
          },
        },
      },
    };
    await admin.messaging().send(notification);
    return { success: true };
  } catch (err: any) {
    // Handle invalid/expired FCM tokens gracefully
    if (err.code === 'messaging/registration-token-not-registered' ||
      err.code === 'messaging/invalid-registration-token') {
      console.warn('⚠️  Invalid or expired FCM token:', token);
      return { success: false, tokenExpired: true };
    }
    console.error('FCM send error:', err);
    return { success: false, error: err.message };
  }
}

/**
 * Send FCM message to all active devices for a user
 * - Sends to multiple tokens (multi-device support)
 * - Handles token cleanup for invalid tokens
 * - Logs send results for debugging
 * - Ensures no collapse keys (each message delivers independently)
 */
export interface MultiDeviceSendOptions {
  userId: string;
  messageUuid: string;
  messageType: 'chat_message' | 'profile_update' | 'chat_picture_like' | 'message_reaction' | 'stories_changed' | 'status_like' | 'incoming_call';
  data: Record<string, string>;
  conversationId?: string;
  notification?: {
    title: string;
    body: string;
    imageUrl?: string;
  };
}

export interface MultiDeviceSendResult {
  success: boolean;
  tokenCount: number;
  successCount: number;
  failureCount: number;
  invalidTokenCount: number;
}

export async function sendToAllUserDevices(
  options: MultiDeviceSendOptions
): Promise<MultiDeviceSendResult> {
  const { userId, messageUuid, messageType, data, conversationId } = options;

  // Get all active tokens for user
  const deviceTokens = await FcmDeviceToken.findAll({
    where: {
      userId,
      isActive: true
    },
    raw: true
  });

  const tokenCount = deviceTokens.length;
  let successCount = 0;
  let failureCount = 0;
  let invalidTokenCount = 0;
  const failureReasons: string[] = [];

  if (tokenCount === 0) {
    console.warn(`⚠️ No active FCM tokens for user ${userId}`);

    return {
      success: false,
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
      invalidTokenCount: 0
    };
  }

  // Enhance data with required fields
  const enhancedData: Record<string, string> = {
    ...data,
    type: messageType,
    messageUuid,
    timestampMs: String(Date.now())
  };

  // Add conversationId if provided (for grouping messages)
  if (conversationId) {
    enhancedData.conversationId = conversationId;
  }

  // Send to all tokens in parallel
  const sendPromises = deviceTokens.map(async (deviceToken) => {
    try {
      const message: admin.messaging.Message = {
        token: deviceToken.fcmToken,
        data: enhancedData,
        android: {
          priority: "high",
          ttl: 86400000, // 24 hours
          // NO collapseKey - each message must deliver independently
        },
        apns: {
          headers: {
            "apns-priority": "10",
            "apns-expiration": String(Math.floor(Date.now() / 1000) + 86400),
            // NO apns-collapse-id
          },
          payload: {
            aps: {
              "content-available": 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      console.log(`✅ FCM sent to device ${deviceToken.deviceId} (${deviceToken.platform}):`, response);
      successCount++;
      return { success: true, deviceToken };
    } catch (err: any) {
      const errorCode = err?.errorInfo?.code || err?.code;

      // Handle invalid/expired tokens
      if (
        errorCode === 'messaging/registration-token-not-registered' ||
        errorCode === 'messaging/invalid-registration-token'
      ) {
        console.warn(
          `⚠️ Invalid token for device ${deviceToken.deviceId}, marking as inactive`
        );

        // Mark token as inactive
        await FcmDeviceToken.update(
          { isActive: false },
          { where: { id: deviceToken.id } }
        );

        invalidTokenCount++;
        failureReasons.push(`${deviceToken.deviceId}: ${errorCode}`);
        return { success: false, deviceToken, reason: 'invalid_token' };
      }

      console.error(`❌ Failed to send to device ${deviceToken.deviceId}:`, errorCode);
      failureCount++;
      failureReasons.push(`${deviceToken.deviceId}: ${errorCode || 'unknown'}`);
      return { success: false, deviceToken, reason: errorCode || 'send_failed' };
    }
  });

  await Promise.all(sendPromises);

  console.log(`📊 FCM Multi-device send to user ${userId}:`, {
    messageUuid,
    messageType,
    tokenCount,
    successCount,
    failureCount,
    invalidTokenCount,
    failureReasons: failureReasons.length > 0 ? failureReasons : undefined
  });

  return {
    success: successCount > 0,
    tokenCount,
    successCount,
    failureCount,
    invalidTokenCount
  };
}

/**
 * Helper function for sending chat messages to all user devices
 */
export async function sendChatMessageToUser(params: {
  receiverId: string;
  chatId: string;
  senderId: string;
  senderFirstName: string;
  senderChatPicture?: string;
  senderMobileNumber?: string;
  messageText: string;
  conversationId: string;
}): Promise<MultiDeviceSendResult> {
  return sendToAllUserDevices({
    userId: params.receiverId,
    messageUuid: params.chatId,
    messageType: 'chat_message',
    conversationId: params.conversationId,
    data: {
      chatId: params.chatId,
      senderId: params.senderId,
      senderFirstName: params.senderFirstName || '',
      sender_chat_picture: params.senderChatPicture || '',
      sender_mobile_number: params.senderMobileNumber || '',
      messageText: params.messageText || '',
      chatType: 'private_message'
    }
  });
}

/**
 * Helper function for sending profile update notifications
 */
export async function sendProfileUpdateToUser(params: {
  receiverId: string;
  updatingUserId: string;
  updatedData: any;
}): Promise<MultiDeviceSendResult> {
  return sendToAllUserDevices({
    userId: params.receiverId,
    messageUuid: `profile-update-${Date.now()}`,
    messageType: 'profile_update',
    data: {
      userId: params.updatingUserId,
      updatedData: JSON.stringify(params.updatedData)
    }
  });
}

export async function sendStoriesChangedToUser(params: {
  receiverId: string;
  actorUserId: string;
  action: 'created' | 'deleted' | 'viewed' | 'expired';
  storyId?: string;
  // Optional story data for offline caching (especially for 'created' action)
  storyData?: {
    mediaUrl?: string;
    mediaType?: 'image' | 'video';
    thumbnailUrl?: string;
    videoDuration?: number;
    createdAt?: string;
    userName?: string;
    userProfilePic?: string;
    caption?: string;
    duration?: number;
    expiresAt?: string;
  };
}): Promise<MultiDeviceSendResult> {
  // Build base data
  const data: any = {
    actorUserId: params.actorUserId,
    action: params.action,
    storyId: params.storyId || ''
  };

  // For 'created' action, include full story data for offline display
  if (params.action === 'created' && params.storyData) {
    data.mediaUrl = params.storyData.mediaUrl || '';
    data.mediaType = params.storyData.mediaType || 'image';
    data.createdAt = params.storyData.createdAt || new Date().toISOString();
    data.userId = params.actorUserId; // Story owner
    data.userName = params.storyData.userName || '';
    data.userProfilePic = params.storyData.userProfilePic || '';
    if (params.storyData.caption) data.caption = params.storyData.caption;
    if (params.storyData.duration) data.duration = params.storyData.duration;
    if (params.storyData.expiresAt) data.expiresAt = params.storyData.expiresAt;
    if (params.storyData.thumbnailUrl) data.thumbnailUrl = params.storyData.thumbnailUrl;
    if (params.storyData.videoDuration) data.videoDuration = String(params.storyData.videoDuration);
  }

  return sendToAllUserDevices({
    userId: params.receiverId,
    messageUuid: `stories-changed-${params.action}-${Date.now()}`,
    messageType: 'stories_changed',
    data
  });
}

/**
 * Helper function for sending message reaction notifications
 */
export async function sendReactionNotificationToUser(params: {
  receiverId: string;
  reactorId: string;
  reactorName: string;
  emoji: string;
  messageText: string;
  messageId: string;
  isYou: boolean;
}): Promise<MultiDeviceSendResult> {
  // Format: "You: hit emoji 😀 to 'Hello'" or "John: hit emoji 😀 to 'Hello'"
  const actorName = params.isYou ? 'You' : params.reactorName;
  const truncatedMessage = params.messageText.length > 50
    ? params.messageText.substring(0, 50) + '...'
    : params.messageText;

  return sendToAllUserDevices({
    userId: params.receiverId,
    messageUuid: `reaction-${params.messageId}-${Date.now()}`,
    messageType: 'message_reaction',
    data: {
      type: 'message_reaction',
      messageId: params.messageId,
      reactorId: params.reactorId,
      reactorName: params.reactorName,
      emoji: params.emoji,
      messageText: params.messageText,
      body: `${actorName}: hit emoji ${params.emoji} to "${truncatedMessage}"`,
      title: 'New Reaction'
    }
  });
}

/**
 * Helper function for sending incoming call push notification to all user devices
 * High priority data-only message to wake the device and show incoming call UI
 */
export async function sendIncomingCallToUser(params: {
  receiverId: string;
  callId: string;
  callerId: string;
  callerName: string;
  callerProfilePic?: string;
  callType: 'voice' | 'video';
  channelName: string;
}): Promise<MultiDeviceSendResult> {
  return sendToAllUserDevices({
    userId: params.receiverId,
    messageUuid: `incoming-call-${params.callId}`,
    messageType: 'incoming_call',
    notification: {
      title: `Incoming ${params.callType} call`,
      body: `${params.callerName} is calling...`,
      imageUrl: params.callerProfilePic || undefined,
    },
    data: {
      type: 'incoming_call',
      callId: params.callId,
      callerId: params.callerId,
      callerName: params.callerName,
      callerProfilePic: params.callerProfilePic || '',
      callType: params.callType,
      channelName: params.channelName,
    }
  });
}

/**
 * Helper function for sending chat picture like notifications to all user devices
 */
export async function sendChatPictureLikeToUser(params: {
  receiverId: string;
  likeId: string;
  fromUserId: string;
  fromUserName: string;
  fromUserChatPicture?: string;
  targetChatPictureId: string;
}): Promise<MultiDeviceSendResult> {
  return sendToAllUserDevices({
    userId: params.receiverId,
    messageUuid: `chat-picture-like-${params.likeId}`,
    messageType: 'chat_picture_like',
    data: {
      type: 'chat_picture_like',
      likeId: params.likeId,
      fromUserId: params.fromUserId,
      fromUserName: params.fromUserName,
      from_user_chat_picture: params.fromUserChatPicture || '',
      toUserId: params.receiverId,
      target_chat_picture_id: params.targetChatPictureId,
      body: `${params.fromUserName} liked your picture`,
      title: 'New like'
    }
  });
}

/**
 * Helper function for sending status like notifications to all user devices
 */
export async function sendStatusLikeToUser(params: {
  receiverId: string;
  likeId: string;
  fromUserId: string;
  fromUserName: string;
  fromUserProfilePic?: string;
  statusId: string;
  statusText: string;
}): Promise<MultiDeviceSendResult> {
  // Truncate status text for notification (show first 20 chars)
  const truncatedStatus = params.statusText.length > 20
    ? params.statusText.substring(0, 20) + '.....'
    : params.statusText;

  return sendToAllUserDevices({
    userId: params.receiverId,
    messageUuid: `status-like-${params.likeId}`,
    messageType: 'chat_picture_like',  // Using existing message type
    data: {
      type: 'status_like',
      likeId: params.likeId,
      fromUserId: params.fromUserId,
      fromUserName: params.fromUserName,
      fromUserProfilePic: params.fromUserProfilePic || '',
      toUserId: params.receiverId,
      statusId: params.statusId,
      body: `❤ new Like on your SYVT ${truncatedStatus}`,
      title: 'New like on status'
    }
  });
}
