import { Router } from 'express';

import * as emojiUpdateController from '../controllers/emoji-update.controller';
import { authMiddleware } from '../middlewares/auth.middleware';

const router = Router();

// Apply auth middleware to all routes
router.use(authMiddleware);

// Create a new emoji update
router.post('/', emojiUpdateController.createEmojiUpdate);

// Get all emoji updates (public feed)
router.get('/all', emojiUpdateController.getAllEmojiUpdates);

// Get user's emoji updates
router.get('/user/:userId?', emojiUpdateController.getUserEmojiUpdates);

// Get current user's emoji update
router.get('/my/current', emojiUpdateController.getCurrentUserEmojiUpdate);

// Get a specific emoji update
router.get('/:emojiUpdateId', emojiUpdateController.getEmojiUpdate);

// Update an emoji update
router.put('/:emojiUpdateId', emojiUpdateController.updateEmojiUpdate);

// Delete an emoji update
router.delete('/:emojiUpdateId', emojiUpdateController.deleteEmojiUpdate);

export default router;
