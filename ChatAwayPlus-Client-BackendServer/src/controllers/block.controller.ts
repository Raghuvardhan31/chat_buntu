import { Request, Response } from 'express';
import { Op } from 'sequelize';
import User from '../db/models/user.model';
import BlockedUser from '../db/models/blocked-user.model';

export default class BlockController {
  /**
   * Block a user
   */
  public static async blockUser(req: Request, res: Response) {
    try {
      const { userId } = req.params;
      const blockerId = (req as any).user.id; // Assuming user is authenticated and user ID is attached to request

      if (userId === blockerId) {
        return res.status(400).json({ error: 'You cannot block yourself' });
      }

      // Check if user exists
      const userToBlock = await User.findByPk(userId);
      if (!userToBlock) {
        return res.status(404).json({ error: 'User not found' });
      }

      // Check if already blocked
      const existingBlock = await BlockedUser.findOne({
        where: {
          blockerId,
          blockedId: userId
        }
      });

      if (existingBlock) {
        return res.status(400).json({ error: 'User is already blocked' });
      }

      // Create block
      await BlockedUser.create({
        blockerId,
        blockedId: userId
      });

      return res.json({ message: 'User blocked successfully' });
    } catch (error) {
      console.error('Error blocking user:', error);
      return res.status(500).json({ error: 'Failed to block user' });
    }
  }

  /**
   * Unblock a user
   */
  public static async unblockUser(req: Request, res: Response) {
    try {
      const { userId } = req.params;
      const blockerId = (req as any).user.id; // Assuming user is authenticated

      const result = await BlockedUser.destroy({
        where: {
          blockerId,
          blockedId: userId
        }
      });

      if (result === 0) {
        return res.status(404).json({ error: 'Block record not found' });
      }

      return res.json({ message: 'User unblocked successfully' });
    } catch (error) {
      console.error('Error unblocking user:', error);
      return res.status(500).json({ error: 'Failed to unblock user' });
    }
  }

  /**
   * Get list of blocked users
   */
  public static async getBlockedUsers(req: Request, res: Response) {
    try {
      const userId = (req as any).user.id; // Assuming user is authenticated

      // Get all blocked user IDs where current user is the blocker
      const blockedRecords = await BlockedUser.findAll({
        where: {
          blockerId: userId
        },
        attributes: ['blockedId'],
        raw: true // This will return plain objects instead of Sequelize instances
      });

      console.log({ blockedRecords });

      if (blockedRecords.length === 0) {
        return res.json({
          success: true,
          data: [],
          count: 0
        });
      }

      // Extract blocked user IDs
      const blockedUserIds = blockedRecords.map(record => record.blockedId);

      // Get user details for blocked users
      const blockedUsers = await User.findAll({
        where: {
          id: blockedUserIds
        },
        attributes: ['id', 'firstName', 'lastName', 'chat_picture']
      });

      // Map to rename id to userId
      const formattedUsers = blockedUsers.map(user => ({
        userId: (user as any).id,
        firstName: (user as any).firstName,
        lastName: (user as any).lastName,
        chat_picture: (user as any).chat_picture
      }));

      return res.json({
        success: true,
        data: formattedUsers,
        count: formattedUsers.length
      });
    } catch (error) {
      console.error('Error fetching blocked users:', error);
      return res.status(500).json({ error: 'Failed to fetch blocked users' });
    }
  }

  /**
   * Check if a user is blocked
   */
  public static async checkIfBlocked(blockerId: string, blockedId: string): Promise<boolean> {
    if (!blockerId || !blockedId) return false;

    const block = await BlockedUser.findOne({
      where: {
        [Op.or]: [
          { blockerId, blockedId },
          { blockerId: blockedId, blockedId: blockerId }
        ]
      }
    });

    return !!block;
  }
}
