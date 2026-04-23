import { Router } from 'express';
import { authMiddleware } from '../middlewares/auth.middleware';
import BlockController from '../controllers/block.controller';

const router = Router();

// Block a user
router.post('/:userId', authMiddleware, BlockController.blockUser);

// Unblock a user
router.delete('/:userId', authMiddleware, BlockController.unblockUser);

// Get list of blocked users
router.get('/list', authMiddleware, BlockController.getBlockedUsers);

export default router;
