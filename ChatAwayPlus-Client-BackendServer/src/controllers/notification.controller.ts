import { Request, Response } from 'express';
import * as notificationService from '../services/notification.service';

interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
  };
}

/**
 * Get user notifications
 */
export const getNotifications = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ success: false, error: 'User not authenticated' });
    }

    const limit = parseInt(req.query.limit as string) || 50;
    const offset = parseInt(req.query.offset as string) || 0;

    const notifications = await notificationService.getNotificationsForUser(userId, limit, offset);

    return res.status(200).json({
      success: true,
      data: notifications,
    });
  } catch (error: any) {
    console.error('❌ Error fetching notifications:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to fetch notifications',
    });
  }
};

/**
 * Mark notification as read
 */
export const markAsRead = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    const { id } = req.params;

    if (!userId) {
      return res.status(401).json({ success: false, error: 'User not authenticated' });
    }

    const success = await notificationService.markAsRead(id, userId);

    if (!success) {
      return res.status(404).json({ success: false, error: 'Notification not found' });
    }

    return res.status(200).json({
      success: true,
      message: 'Notification marked as read',
    });
  } catch (error: any) {
    console.error('❌ Error marking notification as read:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to update notification',
    });
  }
};

/**
 * Mark all notifications as read
 */
export const markAllAsRead = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ success: false, error: 'User not authenticated' });
    }

    const count = await notificationService.markAllAsRead(userId);

    return res.status(200).json({
      success: true,
      message: `${count} notifications marked as read`,
    });
  } catch (error: any) {
    console.error('❌ Error marking all notifications as read:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to update notifications',
    });
  }
};

/**
 * Delete a notification
 */
export const deleteNotification = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    const { id } = req.params;

    if (!userId) {
      return res.status(401).json({ success: false, error: 'User not authenticated' });
    }

    const success = await notificationService.deleteNotification(id, userId);

    if (!success) {
      return res.status(404).json({ success: false, error: 'Notification not found' });
    }

    return res.status(200).json({
      success: true,
      message: 'Notification deleted',
    });
  } catch (error: any) {
    console.error('❌ Error deleting notification:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to delete notification',
    });
  }
};
