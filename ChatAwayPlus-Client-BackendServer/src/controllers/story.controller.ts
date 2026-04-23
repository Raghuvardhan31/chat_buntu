import { Request, Response } from 'express';
import * as storyService from '../services/story.service';
import { chatController } from '../index';
import { processVideoStory } from '../utils/video.util';
import { formatMediaUrl } from '../utils/storage.util';

/**
 * Extract S3 key from either a full S3 URL or an API streaming URL
 * Input: https://bucket.s3.region.amazonaws.com/stories/userId/file.mp4
 *   OR: /api/images/stream/stories/userId/file.mp4
 * Output: stories/userId/file.mp4
 */
const extractS3Key = (url: string): string | null => {
  try {
    if (url.includes('.amazonaws.com/')) {
      const parts = url.split('.amazonaws.com/');
      return parts[1] || null;
    }
    if (url.startsWith('/api/images/stream/')) {
      return url.replace('/api/images/stream/', '');
    }
    return null;
  } catch (error) {
    return null;
  }
};

/**
 * Upload story media to S3
 * POST /api/stories/upload
 */
export const uploadStoryMedia = async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    // Handle both single file upload and multiple files (media + thumbnail)
    const files = req.files as { [fieldname: string]: Express.Multer.File[] };
    const file = req.file || (files?.media?.[0]);
    const thumbnailFile = files?.thumbnail?.[0];

    // Check if media file was uploaded
    if (!file) {
      return res.status(400).json({ success: false, message: 'No media file provided' });
    }

    // Extract file info
    const mediaFileInfo = file as any;
    const mediaType = mediaFileInfo.mimetype.startsWith('image/') ? 'image' : 'video';

    // Format storage location to API streaming URL
    const mediaUrl = formatMediaUrl(mediaFileInfo);

    let thumbnailUrl: string | null = null;
    let videoDuration: number | null = null;

    // Check if client provided thumbnail
    if (thumbnailFile) {
      // Use client-provided thumbnail
      thumbnailUrl = formatMediaUrl(thumbnailFile);
      console.log('✓ Using client-provided thumbnail');
    } else if (mediaType === 'video' && mediaFileInfo.location) {
      // Only generate thumbnail if using S3 (local processing requires ffmpeg Setup)
      try {
        const videoResult = await processVideoStory(mediaFileInfo.key, userId);
        videoDuration = videoResult.videoDuration;
        if (videoResult.thumbnailKey) {
          thumbnailUrl = `/api/images/stream/${videoResult.thumbnailKey}`;
        }
      } catch (err) {
        console.error('⚠️ Video processing failed (upload will continue):', err);
      }
    }

    res.status(200).json({
      success: true,
      message: 'Media uploaded successfully',
      data: {
        mediaUrl,
        mediaType,
        thumbnailUrl,
        videoDuration,
        size: mediaFileInfo.size,
        key: mediaFileInfo.key || mediaFileInfo.path // Use key for S3, path for Local
      }
    });
  } catch (error) {
    console.error('Error uploading story media:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to upload media',
      error: (error as Error).message,
    });
  }
};

/**
 * Create a new story
 * POST /api/stories
 * Supports both:
 * 1. File upload (multipart/form-data with 'media' field)
 * 2. Pre-uploaded URL (application/json with 'mediaUrl' field)
 */
export const createStory = async (req: Request, res: Response) => {
  try {
    let { mediaUrl, mediaType, caption, duration, backgroundColor, thumbnailUrl, videoDuration } = req.body;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    // Handle both single file upload and multiple files (media + thumbnail)
    const files = req.files as { [fieldname: string]: Express.Multer.File[] };
    const file = req.file || (files?.media?.[0]);
    const thumbnailFile = files?.thumbnail?.[0];

    // Check if file was uploaded directly via multipart/form-data
    if (file) {
      const mediaFileInfo = file as any;
      mediaUrl = formatMediaUrl(mediaFileInfo);
      mediaType = mediaFileInfo.mimetype.startsWith('image/') ? 'image' : 'video';

      // Check if client provided thumbnail
      if (thumbnailFile) {
        thumbnailUrl = formatMediaUrl(thumbnailFile);
        console.log('✓ Using client-provided thumbnail');
      } else if (mediaType === 'video' && mediaFileInfo.location) {
        // Only generate thumbnail for S3 videos
        try {
          const videoResult = await processVideoStory(mediaFileInfo.key, userId);
          videoDuration = videoResult.videoDuration;
          if (videoResult.thumbnailKey) {
            thumbnailUrl = `/api/images/stream/${videoResult.thumbnailKey}`;
          }
        } catch (err) {
          console.error('⚠️ Video processing failed (story will continue without thumbnail):', err);
        }
      }
    }

    // Validate mediaUrl exists (either from upload or body)
    if (!mediaUrl) {
      return res.status(400).json({
        success: false,
        message: 'Media is required. Either upload a file or provide mediaUrl'
      });
    }

    // Validate mediaType
    if (!mediaType || !['image', 'video'].includes(mediaType)) {
      return res.status(400).json({ success: false, message: 'Invalid media type' });
    }

    // Ensure mediaUrl is correctly formatted (if provided as string in JSON)
    if (typeof mediaUrl === 'string' && (mediaUrl.includes('.amazonaws.com/') || mediaUrl.includes('uploads/'))) {
      mediaUrl = formatMediaUrl({ location: mediaUrl.includes('.amazonaws.com/') ? mediaUrl : undefined, path: mediaUrl.includes('uploads/') ? mediaUrl : undefined });
    }
    
    const formattedMediaUrl = mediaUrl;

    // For video stories sent with pre-uploaded URL, process if not already done
    if (mediaType === 'video' && !thumbnailUrl) {
      const s3Key = extractS3Key(mediaUrl);
      if (s3Key) {
        try {
          const videoResult = await processVideoStory(s3Key, userId);
          videoDuration = videoResult.videoDuration || videoDuration;
          if (videoResult.thumbnailKey) {
            thumbnailUrl = `/api/images/stream/${videoResult.thumbnailKey}`;
          }
        } catch (err) {
          console.error('⚠️ Video processing failed for pre-uploaded URL:', err);
        }
      }
    }

    // For video stories, use actual video duration as display duration if available
    const displayDuration = mediaType === 'video' && videoDuration
      ? Math.ceil(videoDuration)
      : (duration || 5);

    const story = await storyService.createStory(
      userId,
      formattedMediaUrl,
      mediaType,
      caption,
      displayDuration,
      backgroundColor,
      24,
      thumbnailUrl || null,
      videoDuration || null,
    );

    await chatController.notifyContactsAboutNewStory(userId, {
      storyId: story.id,
      mediaUrl: story.mediaUrl,
      mediaType: story.mediaType,
      thumbnailUrl: story.thumbnailUrl,
      videoDuration: story.videoDuration,
      createdAt: story.createdAt,
    });

    res.status(201).json({
      success: true,
      message: 'Story created successfully',
      story,
    });
  } catch (error) {
    console.error('Error creating story:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create story',
      error: (error as Error).message,
    });
  }
};

/**
 * Get stories from all contacts
 * GET /api/stories/contacts
 */
export const getContactsStories = async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const stories = await storyService.getContactsStories(userId);

    res.json({
      success: true,
      stories,
    });
  } catch (error) {
    console.error('Error fetching contacts stories:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch stories',
      error: (error as Error).message,
    });
  }
};

/**
 * Get stories for a specific user
 * GET /api/stories/user/:userId
 */
export const getUserStories = async (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const viewerId = req.user?.id;

    if (!viewerId) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const stories = await storyService.getUserStories(userId, viewerId);

    res.json({
      success: true,
      stories,
    });
  } catch (error) {
    console.error('Error fetching user stories:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch user stories',
      error: (error as Error).message,
    });
  }
};

/**
 * Get a single story by ID
 * GET /api/stories/:storyId
 */
export const getStory = async (req: Request, res: Response) => {
  try {
    const { storyId } = req.params;
    const viewerId = req.user?.id;

    if (!viewerId) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const story = await storyService.getStoryById(storyId, viewerId);

    if (!story) {
      return res.status(404).json({
        success: false,
        message: 'Story not found or expired',
      });
    }

    res.json({
      success: true,
      story,
    });
  } catch (error) {
    console.error('Error fetching story:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch story',
      error: (error as Error).message,
    });
  }
};

/**
 * Delete a story
 * DELETE /api/stories/:storyId
 */
export const deleteStory = async (req: Request, res: Response) => {
  try {
    const { storyId } = req.params;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const result = await storyService.deleteStory(storyId, userId);

    if (!result.success) {
      return res.status(404).json(result);
    }

    await chatController.notifyContactsAboutDeletedStory(userId, storyId);

    res.json(result);
  } catch (error) {
    console.error('Error deleting story:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete story',
      error: (error as Error).message,
    });
  }
};

/**
 * Mark story as viewed
 * POST /api/stories/:storyId/view
 */
export const markStoryAsViewed = async (req: Request, res: Response) => {
  try {
    const { storyId } = req.params;
    const viewerId = req.user?.id;

    if (!viewerId) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const result = await storyService.markStoryAsViewed(storyId, viewerId);

    if (!result.success) {
      return res.status(400).json(result);
    }

    if (result.isNewView) {
      await chatController.notifyStoryOwnerAboutView(storyId, viewerId);
    }

    res.json(result);
  } catch (error) {
    console.error('Error marking story as viewed:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to mark story as viewed',
      error: (error as Error).message,
    });
  }
};

/**
 * Get viewers for a story (only for story owner)
 * GET /api/stories/:storyId/viewers
 */
export const getStoryViewers = async (req: Request, res: Response) => {
  try {
    const { storyId } = req.params;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const result = await storyService.getStoryViewers(storyId, userId);

    if (!result.success) {
      return res.status(result.message === 'Unauthorized' ? 403 : 404).json(result);
    }

    res.json(result);
  } catch (error) {
    console.error('Error fetching story viewers:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch story viewers',
      error: (error as Error).message,
    });
  }
};

/**
 * Get my own stories with viewer details
 * GET /api/stories/my
 */
export const getMyStories = async (req: Request, res: Response) => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const stories = await storyService.getMyStories(userId);

    res.json({
      success: true,
      stories,
    });
  } catch (error) {
    console.error('Error fetching my stories:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch stories',
      error: (error as Error).message,
    });
  }
};
