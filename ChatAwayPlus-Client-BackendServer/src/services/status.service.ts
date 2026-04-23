import { Transaction, Op } from "sequelize";

import Status from '../db/models/status.model';
import StatusLike from '../db/models/status-like.model';
import User from '../db/models/user.model';
import sequelize from '../db/config/database';

export const createStatus = async (share_your_voice: string, userId: string): Promise<Status> => {
  const t: Transaction = await sequelize.transaction();

  try {
    // Soft delete all existing status for the user
    await Status.update(
      { deletedAt: new Date() },
      {
        where: {
          userId,
          deletedAt: null,
        },
        transaction: t,
      },
    );

    // Create new status
    const statusRecord = await Status.create(
      {
        userId,
        share_your_voice,
      },
      { transaction: t, raw: true },
    );

    await t.commit();
    const plainStatus = statusRecord.get({ plain: true }); // Get plain object
    return plainStatus;
  } catch (error) {
    await t.rollback();
    throw new Error(`Error creating share_your_voice: ${error}`);
  }
};

export const getUserStatus = async (userId: string): Promise<Status[]> => {
  try {
    const status = await Status.findAll({
      where: {
        userId,
        deletedAt: null,
      },
      include: [
        {
          model: User,
          attributes: ['firstName', 'lastName', 'chat_picture'],
        },
      ],
      order: [["createdAt", "DESC"]],
    });
    return status;
  } catch (error) {
    throw new Error(`Error fetching user status: ${error}`);
  }
};

export const getStatusById = async (
  statusId: string,
): Promise<Status | null> => {
  try {
    const status = await Status.findOne({
      where: {
        id: statusId,
        deletedAt: null,
      },
      include: [
        {
          model: User,
          attributes: ['firstName', 'lastName', 'chat_picture'],
        },
      ],
    });
    return status;
  } catch (error) {
    throw new Error(`Error fetching status: ${error}`);
  }
};

export const likeStatus = async (
  statusId: string,
  userId: string,
): Promise<{
  action: "liked" | "unliked";
  likeId?: string;
  statusId: string;
  statusOwnerId: string;
  statusText: string;
  likeCount: number;
}> => {
  console.log(`🔄 [STATUS_LIKE] START: statusId=${statusId}, userId=${userId}`);
  const t: Transaction = await sequelize.transaction();

  try {
    // Check if status exists and is not deleted
    const status = await Status.findOne({
      where: {
        id: statusId,
        deletedAt: null,
      },
      transaction: t,
    });

    if (!status) {
      console.log(`❌ [STATUS_LIKE] Status deleted: ${statusId}`);
      // Status is deleted - clean up any orphaned like records
      const orphanedLike = await StatusLike.findOne({
        where: {
          statusId,
          userId,
        },
        transaction: t,
      });

      if (orphanedLike) {
        await orphanedLike.destroy({ transaction: t });
        console.log(`🧹 [STATUS_LIKE] Cleaned up orphaned like record for deleted status`);
      }

      await t.rollback();
      throw new Error("STATUS_DELETED");
    }
    console.log(`✅ [STATUS_LIKE] Status exists: ${statusId}, ownerId=${(status as any).userId}`);

    // Check if already liked
    const existingLike = await StatusLike.findOne({
      where: {
        statusId,
        userId,
      },
      transaction: t,
    });
    console.log(`🔍 [STATUS_LIKE] Existing like check: ${existingLike ? 'FOUND (id=' + (existingLike as any).id + ')' : 'NOT FOUND'}`);

    let action: "liked" | "unliked";
    let likeId: string | undefined;

    if (existingLike) {
      // Unlike - remove the like
      await existingLike.destroy({ transaction: t });

      // Decrement likes count
      await Status.decrement("likesCount", {
        by: 1,
        where: {
          id: statusId,
          deletedAt: null,
        },
        transaction: t,
      });

      action = "unliked";
      console.log(`👎 [STATUS_LIKE] User ${userId} unliked status ${statusId}`);
    } else {
      console.log(`📝 [STATUS_LIKE] Creating new like record...`);
      const newLike = await StatusLike.create(
        {
          statusId,
          userId,
        },
        { transaction: t },
      );
      console.log(`📝 [STATUS_LIKE] Create result: id=${(newLike as any).id}`);

      // Increment likes count
      await Status.increment("likesCount", {
        by: 1,
        where: {
          id: statusId,
          deletedAt: null,
        },
        transaction: t,
      });

      action = "liked";
      likeId = (newLike as any).id;
      console.log(
        `👍 User ${userId} liked status ${statusId} (likeId: ${likeId})`,
      );
    }

    await t.commit();
    console.log(`✅ [STATUS_LIKE] Transaction committed`);

    // Get updated like count
    const likeCount = await StatusLike.count({
      where: { statusId },
    });
    console.log(`📊 [STATUS_LIKE] Like count for ${statusId}: ${likeCount}`);
    console.log(`✅ [STATUS_LIKE] END: action=${action}, likeCount=${likeCount}, likeId=${likeId}, statusOwnerId=${(status as any).userId}`);

    // Return data for notification
    return {
      action,
      likeId,
      statusId,
      statusOwnerId: (status as any).userId,
      statusText: (status as any).share_your_voice || '',
      likeCount,
    };
  } catch (error) {
    console.error(`❌ [STATUS_LIKE] Error:`, error);
    await t.rollback();
    throw new Error(`Error liking share_your_voice: ${error}`);
  }
};

// Alias for likeStatus - used by WebSocket handler (toggle-status-like event)
export const toggleStatusLike = likeStatus;

export const unlikeStatus = async (
  statusId: string,
  userId: string,
): Promise<number> => {
  const t: Transaction = await sequelize.transaction();

  try {
    // Check if status exists and is not deleted
    const status = await Status.findOne({
      where: {
        id: statusId,
        deletedAt: null,
      },
      transaction: t,
    });

    if (!status) {
      throw new Error("Status not found or has been deleted");
    }

    // Remove like record
    const deleted = await StatusLike.destroy({
      where: {
        statusId,
        userId,
      },
      transaction: t,
    });

    if (deleted) {
      // Decrement likes count only if a like was actually removed
      await Status.decrement("likesCount", {
        by: 1,
        where: {
          id: statusId,
          deletedAt: null,
        },
        transaction: t,
      });
    }

    await t.commit();

    // Get updated like count
    const likeCount = await StatusLike.count({
      where: { statusId },
    });

    return likeCount;
  } catch (error) {
    await t.rollback();
    throw new Error(`Error unliking share_your_voice: ${error}`);
  }
};

export const getStatusLikes = async (
  statusId: string,
): Promise<StatusLike[]> => {
  try {
    // First check if status exists and is not deleted
    const status = await Status.findOne({
      where: {
        id: statusId,
        deletedAt: null,
      },
    });

    if (!status) {
      throw new Error("Status not found or has been deleted");
    }

    const likes = await StatusLike.findAll({
      where: { statusId },
      include: [
        {
          model: User,
          attributes: ['id', 'firstName', 'lastName', 'chat_picture'],
        },
      ],
      order: [["createdAt", "DESC"]],
    });
    return likes;
  } catch (error) {
    throw new Error(`Error fetching status likes: ${error}`);
  }
};

export const hasUserLikedStatus = async (
  statusId: string,
  userId: string,
): Promise<boolean> => {
  try {
    // First check if status exists and is not deleted
    const status = await Status.findOne({
      where: {
        id: statusId,
        deletedAt: null,
      },
    });

    if (!status) {
      throw new Error("Status not found or has been deleted");
    }

    const like = await StatusLike.findOne({
      where: {
        statusId,
        userId,
      },
    });
    return !!like;
  } catch (error) {
    throw new Error(`Error checking status like: ${error}`);
  }
};

export const getUserStatusWithLikes = async (
  userId: string,
): Promise<any[]> => {
  try {
    const status = await Status.findAll({
      where: {
        userId,
        deletedAt: null,
      },
      include: [
        {
          model: User,
          attributes: ['firstName', 'lastName', 'chat_picture'],
        },
        {
          model: StatusLike,
          include: [{
            model: User,
            attributes: ['id', 'firstName', 'lastName', 'chat_picture'],
          }],
        },
      ],
      order: [["createdAt", "DESC"]],
    });
    return status;
  } catch (error) {
    throw new Error(`Error fetching user status with likes: ${error}`);
  }
};

export const getStatusLikedByUser = async (userId: string): Promise<any[]> => {
  try {
    const likedStatus = await StatusLike.findAll({
      where: { userId },
      include: [
        {
          model: Status,
          where: {
            deletedAt: null,
          },
          include: [
            {
              model: User,
              attributes: ['firstName', 'lastName', 'chat_picture'],
            },
          ],
        },
      ],
      order: [["createdAt", "DESC"]],
    });
    return likedStatus.map((like) => like.get("status"));
  } catch (error) {
    throw new Error(`Error fetching status liked by user: ${error}`);
  }
};

export const getStatusLikeCount = async (statusId: string): Promise<number> => {
  try {
    // Check if status exists and is not deleted
    const status = await Status.findOne({
      where: {
        id: statusId,
        deletedAt: null,
      },
    });

    if (!status) {
      throw new Error("Status not found or has been deleted");
    }

    // Return the like count from the status record
    return (status as any).likesCount || 0;
  } catch (error) {
    throw new Error(`Error fetching status like count: ${error}`);
  }
};
