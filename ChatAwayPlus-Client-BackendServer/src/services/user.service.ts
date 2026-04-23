import jwt from "jsonwebtoken";
import { Op, Model, Optional } from "sequelize";
import sequelize from "../db/config/database";

import User from "../db/models/user.model";
import Status from "../db/models/status.model";
import EmojiUpdate from "../db/models/emoji-update.model";
import Location from "../db/models/location.model";
import Contact from "../db/models/contact.model";
import { config } from "../config";
import admin from "firebase-admin";

interface UpdateProfileDto {
  name?: string;
  chat_picture?: string;
  chat_picture_caption?: string;
  metadata?: any;
}

export const createUser = async (userData: {
  name: string;
  email: string;
  password: string;
  phone?: string;
  dob?: Date;
}): Promise<User> => {
  try {
    const user = await User.create(userData);
    return user;
  } catch (error) {
    throw new Error(`Error creating user: ${error}`);
  }
};

export const getAllUsers = async (): Promise<User[]> => {
  try {
    const users = await User.findAll({
      attributes: { exclude: ["password"] },
    });
    return users;
  } catch (error) {
    throw new Error(`Error fetching users: ${error}`);
  }
};

export const getById = async (id: string): Promise<User | null> => {
  try {
    const user = await User.findByPk(id, {
      attributes: { exclude: ["password"] },
    });
    return user;
  } catch (error) {
    throw new Error(`Error fetching user: ${error}`);
  }
};

export const updateUser = async (
  id: number,
  userData: Partial<{
    name: string;
    email: string;
    phone: string;
    dob: Date;
  }>,
): Promise<[number, User[]]> => {
  try {
    const [affectedCount, affectedRows] = await User.update(userData, {
      where: { id },
      returning: true,
    });
    return [affectedCount, affectedRows];
  } catch (error) {
    throw new Error(`Error updating user: ${error}`);
  }
};

export const deleteUser = async (id: number): Promise<number> => {
  try {
    const deletedCount = await User.destroy({
      where: { id },
    });
    return deletedCount;
  } catch (error) {
    throw new Error(`Error deleting user: ${error}`);
  }
};

export const updateProfile = async (userId: string, data: UpdateProfileDto) => {
  try {
    console.log("updateProfile service - userId:", userId);
    console.log("updateProfile service - data:", data);

    const user = await User.findByPk(userId);

    if (!user) {
      throw new Error("User not found");
    }

    const updates: any = {};

    if (data.name !== undefined) {
      updates.firstName = data.name;
    }

    if (data.chat_picture !== undefined) {
      updates.chat_picture = data.chat_picture;
      // Generate new chat_picture_version when profile picture changes
      const { v4: uuidv4 } = require("uuid");
      updates.chat_picture_version = uuidv4();
      console.log("Updating chat_picture to:", data.chat_picture);
      console.log(
        "Generated new chat_picture_version:",
        updates.chat_picture_version,
      );
    }

    if (data.chat_picture_caption !== undefined) {
      updates.chat_picture_caption = data.chat_picture_caption;
      console.log(
        "Updating chat_picture_caption to:",
        data.chat_picture_caption,
      );
    }

    if (data.metadata !== undefined) {
      updates.metadata = data.metadata;
    }

    console.log("Updates to apply:", updates);

    await User.update(updates, {
      where: { id: userId },
      returning: true,
    });

    // Fetch and return the updated user
    const updatedUser = await User.findByPk(userId, {
      attributes: { exclude: ["password"] },
    });

    console.log("Updated user chat_picture:", updatedUser?.chat_picture);

    return updatedUser;
  } catch (error) {
    throw new Error(`Error updating profile: ${error}`);
  }
};

export const getUserFromToken = async (token: string) => {
  try {
    if (!token) {
      throw new Error("No token provided");
    }

    if (!config.jwt?.secret) {
      throw new Error("JWT secret is not configured");
    }

    const tokenString = token.startsWith("Bearer ") ? token.slice(7) : token;
    const decoded = jwt.verify(tokenString, config.jwt.secret) as {
      userId: string;
    };
    const user = await User.findByPk(decoded.userId);

    if (!user) {
      throw new Error("User not found");
    }

    return user;
  } catch (error) {
    throw new Error(`Invalid token: ${error}`);
  }
};

export const deleteProfilePic = async (userId: string): Promise<User> => {
  try {
    const user = await User.findByPk(userId);
    if (!user) {
      throw new Error("User not found");
    }

    await User.update(
      { chat_picture: null },
      {
        where: { id: userId },
        returning: true,
      },
    );

    // Fetch and return the updated user
    const updatedUser = await User.findByPk(userId, {
      attributes: { exclude: ["password"] },
    });

    if (!updatedUser) {
      throw new Error("Failed to fetch updated user");
    }

    return updatedUser;
  } catch (error) {
    throw new Error(`Error deleting profile picture: ${error}`);
  }
};

export const checkRegisteredContacts = async (
  contacts: { contact_name: string; contact_mobile_number: string }[],
) => {
  // Extract and deduplicate valid mobile numbers
  const uniqueNumbers = [
    ...new Set(
      contacts.map((contact) => contact.contact_mobile_number).filter(Boolean),
    ),
  ];

  // Process in smaller batches to prevent memory issues
  const BATCH_SIZE = 100;
  const results = [];

  for (let i = 0; i < uniqueNumbers.length; i += BATCH_SIZE) {
    const batchNumbers = uniqueNumbers.slice(i, i + BATCH_SIZE);

    // Fetch registered users by mobileNo for this batch
    const users = await User.findAll({
      where: {
        mobileNo: batchNumbers,
      },
      attributes: [
        "id",
        "mobileNo",
        "firstName",
        "lastName",
        "chat_picture",
        "chat_picture_version",
        "updatedAt",
      ],
      raw: true,
    });

    const userIds = users.map((u) => u.id);
    if (userIds.length === 0) continue;

    // Get latest status for each user in the batch
    interface LatestRecord {
      userId: string;
      latestDate: Date;
    }

    // First, get the latest status date for each user
    const latestStatusDates = (await Status.findAll({
      where: {
        userId: { [Op.in]: userIds },
        deletedAt: null,
      },
      attributes: [
        "userId",
        [sequelize.fn("MAX", sequelize.col("createdAt")), "latestDate"],
      ],
      group: ["userId"],
      raw: true,
    })) as unknown as LatestRecord[];

    // Then get the actual status records for these dates
    const statuses =
      latestStatusDates.length > 0
        ? await Status.findAll({
          where: {
            [Op.or]: latestStatusDates.map((status) => ({
              userId: status.userId,
              createdAt: status.latestDate,
              deletedAt: null,
            })),
          },
          attributes: ["id", "userId", "share_your_voice", "createdAt"],
          raw: true,
        })
        : [];

    // Get latest emoji update for each user in the batch
    const latestEmojiUpdateDates = (await EmojiUpdate.findAll({
      where: {
        userId: { [Op.in]: userIds },
        deletedAt: null,
      },
      attributes: [
        "userId",
        [sequelize.fn("MAX", sequelize.col("createdAt")), "latestDate"],
      ],
      group: ["userId"],
      raw: true,
    })) as unknown as LatestRecord[];

    // Then get the actual emoji update records for these dates
    const emojiUpdates =
      latestEmojiUpdateDates.length > 0
        ? await EmojiUpdate.findAll({
          where: {
            [Op.or]: latestEmojiUpdateDates.map((emojiUpdate) => ({
              userId: emojiUpdate.userId,
              createdAt: emojiUpdate.latestDate,
              deletedAt: null,
            })),
          },
          attributes: [
            "id",
            "userId",
            "emojis_update",
            "emojis_caption",
            "createdAt",
          ],
          raw: true,
        })
        : [];

    //removing location for the checking contacts for time being

    // // Get latest location for each user in the batch
    // const latestLocationDates = await Location.findAll({
    //   where: {
    //     userId: { [Op.in]: userIds }
    //   },
    //   attributes: [
    //     'userId',
    //     [sequelize.fn('MAX', sequelize.col('createdAt')), 'latestDate']
    //   ],
    //   group: ['userId'],
    //   raw: true
    // }) as unknown as LatestRecord[];

    // // Get the actual location records for these dates
    // const locations = latestLocationDates.length > 0 ? await Location.findAll({
    //   where: {
    //     [Op.or]: latestLocationDates.map(location => ({
    //       userId: location.userId,
    //       createdAt: location.latestDate
    //     }))
    //   },
    //   attributes: ['id', 'userId', 'name', 'description', 'photos', 'createdAt'],
    //   raw: true
    // }) : [];

    // Create maps for quick lookup
    const statusMap = new Map(statuses.map((s) => [s.userId, s]));
    const emojiUpdateMap = new Map(emojiUpdates.map((e) => [e.userId, e]));
    // const locationMap = new Map(locations.map(l => [l.userId, l]));

    // Process batch results
    const batchResults = users.map((user) => ({
      contact_mobile_number: user.mobileNo,
      user_details: {
        user_id: user.id,
        contact_name:
          `${user.firstName || ""} ${user.lastName || ""}`.trim() || null,
        chat_picture: user.chat_picture,
        chat_picture_version: user.chat_picture_version,
        updatedAt: user.updatedAt,
        recentStatus: statusMap.get(user.id) || null,
        recentEmojiUpdate: emojiUpdateMap.get(user.id) || null,
        // recentLocation: locationMap.get(user.id) || null
      },
    }));

    results.push(...batchResults);
  }

  // Create a map of mobile numbers to user details
  const userDetailsMap = new Map(
    results.map((item) => [item.contact_mobile_number, item.user_details]),
  );

  // Add user details to each contact
  return contacts.map((contact) => {
    const userDetails = userDetailsMap.get(contact.contact_mobile_number);
    return {
      ...contact,
      is_registered: Boolean(userDetails),
      ...(userDetails && {
        user_details: {
          user_id: userDetails.user_id,
          contact_name: userDetails.contact_name,
          chat_picture: userDetails.chat_picture,
          chat_picture_version: userDetails.chat_picture_version,
          updatedAt: userDetails.updatedAt,
          recentStatus: userDetails.recentStatus
            ? {
              statusId: userDetails.recentStatus.id,
              share_your_voice: userDetails.recentStatus.share_your_voice,
              createdAt: userDetails.recentStatus.createdAt,
            }
            : null,
          recentEmojiUpdate: userDetails.recentEmojiUpdate
            ? {
              emojis_update: userDetails.recentEmojiUpdate.emojis_update,
              emojis_caption: userDetails.recentEmojiUpdate.emojis_caption,
              createdAt: userDetails.recentEmojiUpdate.createdAt,
            }
            : null,
          // recentLocation: userDetails.recentLocation ? {
          //   name: userDetails.recentLocation.name,
          //   description: userDetails.recentLocation.description,
          //   photos: userDetails.recentLocation.photos,
          //   createdAt: userDetails.recentLocation.createdAt
          // } : null
        },
      }),
    };
  });
};

export const getUserDetailsByIds = async (userIds: string[]) => {
  // Remove duplicates and filter out empty values
  const uniqueUserIds = [...new Set(userIds.filter(Boolean))];

  if (uniqueUserIds.length === 0) {
    return [];
  }

  // Process in smaller batches to prevent memory issues
  const BATCH_SIZE = 100;
  const results = [];

  for (let i = 0; i < uniqueUserIds.length; i += BATCH_SIZE) {
    const batchUserIds = uniqueUserIds.slice(i, i + BATCH_SIZE);

    // Fetch users by IDs for this batch
    const users = await User.findAll({
      where: {
        id: batchUserIds,
      },
      attributes: [
        "id",
        "mobileNo",
        "firstName",
        "lastName",
        "chat_picture",
        "chat_picture_version",
        "metadata",
        "updatedAt",
      ],
      raw: true,
    });

    if (users.length === 0) continue;

    const foundUserIds = users.map((u) => u.id);

    // Get latest status for each user in the batch
    interface LatestRecord {
      userId: string;
      latestDate: Date;
    }

    // First, get the latest status date for each user
    const latestStatusDates = (await Status.findAll({
      where: {
        userId: { [Op.in]: foundUserIds },
        deletedAt: null,
      },
      attributes: [
        "userId",
        [sequelize.fn("MAX", sequelize.col("createdAt")), "latestDate"],
      ],
      group: ["userId"],
      raw: true,
    })) as unknown as LatestRecord[];

    // Then get the actual status records for these dates
    const statuses =
      latestStatusDates.length > 0
        ? await Status.findAll({
          where: {
            [Op.or]: latestStatusDates.map((status) => ({
              userId: status.userId,
              createdAt: status.latestDate,
              deletedAt: null,
            })),
          },
          attributes: ["id", "userId", "share_your_voice", "createdAt"],
          raw: true,
        })
        : [];

    // Get latest emoji update for each user in the batch
    const latestEmojiUpdateDates = (await EmojiUpdate.findAll({
      where: {
        userId: { [Op.in]: foundUserIds },
        deletedAt: null,
      },
      attributes: [
        "userId",
        [sequelize.fn("MAX", sequelize.col("createdAt")), "latestDate"],
      ],
      group: ["userId"],
      raw: true,
    })) as unknown as LatestRecord[];

    // Then get the actual emoji update records for these dates
    const emojiUpdates =
      latestEmojiUpdateDates.length > 0
        ? await EmojiUpdate.findAll({
          where: {
            [Op.or]: latestEmojiUpdateDates.map((emojiUpdate) => ({
              userId: emojiUpdate.userId,
              createdAt: emojiUpdate.latestDate,
              deletedAt: null,
            })),
          },
          attributes: [
            "id",
            "userId",
            "emojis_update",
            "emojis_caption",
            "createdAt",
          ],
          raw: true,
        })
        : [];

    // Create maps for quick lookup
    const statusMap = new Map(statuses.map((s) => [s.userId, s]));
    const emojiUpdateMap = new Map(emojiUpdates.map((e) => [e.userId, e]));

    // Process batch results
    const batchResults = users.map((user) => ({
      id: user.id,
      mobileNo: user.mobileNo,
      name: `${user.firstName || ""} ${user.lastName || ""}`.trim() || null,
      chat_picture: user.chat_picture,
      chat_picture_version: user.chat_picture_version,
      metadata: JSON.parse(user.metadata || "{}"),
      updatedAt: user.updatedAt,
      recentStatus: statusMap.get(user.id)
        ? {
          statusId: statusMap.get(user.id)!.id,
          share_your_voice: statusMap.get(user.id)!.share_your_voice,
          createdAt: statusMap.get(user.id)!.createdAt,
        }
        : null,
      recentEmojiUpdate: emojiUpdateMap.get(user.id)
        ? {
          emojis_update: emojiUpdateMap.get(user.id)!.emojis_update,
          emojis_caption: emojiUpdateMap.get(user.id)!.emojis_caption,
          createdAt: emojiUpdateMap.get(user.id)!.createdAt,
        }
        : null,
    }));

    results.push(...batchResults);
  }

  // Create a map for quick lookup by original order
  const userDetailsMap = new Map(results.map((user) => [user.id, user]));

  // Return users in the same order as requested, with null for not found users
  return userIds.map((userId) => userDetailsMap.get(userId) || null);
};

export const storeContacts = async (
  userId: string,
  contacts: { contact_name: string; contact_mobile_number: string }[],
) => {
  try {
    // Extract mobile numbers
    const mobileNumbers = contacts.map((c) => c.contact_mobile_number);

    const matchedUsers = await User.findAll({
      where: {
        mobileNo: {
          [Op.in]: mobileNumbers,
        },
      },
      attributes: ["id"],
      raw: true,
    });

    // Fetch existing contacts to avoid inserting again
    const existing = await Contact.findAll({
      where: {
        userId,
        contactUserId: {
          [Op.in]: matchedUsers.map((e) => e.id),
        },
      },
      attributes: ["contactUserId"],
      raw: true,
    });

    // remove existing contacts to avoid duplicates
    const finalInsert = matchedUsers
      .filter((user) => !existing.find((e) => e.contactUserId === user.id))
      .map((user) => ({
        userId,
        contactUserId: user.id,
      }));

    // Insert only new contacts
    if (finalInsert.length > 0) {
      await Contact.bulkCreate(finalInsert);

      // Notify User A (who is syncing) that they have new registered contacts
      // This allows User A's contact list to update automatically
      try {
        const userWhoIsSyncing = await User.findByPk(userId, {
          attributes: ["id", "metadata"],
        });

        if (userWhoIsSyncing) {
          let metadata: any = {};
          const rawMetadata = (userWhoIsSyncing as any).metadata;

          if (rawMetadata) {
            if (typeof rawMetadata === "string") {
              try {
                metadata = JSON.parse(rawMetadata);
              } catch {
                metadata = {};
              }
            } else {
              metadata = rawMetadata || {};
            }
          }

          const fcmToken = metadata?.fcmToken;

          if (fcmToken) {
            // Send silent notification to User A to refresh their contact list
            await admin.messaging().send({
              token: fcmToken,
              data: {
                type: "CONTACTS_CHANGED",
                message: "Your contacts list has been updated",
                newContactsCount: String(finalInsert.length),
                timestamp: new Date().toISOString()
              },
              android: { priority: "high" },
              apns: {
                headers: {
                  "apns-priority": "5",
                },
                payload: {
                  aps: { "content-available": 1 },
                },
              },
            });
          }
        }
      } catch (notifyError) {
        console.error("Error notifying user about contact sync:", notifyError);
        // Don't fail the whole operation if notification fails
      }
    }

    return {
      message: "Contacts stored",
      added: finalInsert.length,
    };
  } catch (error) {
    console.error("Error storing contacts:", error);
  }
};

export const getContactUserIdsForUser = async (
  userId: string,
  candidateUserIds: string[],
): Promise<string[]> => {
  if (!candidateUserIds.length) {
    return [];
  }

  const contacts = await Contact.findAll({
    where: {
      userId,
      contactUserId: {
        [Op.in]: candidateUserIds,
      },
    },
    attributes: ["contactUserId"],
    raw: true,
  });

  return contacts.map((c: any) => c.contactUserId);
};

export const notifyContactsAboutNewUser = async (newUser: {
  id: string;
  firstName?: string;
  lastName?: string;
  mobileNo: string;
  chat_picture?: string;
  chat_picture_version?: string;
}) => {
  try {
    const contacts = await Contact.findAll({
      where: { contactUserId: newUser.id },
      attributes: ["userId"],
      raw: true,
    });

    if (!contacts.length) {
      return { notified: 0 };
    }

    const userIds = contacts.map((c: any) => c.userId);

    const users = await User.findAll({
      where: { id: { [Op.in]: userIds } },
      attributes: ["id", "metadata"],
      raw: true,
    });

    const targets: { userId: string; token: string }[] = [];

    for (const u of users) {
      let meta: any = {};
      if (u && (u as any).metadata) {
        if (typeof (u as any).metadata === "string") {
          try {
            meta = JSON.parse((u as any).metadata);
          } catch {
            meta = {};
          }
        } else {
          meta = (u as any).metadata || {};
        }
      }

      if (meta.fcmToken) {
        targets.push({ userId: (u as any).id, token: meta.fcmToken });
      }
    }

    if (!targets.length) {
      return { notified: 0 };
    }

    const name = `${newUser.firstName || ''} ${newUser.lastName || ''}`.trim();

    let successCount = 0;
    let failedCount = 0;

    for (const t of targets) {
      try {
        await admin.messaging().send({
          token: t.token,
          data: {
            type: "CONTACTS_CHANGED",
            userId: newUser.id,
            mobileNo: newUser.mobileNo,
            // Additional fields for app context
            name,
            chat_picture: newUser.chat_picture || '',
            timestamp: new Date().toISOString()
          },
          android: { priority: "high" },
          apns: {
            headers: {
              "apns-priority": "5",
            },
            payload: {
              aps: { "content-available": 1 },
            },
          },
        });
        successCount += 1;
      } catch {
        failedCount += 1;
      }
    }

    return { notified: successCount, failed: failedCount };
  } catch (err) {
    console.error("Error notifying offline users:", err);
    return { notified: 0, failed: 0 };
  }
};

/**
 * Get contacts updated since a specific timestamp (Delta Sync - Option 2)
 * Returns only contacts whose profiles were modified after the given timestamp
 */
export const getContactsUpdatedSince = async (
  currentUserId: string,
  sinceTimestamp: Date,
) => {
  try {
    // Get all contact user IDs for the current user
    const contacts = await Contact.findAll({
      where: { userId: currentUserId },
      attributes: ["contactUserId"],
      raw: true,
    });

    if (contacts.length === 0) {
      return [];
    }

    const contactUserIds = contacts.map((c) => c.contactUserId);

    // Find contacts updated after the given timestamp
    const updatedUsers = await User.findAll({
      where: {
        id: { [Op.in]: contactUserIds },
        updatedAt: { [Op.gt]: sinceTimestamp },
      },
      attributes: [
        "id",
        "mobileNo",
        "firstName",
        "lastName",
        "chat_picture",
        "chat_picture_version",
        "metadata",
        "updatedAt",
      ],
      raw: true,
    });

    if (updatedUsers.length === 0) {
      return [];
    }

    const updatedUserIds = updatedUsers.map((u) => u.id);

    // Get latest status for each updated user
    interface LatestRecord {
      userId: string;
      latestDate: Date;
    }

    const latestStatusDates = (await Status.findAll({
      where: {
        userId: { [Op.in]: updatedUserIds },
        deletedAt: null,
      },
      attributes: [
        "userId",
        [sequelize.fn("MAX", sequelize.col("createdAt")), "latestDate"],
      ],
      group: ["userId"],
      raw: true,
    })) as unknown as LatestRecord[];

    const statuses =
      latestStatusDates.length > 0
        ? await Status.findAll({
          where: {
            [Op.or]: latestStatusDates.map((status) => ({
              userId: status.userId,
              createdAt: status.latestDate,
              deletedAt: null,
            })),
          },
          attributes: ["id", "userId", "share_your_voice", "createdAt"],
          raw: true,
        })
        : [];

    // Get latest emoji update for each updated user
    const latestEmojiUpdateDates = (await EmojiUpdate.findAll({
      where: {
        userId: { [Op.in]: updatedUserIds },
        deletedAt: null,
      },
      attributes: [
        "userId",
        [sequelize.fn("MAX", sequelize.col("createdAt")), "latestDate"],
      ],
      group: ["userId"],
      raw: true,
    })) as unknown as LatestRecord[];

    const emojiUpdates =
      latestEmojiUpdateDates.length > 0
        ? await EmojiUpdate.findAll({
          where: {
            [Op.or]: latestEmojiUpdateDates.map((emojiUpdate) => ({
              userId: emojiUpdate.userId,
              createdAt: emojiUpdate.latestDate,
              deletedAt: null,
            })),
          },
          attributes: [
            "id",
            "userId",
            "emojis_update",
            "emojis_caption",
            "createdAt",
          ],
          raw: true,
        })
        : [];

    // Create maps for quick lookup
    const statusMap = new Map(statuses.map((s) => [s.userId, s]));
    const emojiUpdateMap = new Map(emojiUpdates.map((e) => [e.userId, e]));

    // Build result with profile data + latest status/emoji
    return updatedUsers.map((user) => ({
      id: user.id,
      mobileNo: user.mobileNo,
      name: `${user.firstName || ""} ${user.lastName || ""}`.trim() || null,
      chat_picture: user.chat_picture,
      chat_picture_version: user.chat_picture_version,
      metadata: JSON.parse(user.metadata || "{}"),
      updatedAt: user.updatedAt,
      recentStatus: statusMap.get(user.id)
        ? {
          statusId: statusMap.get(user.id)!.id,
          share_your_voice: statusMap.get(user.id)!.share_your_voice,
          createdAt: statusMap.get(user.id)!.createdAt,
        }
        : null,
      recentEmojiUpdate: emojiUpdateMap.get(user.id)
        ? {
          emojis_update: emojiUpdateMap.get(user.id)!.emojis_update,
          emojis_caption: emojiUpdateMap.get(user.id)!.emojis_caption,
          createdAt: emojiUpdateMap.get(user.id)!.createdAt,
        }
        : null,
    }));
  } catch (error) {
    throw new Error(`Error fetching updated contacts: ${error}`);
  }
};
