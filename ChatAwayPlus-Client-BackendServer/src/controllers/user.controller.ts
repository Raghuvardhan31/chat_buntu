import { Request, Response } from "express";
import {
  checkRegisteredContacts,
  createUser as create,
  getAllUsers as getAll,
  getById,
  updateProfile as update,
  deleteProfilePic,
  getUserDetailsByIds,
  storeContacts,
  getContactUserIdsForUser,
  getContactsUpdatedSince,
} from '../services/user.service';
import * as statusService from '../services/status.service';
import * as emojiUpdateService from '../services/emoji-update.service';
import FcmDeviceToken from '../db/models/fcm-device-token.model';

import { sendDataMessage, sendProfileUpdateToUser } from '../services/fcm.service';
import { chatController } from '../index';
import { formatMediaUrl } from '../utils/storage.util';

export const createUser = async (req: Request, res: Response) => {
  try {
    const user = await create(req.body);
    res.status(201).json({
      success: true,
      data: user,
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: (error as Error).message,
    });
  }
};

export const getAllUsers = async (req: Request, res: Response) => {
  try {
    const users = await getAll();
    res.status(200).json({
      success: true,
      data: users,
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: (error as Error).message,
    });
  }
};

export const getUserById = async (req: Request, res: Response) => {
  try {
    const user = await getById(req.params.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: "User not found!!12",
      });
    }
    res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: (error as Error).message,
    });
  }
};

export const updateProfile = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }

    const userId = req.user.id;
    const {
      name,
      share_your_voice,
      emojis_update,
      emojis_caption,
      chat_picture_caption,
    } = req.body;

    if (req.file) {
      console.log("File details:", {
        fieldname: req.file.fieldname,
        originalname: req.file.originalname,
        filename: (req.file as any).filename,
        size: req.file.size,
        mimetype: req.file.mimetype,
        location: (req.file as any).location, // S3 URL
      });
    }

    // Handle file upload
    let chat_picture;
    if (req.file) {
      chat_picture = formatMediaUrl(req.file);
      console.log("✅ Chat picture URL set to:", chat_picture);
    } else {
      console.log("⚠️ No file uploaded - chat_picture will remain unchanged");
    }

    // Update user profile
    const updatedUser = await update(userId, {
      name: name || undefined,
      chat_picture: chat_picture || undefined,
      chat_picture_caption: chat_picture_caption || undefined,
    });

    // Handle status - create new or fetch existing
    let newStatus = null;
    if (share_your_voice) {
      newStatus = await statusService.createStatus(share_your_voice, userId);
    } else {
      const userStatus = await statusService.getUserStatus(userId);
      newStatus = userStatus.length > 0 ? userStatus[0] : null;
    }

    // Handle emoji update - create new or fetch existing
    let latestEmojiUpdate = null;
    if (emojis_update) {
      latestEmojiUpdate = await emojiUpdateService.createEmojiUpdate(
        emojis_update,
        emojis_caption || "",
        userId,
      );
    } else {
      const userEmojiUpdates =
        await emojiUpdateService.getUserEmojiUpdates(userId);
      latestEmojiUpdate =
        userEmojiUpdates.length > 0 ? userEmojiUpdates[0] : null;
    }

    const updatedData: Record<string, any> = {};

    if (name) updatedData.name = name;
    if (chat_picture) {
      updatedData.chat_picture = chat_picture;
      // Include chat_picture_version so frontend can like the correct picture
      if (updatedUser?.chat_picture_version) {
        updatedData.chat_picture_version = updatedUser.chat_picture_version;
      }
    }
    if (chat_picture_caption !== undefined) {
      updatedData.chat_picture_caption = chat_picture_caption;
    }
    if (share_your_voice)
      updatedData.share_your_voice = newStatus?.share_your_voice;
    if (emojis_update) {
      updatedData.emojis_update = latestEmojiUpdate?.emojis_update;
      updatedData.emojis_caption = latestEmojiUpdate?.emojis_caption;
    }

    const userIds: string[] = await chatController.emitProfileUpdate(
      userId,
      updatedData,
    );

    // Get complete details of the updated user to send in FCM payload
    const updatedUserDetails = await getUserDetailsByIds([userId]);
    const updatedUserData = updatedUserDetails[0];

    // Prepare the complete user data payload
    const completeUserPayload = {
      user: {
        id: updatedUser?.id,
        email: updatedUser?.email || null,
        firstName: updatedUser?.firstName || null,
        lastName: updatedUser?.lastName || null,
        mobileNo: updatedUser?.mobileNo,
        isVerified: updatedUser?.isVerified,
        metadata: JSON.stringify(updatedUser?.metadata || {}),
        chat_picture: updatedUser?.chat_picture || null,
        chat_picture_version: updatedUser?.chat_picture_version || null,
        createdAt: (updatedUser as any)?.createdAt,
        updatedAt: (updatedUser as any)?.updatedAt
      },
      share_your_voice: newStatus ? {
        id: newStatus.id,
        userId: newStatus.userId,
        share_your_voice: newStatus.share_your_voice,
        likesCount: newStatus.likesCount || 0,
        deletedAt: newStatus.deletedAt || null,
        createdAt: newStatus.createdAt,
        updatedAt: newStatus.updatedAt,

      } : null,
      emoji_update: latestEmojiUpdate ? {
        id: latestEmojiUpdate.id,
        userId: latestEmojiUpdate.userId,
        emojis_update: latestEmojiUpdate.emojis_update,
        emojis_caption: latestEmojiUpdate.emojis_caption || null,
        deletedAt: latestEmojiUpdate.deletedAt || null,
        createdAt: latestEmojiUpdate.createdAt,
        updatedAt: latestEmojiUpdate.updatedAt
      } : null
    };

    // Send profile update to all contacts using multi-device support
    const userData = await getUserDetailsByIds(userIds);
    const sendPromises = userData.map(async (user) => {
      if (!user || !user.id) return;

      try {
        const result = await sendProfileUpdateToUser({
          receiverId: user.id,
          updatingUserId: userId,
          updatedData: completeUserPayload
        });

        console.log(`📤 Profile update sent to user ${user.id}:`, {
          tokenCount: result.tokenCount,
          successCount: result.successCount,
          failureCount: result.failureCount,
          invalidTokenCount: result.invalidTokenCount
        });
      } catch (error) {
        console.error(`Failed to send profile update to user ${user.id}:`, error);
      }
    });

    // Send all FCM notifications in parallel
    await Promise.all(sendPromises);

    return res.json({
      success: true,
      data: {
        user: updatedUser,
        share_your_voice: newStatus,
        emoji_update: latestEmojiUpdate,
      },
    });
  } catch (error: any) {
    console.error("Profile update error:", error);
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }
};

export const deleteUserProfilePic = async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: "Unauthorized",
      });
    }

    const user = await deleteProfilePic(userId);

    // Prepare updated data for profile picture deletion
    const updatedData: Record<string, any> = {
      chat_picture: null,
    };

    // Emit WebSocket profile update to contacts
    const userIds: string[] = await chatController.emitProfileUpdate(userId, updatedData);

    // Get user's status and emoji update for complete payload
    const userStatus = await statusService.getUserStatus(userId);
    const newStatus = userStatus.length > 0 ? userStatus[0] : null;

    const userEmojiUpdates = await emojiUpdateService.getUserEmojiUpdates(userId);
    const latestEmojiUpdate = userEmojiUpdates.length > 0 ? userEmojiUpdates[0] : null;

    // Prepare the complete user data payload
    const completeUserPayload = {
      user: {
        id: user?.id,
        email: user?.email || null,
        firstName: user?.firstName || null,
        lastName: user?.lastName || null,
        mobileNo: user?.mobileNo,
        isVerified: user?.isVerified,
        metadata: JSON.stringify(user?.metadata || {}),
        chat_picture: null, // Profile picture deleted
        chat_picture_version: user?.chat_picture_version || null,
        createdAt: (user as any)?.createdAt,
        updatedAt: (user as any)?.updatedAt
      },
      share_your_voice: newStatus ? {
        id: newStatus.id,
        userId: newStatus.userId,
        share_your_voice: newStatus.share_your_voice,
        likesCount: newStatus.likesCount || 0,
        deletedAt: newStatus.deletedAt || null,
        createdAt: newStatus.createdAt,
        updatedAt: newStatus.updatedAt,
      } : null,
      emoji_update: latestEmojiUpdate ? {
        id: latestEmojiUpdate.id,
        userId: latestEmojiUpdate.userId,
        emojis_update: latestEmojiUpdate.emojis_update,
        emojis_caption: latestEmojiUpdate.emojis_caption || null,
        deletedAt: latestEmojiUpdate.deletedAt || null,
        createdAt: latestEmojiUpdate.createdAt,
        updatedAt: latestEmojiUpdate.updatedAt
      } : null
    };

    // Send profile update to all contacts using multi-device support
    const userData = await getUserDetailsByIds(userIds);
    const sendPromises = userData.map(async (contactUser) => {
      if (!contactUser || !contactUser.id) return;

      try {
        const result = await sendProfileUpdateToUser({
          receiverId: contactUser.id,
          updatingUserId: userId,
          updatedData: completeUserPayload
        });

        console.log(`📤 Profile picture deletion update sent to user ${contactUser.id}:`, {
          tokenCount: result.tokenCount,
          successCount: result.successCount,
          failureCount: result.failureCount,
          invalidTokenCount: result.invalidTokenCount
        });
      } catch (error) {
        console.error(`Failed to send profile picture deletion update to user ${contactUser.id}:`, error);
      }
    });

    // Send all FCM notifications in parallel
    await Promise.all(sendPromises);

    res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      error: (error as Error).message,
    });
  }
};

export const userProfile = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }

    const userId = req.user.id;
    const user = await getById(userId);

    // Get user's latest status
    const userStatus = await statusService.getUserStatus(userId);
    const latestStatus = userStatus.length > 0 ? userStatus[0] : null;
    const userEmojiUpdates =
      await emojiUpdateService.getUserEmojiUpdates(userId);
    const latestEmojiUpdate =
      userEmojiUpdates.length > 0 ? userEmojiUpdates[0] : null;

    return res.json({
      success: true,
      data: {
        user,
        share_your_voice: latestStatus,
        emoji_update: latestEmojiUpdate,
      },
    });
  } catch (error: any) {
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }
};

export const checkContactList = async (req: Request, res: Response) => {
  try {
    const { contacts } = req.body;

    if (!req.user) {
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }

    if (!Array.isArray(contacts)) {
      return res.status(400).json({
        success: false,
        message: "Contacts must be an array of mobile numbers",
      });
    }

    if (contacts.length === 0) {
      return res.status(400).json({
        success: false,
        message: "Contacts array cannot be empty",
      });
    }

    const userMobileNo = (req.user as any).mobileNo;
    const filteredContacts = userMobileNo
      ? contacts.filter((c: any) => c && c.mobileNo !== userMobileNo)
      : contacts;

    // Transform contacts to the format expected by the service
    const transformedContacts = filteredContacts.map((contact: any) => ({
      contact_name: contact.name || contact.contact_name || "",
      contact_mobile_number:
        contact.mobileNo || contact.contact_mobile_number || "",
    }));

    //Storing contacts in DB
    await storeContacts(req.user.id, transformedContacts);

    const registeredContacts =
      await checkRegisteredContacts(transformedContacts);

    return res.json({
      success: true,
      data: registeredContacts,
    });
  } catch (error: any) {
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }
};

export const storeFcmToken = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }

    const userId = req.user.id;
    const { fcmToken, deviceId, platform, appVersion } = req.body;

    // Validate required fields
    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        message: 'fcmToken is required'
      });
    }

    if (!deviceId) {
      return res.status(400).json({
        success: false,
        message: 'deviceId is required (stable device identifier)'
      });
    }

    if (!platform || !['android', 'ios', 'web'].includes(platform)) {
      return res.status(400).json({
        success: false,
        message: 'platform is required and must be one of: android, ios, web'
      });
    }

    // UPSERT by (userId, deviceId) - update if exists, create if not
    const [deviceToken, created] = await FcmDeviceToken.upsert(
      {
        userId,
        deviceId,
        fcmToken,
        platform,
        appVersion: appVersion || null,
        lastSeenAt: new Date(),
        isActive: true
      },
      {
        returning: true
      }
    );

    console.log(
      created
        ? `✅ Registered new FCM token for user ${userId}, device ${deviceId} (${platform})`
        : `✅ Updated FCM token for user ${userId}, device ${deviceId} (${platform})`
    );

    // Also maintain backward compatibility - store in user metadata for old code
    const user = await getById(userId);
    let metadata = {};
    try {
      metadata = JSON.parse(user?.metadata || "{}");
    } catch (error) {
      console.error('Invalid metadata JSON:', error);
    }

    await update(userId, {
      metadata: {
        ...metadata,
        fcmToken: fcmToken // Keep the most recent token in metadata
      }
    });

    return res.json({
      success: true,
      data: {
        deviceTokenId: Array.isArray(deviceToken) ? deviceToken[0].id : deviceToken.id,
        created,
        message: created
          ? 'Device token registered successfully'
          : 'Device token updated successfully'
      }
    });
  } catch (error: any) {
    console.error("Could not store fcm token:", error);
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }
};

export const deleteUser = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }

    const userId = req.user.id;
    const { deleteAccount } = req.body;
    if (!deleteAccount) {
      return res.json({
        success: false,
        message: "Invalid request",
      });
    }

    // Update user profile
    const user = await getById(userId);

    const metadata = JSON.parse(user?.metadata || "{}");
    const updatedUser = await update(userId, {
      metadata: {
        ...metadata,
        deleteAccount: Date.now() || undefined,
      },
    });

    return res.json({
      success: true,
      message: "Account will be deleted in 30 days",
    });
  } catch (error: any) {
    console.error("Could not store fcm token:", error);
    return res.status(400).json({
      success: false,
      message: error.message,
    });
  }
};

export const refreshUserDetails = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    const { userIds } = req.body;

    if (!Array.isArray(userIds)) {
      return res.status(400).json({
        success: false,
        message: "userIds must be an array of user IDs",
      });
    }

    if (userIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: "userIds array cannot be empty",
      });
    }

    // Validate that all userIds are strings
    const invalidIds = userIds.filter(
      (id) => typeof id !== "string" || !id.trim(),
    );
    if (invalidIds.length > 0) {
      return res.status(400).json({
        success: false,
        message: "All userIds must be valid non-empty strings",
      });
    }

    const currentUserId = req.user.id;

    // Determine which of the requested IDs are actual contacts of the current user
    const contactUserIds = await getContactUserIdsForUser(
      currentUserId,
      userIds,
    );

    if (contactUserIds.length === 0) {
      // Preserve the response shape: return null for each requested id when none are contacts
      return res.json({
        success: true,
        data: userIds.map(() => null),
      });
    }

    const userDetails = await getUserDetailsByIds(userIds);
    const allowedSet = new Set(contactUserIds);
    const filteredDetails = userDetails.map((detail: any) => {
      if (!detail) {
        return null;
      }
      if (!allowedSet.has(detail.id)) {
        return null;
      }
      return detail;
    });

    return res.json({
      success: true,
      data: filteredDetails,
    });
  } catch (error: any) {
    console.error("Error refreshing user details:", error);
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

/**
 * Delta Sync Endpoint - Get contacts updated since a specific timestamp
 * Returns only contacts whose profiles changed after the given timestamp
 *
 * Query params:
 * - timestamp: ISO 8601 timestamp (e.g., 2026-01-28T10:00:00.000Z)
 *
 * Example: GET /api/users/contacts/updated-since?timestamp=2026-01-28T10:00:00.000Z
 */
export const getUpdatedContactsSince = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    const { timestamp } = req.query;

    if (!timestamp || typeof timestamp !== "string") {
      return res.status(400).json({
        success: false,
        message: "timestamp query parameter is required (ISO 8601 format)",
      });
    }

    // Validate timestamp format
    const parsedTimestamp = new Date(timestamp);
    if (isNaN(parsedTimestamp.getTime())) {
      return res.status(400).json({
        success: false,
        message: "Invalid timestamp format. Use ISO 8601 format (e.g., 2026-01-28T10:00:00.000Z)",
      });
    }

    const currentUserId = req.user.id;
    const updatedContacts = await getContactsUpdatedSince(
      currentUserId,
      parsedTimestamp,
    );

    return res.json({
      success: true,
      message: `Found ${updatedContacts.length} contact(s) updated since ${timestamp}`,
      data: updatedContacts,
      metadata: {
        sinceTimestamp: timestamp,
        resultCount: updatedContacts.length,
      },
    });
  } catch (error: any) {
    console.error("Error fetching updated contacts:", error);
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
