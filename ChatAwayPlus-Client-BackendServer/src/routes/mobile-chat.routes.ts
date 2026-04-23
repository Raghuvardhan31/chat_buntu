import { Router } from 'express';
import { authMiddleware } from '../middlewares/auth.middleware';
import MobileChatController from '../controllers/mobile-chat.controller';
import ChatController from '../controllers/chat.controller';

const setupMobileChatRoutes = (chatController: ChatController) => {
	const router = Router();
	const mobileChatController = new MobileChatController(chatController);

	// Send a message (for mobile when WebSocket is not available)
	router.post('/messages', authMiddleware, mobileChatController.sendMessage.bind(mobileChatController));

	// Delete a message (only sender can delete)
	router.delete('/message/:chatId/delete-type/:deleteType', authMiddleware, mobileChatController.deleteMessage.bind(mobileChatController));

	// Get chat history with pagination
	router.get('/messages/:otherUserId', authMiddleware, mobileChatController.getChatHistory.bind(mobileChatController));

	// Sync chat messages - get new/updated messages since last sync time
	router.post('/messages/sync', authMiddleware, mobileChatController.syncChatMessages.bind(mobileChatController));

	// Get chat contacts (people you've chatted with)
	router.get('/contacts', authMiddleware, mobileChatController.getChatContacts.bind(mobileChatController));

	// Mark messages as read
	router.put('/messages/read', authMiddleware, mobileChatController.markMessagesAsRead.bind(mobileChatController));

	// Get unread message count
	router.get('/messages/unread/count', authMiddleware, mobileChatController.getUnreadCount.bind(mobileChatController));

	// Search messages
	router.get('/messages/search', authMiddleware, mobileChatController.searchMessages.bind(mobileChatController));

	// Mark messages as delivered
	router.put('/messages/delivered', authMiddleware, mobileChatController.markMessagesAsDelivered.bind(mobileChatController));

	// Update message status (delivered + read)
	router.put('/messages/status-update', authMiddleware, mobileChatController.updateMessageStatus.bind(mobileChatController));

	// Get message status
	router.post('/messages/status', authMiddleware, mobileChatController.getMessageStatus.bind(mobileChatController));

	router.get('/messages/starred', authMiddleware, mobileChatController.getStarredMessages.bind(mobileChatController));

	router.post('/messages/star', authMiddleware, mobileChatController.starMessage.bind(mobileChatController));

	router.post('/messages/unstar', authMiddleware, mobileChatController.unstarMessage.bind(mobileChatController));
	return router;
};

export default setupMobileChatRoutes;
