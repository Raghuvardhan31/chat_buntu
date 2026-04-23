import Notification from '../db/models/notification.model';
import User from '../db/models/user.model';

/**
 * Notification Service
 */

interface CreateNotificationData {
  senderId: string;
  receiverId: string;
  message: string;
  type: string;
  metadata?: any;
}

/**
 * Create a new persistent notification
 */
export const createNotification = async (data: CreateNotificationData): Promise<Notification> => {
  return await Notification.create({
    senderId: data.senderId,
    receiverId: data.receiverId,
    message: data.message,
    type: data.type,
    metadata: data.metadata,
    isRead: false,
  });
};

/**
 * Get notifications for a specific user
 */
export const getNotificationsForUser = async (userId: string, limit: number = 50, offset: number = 0): Promise<Notification[]> => {
  return await Notification.findAll({
    where: { receiverId: userId },
    include: [
      {
        model: User,
        as: 'senderUser',
        attributes: ['id', 'firstName', 'lastName', 'chat_picture'],
      },
    ],
    order: [['createdAt', 'DESC']],
    limit,
    offset,
  });
};

/**
 * Mark a notification as read
 */
export const markAsRead = async (notificationId: string, userId: string): Promise<boolean> => {
  const [updatedCount] = await Notification.update(
    { isRead: true },
    {
      where: {
        id: notificationId,
        receiverId: userId,
      },
    }
  );
  return updatedCount > 0;
};

/**
 * Mark all notifications as read for a user
 */
export const markAllAsRead = async (userId: string): Promise<number> => {
  const [updatedCount] = await Notification.update(
    { isRead: true },
    {
      where: {
        receiverId: userId,
        isRead: false,
      },
    }
  );
  return updatedCount;
};

/**
 * Delete a notification
 */
export const deleteNotification = async (notificationId: string, userId: string): Promise<boolean> => {
  const deletedCount = await Notification.destroy({
    where: {
      id: notificationId,
      receiverId: userId,
    },
  });
  return deletedCount > 0;
};
