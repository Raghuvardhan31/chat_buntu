import { Op } from 'sequelize';
import Story from '../db/models/story.model';
import StoryView from '../db/models/story-view.model';
import User from '../db/models/user.model';
import Contact from '../db/models/contact.model';
import BlockedUser from '../db/models/blocked-user.model';

/**
 * Create a new story
 */
export const createStory = async (
  userId: string,
  mediaUrl: string,
  mediaType: 'image' | 'video',
  caption?: string,
  duration: number = 5,
  backgroundColor?: string,
  expiresInHours: number = 24,
  thumbnailUrl?: string | null,
  videoDuration?: number | null,
) => {
  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + expiresInHours);

  const story = await Story.create({
    userId,
    mediaUrl,
    mediaType,
    caption: caption || null,
    duration,
    expiresAt,
    backgroundColor: backgroundColor || null,
    thumbnailUrl: thumbnailUrl || null,
    videoDuration: videoDuration || null,
    viewsCount: 0,
  });

  return story;
};

/**
 * Get stories from user's contacts (only non-expired stories)
 * Groups stories by user
 */
export const getContactsStories = async (userId: string) => {
  const contacts = await Contact.findAll({
    where: { userId },
    attributes: ['contactUserId'],
  });

  const contactUserIds = contacts.map((c) => c.contactUserId);

  if (contactUserIds.length === 0) {
    return [];
  }

  // Get users who have blocked the current user
  const blockedByUsers = await BlockedUser.findAll({
    where: {
      blockedId: userId, // Current user is blocked
    },
    attributes: ['blockerId'],
  });

  const blockerIds = blockedByUsers.map((b) => b.blockerId);

  // Filter out contact IDs of users who have blocked the current user
  const visibleContactUserIds = contactUserIds.filter(
    (contactId) => !blockerIds.includes(contactId)
  );

  if (visibleContactUserIds.length === 0) {
    return [];
  }

  const stories = await Story.findAll({
    where: {
      userId: {
        [Op.in]: visibleContactUserIds,
      },
      expiresAt: {
        [Op.gt]: new Date(),
      },
    },
    include: [
      {
        model: User,
        as: 'user',
        attributes: ['id', 'firstName', 'lastName', 'chat_picture', 'mobileNo'],
      },
      {
        model: StoryView,
        as: 'views',
        where: { viewerId: userId },
        required: false,
        attributes: ['id', 'viewedAt'],
      },
    ],
    order: [['createdAt', 'DESC']],
  });

  const groupedStories = stories.reduce((acc: any, story: any) => {
    const storyUserId = story.userId;
    if (!acc[storyUserId]) {
      acc[storyUserId] = {
        user: story.user,
        stories: [],
        hasUnviewed: false,
      };
    }

    const isViewed = story.views && story.views.length > 0;
    if (!isViewed) {
      acc[storyUserId].hasUnviewed = true;
    }

    acc[storyUserId].stories.push({
      id: story.id,
      mediaUrl: story.mediaUrl,
      mediaType: story.mediaType,
      thumbnailUrl: story.thumbnailUrl,
      videoDuration: story.videoDuration,
      caption: story.caption,
      duration: story.duration,
      viewsCount: story.viewsCount,
      expiresAt: story.expiresAt,
      backgroundColor: story.backgroundColor,
      createdAt: story.createdAt,
      isViewed,
    });

    return acc;
  }, {});

  return Object.values(groupedStories);
};

/**
 * Get all stories for a specific user (non-expired)
 */
export const getUserStories = async (userId: string, viewerId?: string) => {
  // Check if the story owner (userId) has blocked the viewer
  if (viewerId) {
    const isBlocked = await BlockedUser.findOne({
      where: {
        blockerId: userId, // Story owner
        blockedId: viewerId, // Viewer
      },
    });

    // If viewer is blocked by story owner, return empty array
    if (isBlocked) {
      return [];
    }
  }

  const stories = await Story.findAll({
    where: {
      userId,
      expiresAt: {
        [Op.gt]: new Date(),
      },
    },
    include: [
      {
        model: User,
        as: 'user',
        attributes: ['id', 'firstName', 'lastName', 'chat_picture', 'mobileNo'],
      },
      ...(viewerId
        ? [
          {
            model: StoryView,
            as: 'views',
            where: { viewerId },
            required: false,
            attributes: ['id', 'viewedAt'],
          },
        ]
        : []),
    ],
    order: [['createdAt', 'ASC']],
  });

  return stories.map((story: any) => ({
    id: story.id,
    userId: story.userId,
    mediaUrl: story.mediaUrl,
    mediaType: story.mediaType,
    thumbnailUrl: story.thumbnailUrl,
    videoDuration: story.videoDuration,
    caption: story.caption,
    duration: story.duration,
    viewsCount: story.viewsCount,
    expiresAt: story.expiresAt,
    backgroundColor: story.backgroundColor,
    createdAt: story.createdAt,
    user: story.user,
    isViewed: viewerId && story.views && story.views.length > 0,
  }));
};

/**
 * Get a single story by ID
 */
export const getStoryById = async (storyId: string, viewerId?: string) => {
  const story = await Story.findOne({
    where: {
      id: storyId,
      expiresAt: {
        [Op.gt]: new Date(),
      },
    },
    include: [
      {
        model: User,
        as: 'user',
        attributes: ['id', 'firstName', 'lastName', 'chat_picture', 'mobileNo'],
      },
      ...(viewerId
        ? [
          {
            model: StoryView,
            as: 'views',
            where: { viewerId },
            required: false,
            attributes: ['id', 'viewedAt'],
          },
        ]
        : []),
    ],
  });

  if (!story) {
    return null;
  }

  return {
    id: story.id,
    userId: story.userId,
    mediaUrl: story.mediaUrl,
    mediaType: story.mediaType,
    thumbnailUrl: story.thumbnailUrl,
    videoDuration: story.videoDuration,
    caption: story.caption,
    duration: story.duration,
    viewsCount: story.viewsCount,
    expiresAt: story.expiresAt,
    backgroundColor: story.backgroundColor,
    createdAt: story.createdAt,
    user: (story as any).user,
    isViewed: viewerId && (story as any).views && (story as any).views.length > 0,
  };
};

/**
 * Delete a story (only by owner)
 */
export const deleteStory = async (storyId: string, userId: string) => {
  const story = await Story.findOne({
    where: { id: storyId, userId },
  });

  if (!story) {
    return { success: false, message: 'Story not found or unauthorized' };
  }

  await story.destroy();
  return { success: true, message: 'Story deleted successfully' };
};

/**
 * Mark story as viewed
 */
export const markStoryAsViewed = async (storyId: string, viewerId: string) => {
  const story = await Story.findByPk(storyId);

  if (!story) {
    return { success: false, message: 'Story not found' };
  }

  if (new Date() > story.expiresAt) {
    return { success: false, message: 'Story has expired' };
  }

  const [storyView, created] = await StoryView.findOrCreate({
    where: { storyId, viewerId },
    defaults: { storyId, viewerId, viewedAt: new Date() },
  });

  if (created) {
    await story.increment('viewsCount');
  }

  return {
    success: true,
    message: created ? 'Story view recorded' : 'Already viewed',
    isNewView: created,
  };
};

/**
 * Get list of viewers for a story (only for story owner)
 */
export const getStoryViewers = async (storyId: string, requesterId: string) => {
  const story = await Story.findByPk(storyId);

  if (!story) {
    return { success: false, message: 'Story not found', viewers: [] };
  }

  if (story.userId !== requesterId) {
    return { success: false, message: 'Unauthorized', viewers: [] };
  }

  const views = await StoryView.findAll({
    where: { storyId },
    include: [
      {
        model: User,
        as: 'viewer',
        attributes: ['id', 'firstName', 'lastName', 'chat_picture', 'mobileNo'],
      },
    ],
    order: [['viewedAt', 'DESC']],
  });

  const viewers = views.map((view: any) => ({
    id: view.id,
    viewedAt: view.viewedAt,
    viewer: view.viewer,
  }));

  return { success: true, viewers, totalViews: story.viewsCount };
};

/**
 * Cleanup expired stories (for cron job)
 */
export const cleanupExpiredStories = async () => {
  const deletedCount = await Story.destroy({
    where: {
      expiresAt: {
        [Op.lt]: new Date(),
      },
    },
    force: true,
  });

  console.log(`🧹 Cleaned up ${deletedCount} expired stories`);
  return deletedCount;
};

/**
 * Get user's own stories with viewer details
 */
export const getMyStories = async (userId: string) => {
  const stories = await Story.findAll({
    where: {
      userId,
      expiresAt: {
        [Op.gt]: new Date(),
      },
    },
    include: [
      {
        model: StoryView,
        as: 'views',
        include: [
          {
            model: User,
            as: 'viewer',
            attributes: ['id', 'firstName', 'lastName', 'chat_picture'],
          },
        ],
      },
    ],
    order: [['createdAt', 'DESC']],
  });

  return stories;
};
