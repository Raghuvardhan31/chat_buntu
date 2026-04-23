import { Router } from "express";

import * as statusController from "../controllers/status.controller";
import { authMiddleware } from "../middlewares/auth.middleware";

const router = Router();

// Apply auth middleware to all routes
router.use(authMiddleware);

// Create a new status
router.post("/", statusController.createStatus);

// Get user's status
router.get("/user/:userId?", statusController.getUserStatus);

// Get current user's status with likes
router.get("/my/status", statusController.getMyStatusWithLikes);

// Get status liked by current user
router.get("/my/liked", statusController.getMyLikedStatus);

// Get a specific status
router.get("/:statusId", statusController.getStatus);

// Like a status
router.post("/:statusId/like", statusController.likeStatus);

// Unlike a status
router.delete("/:statusId/like", statusController.unlikeStatus);

// Get likes for a status
router.get("/:statusId/likes", statusController.getStatusLikes);

// Get like count for a status
router.get("/:statusId/likeCount", statusController.getStatusLikeCount);

// Check if user has liked a status
router.get("/:statusId/hasLiked", statusController.checkStatusLike);

export default router;
