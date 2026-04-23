import { Router } from 'express';
import * as notificationController from '../controllers/notification.controller';
import { authMiddleware } from '../middlewares/auth.middleware';

const router = Router();

// Get all notifications for current user
router.get('/', authMiddleware, notificationController.getNotifications);

// Mark a specific notification as read
router.patch('/:id/read', authMiddleware, notificationController.markAsRead);

// Mark all notifications as read
router.post('/read-all', authMiddleware, notificationController.markAllAsRead);

// Delete a notification
router.delete('/:id', authMiddleware, notificationController.deleteNotification);

export default router;
