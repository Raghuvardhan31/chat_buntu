import { Router } from 'express';
import {
	toggleLike,
	getLikeCount,
	checkIfLiked,
	getUsersWhoLiked,
} from '../controllers/chat-picture-like.controller';
import { authMiddleware } from '../middlewares/auth.middleware';

const router = Router();

// Toggle like on a user's profile (like/unlike)
router.post('/toggle', authMiddleware, toggleLike);

// Get like count for a user's profile (protected for privacy)
router.post('/count', authMiddleware, getLikeCount);

// Check if current user has liked a specific profile
router.post('/check', authMiddleware, checkIfLiked);

// Get users who liked a profile (protected for privacy)
router.post('/users', authMiddleware, getUsersWhoLiked);

export default router;
