import { Request, Response } from "express";
import * as statusService from "../services/status.service";
import { chatController } from "../index";

export const createStatus = async (req: Request, res: Response) => {
  try {
    const { share_your_voice } = req.body;

    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const statusRecord = await statusService.createStatus(
      share_your_voice,
      req.user.id,
    );
    res.status(201).json(statusRecord);
  } catch (error) {
    res.status(500).json({ message: `Error creating status: ${error}` });
  }
};

export const getUserStatus = async (req: Request, res: Response) => {
  try {
    const userId = req.params.userId || req.user?.id;

    if (!userId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const status = await statusService.getUserStatus(userId);
    res.json(status);
  } catch (error) {
    res.status(500).json({ message: `Error fetching status: ${error}` });
  }
};

export const getStatus = async (req: Request, res: Response) => {
  try {
    const { statusId } = req.params;
    const status = await statusService.getStatusById(statusId);

    if (!status) {
      return res.status(404).json({ message: "Status not found" });
    }

    res.json(status);
  } catch (error) {
    res.status(500).json({ message: `Error fetching status: ${error}` });
  }
};

export const likeStatus = async (req: Request, res: Response) => {
  try {
    const { statusId } = req.params;

    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    if (!statusId) {
      return res.status(400).json({
        success: false,
        message: "Status ID is required",
      });
    }

    const result = await statusService.likeStatus(statusId, req.user.id);

    if (!result) {
      return res.status(500).json({
        success: false,
        message: "Failed to like status",
      });
    }

    // Send notification to status owner (only if liked and not own status)
    if (
      result.action === "liked" &&
      result.statusOwnerId &&
      result.likeId &&
      result.statusOwnerId !== req.user.id
    ) {
      try {
        await chatController.sendStatusLikeNotification({
          likeId: result.likeId,
          fromUserId: req.user.id,
          toUserId: result.statusOwnerId,
          statusId: statusId,
          statusText: result.statusText,
        });
      } catch (notificationError) {
        console.error(
          "❌ Error sending status-like notification:",
          notificationError,
        );
        // Don't fail the request if notification fails
      }
    }

    res.json({
      success: true,
      message:
        result.action === "liked"
          ? "Status liked successfully"
          : "Status unliked successfully",
      data: {
        action: result.action,
        likeId: result.likeId,
        likeCount: result.likeCount,
      },
    });
  } catch (error) {
    res.status(500).json({ message: `Error liking status: ${error}` });
  }
};

export const unlikeStatus = async (req: Request, res: Response) => {
  try {
    const { statusId } = req.params;

    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    if (!statusId) {
      return res.status(400).json({
        success: false,
        message: "Status ID is required",
      });
    }

    const likeCount = await statusService.unlikeStatus(statusId, req.user.id);

    res.json({
      success: true,
      message: "Status unliked successfully",
      data: {
        likeCount,
      },
    });
  } catch (error) {
    res.status(500).json({ message: `Error unliking status: ${error}` });
  }
};

export const getStatusLikes = async (req: Request, res: Response) => {
  try {
    const { statusId } = req.params;
    const likes = await statusService.getStatusLikes(statusId);
    res.json(likes);
  } catch (error) {
    res.status(500).json({ message: `Error fetching status likes: ${error}` });
  }
};

export const checkStatusLike = async (req: Request, res: Response) => {
  try {
    const { statusId } = req.params;

    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const hasLiked = await statusService.hasUserLikedStatus(
      statusId,
      req.user.id,
    );
    res.json({ hasLiked });
  } catch (error) {
    res.status(500).json({ message: `Error checking status like: ${error}` });
  }
};

export const getMyStatusWithLikes = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const status = await statusService.getUserStatusWithLikes(req.user.id);
    res.json(status);
  } catch (error) {
    res
      .status(500)
      .json({ message: `Error fetching your status with likes: ${error}` });
  }
};

export const getMyLikedStatus = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const likedStatus = await statusService.getStatusLikedByUser(req.user.id);
    res.json(likedStatus);
  } catch (error) {
    res
      .status(500)
      .json({ message: `Error fetching your liked status: ${error}` });
  }
};

export const getStatusLikeCount = async (req: Request, res: Response) => {
  try {
    const { statusId } = req.params;
    const count = await statusService.getStatusLikeCount(statusId);
    res.json({ statusId, likeCount: count });
  } catch (error) {
    res
      .status(500)
      .json({ message: `Error fetching status like count: ${error}` });
  }
};
