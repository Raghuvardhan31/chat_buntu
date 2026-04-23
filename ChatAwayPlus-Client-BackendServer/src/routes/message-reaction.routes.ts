import { Router } from 'express';
import * as messageReactionController from '../controllers/message-reaction.controller';
import { authMiddleware } from '../middlewares/auth.middleware';

const router = Router();


// Add or update a reaction (or remove if same emoji is sent)
router.post(
	'/',
	authMiddleware,
	messageReactionController.addOrUpdateReaction
);

// Get most popular emojis (for quick access suggestions)

router.get(
	'/popular-emojis',
	authMiddleware,
	messageReactionController.getMostUsedEmojis
);

// Get reactions for multiple messages (batch)
router.post(
	'/batch',
	authMiddleware,
	messageReactionController.getReactionsForMessages
);

// Remove a reaction
router.delete(
	'/:messageId',
	authMiddleware,
	messageReactionController.removeReaction
);

// Get reactions for a specific message
router.get(
	'/:messageId',
	authMiddleware,
	messageReactionController.getMessageReactions
);

export default router;
