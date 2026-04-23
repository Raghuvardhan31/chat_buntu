import { Router } from 'express';
import * as storyController from '../controllers/story.controller';
import { authMiddleware } from '../middlewares/auth.middleware';
import { storyUpload } from '../middlewares/upload.middleware';

const router = Router();

// Upload story media to S3 (pre-upload before creating story - useful for videos)
// Accepts 'media' (required) and 'thumbnail' (optional) files
router.post('/upload', authMiddleware, storyUpload.fields([{ name: 'media', maxCount: 1 }, { name: 'thumbnail', maxCount: 1 }]), storyController.uploadStoryMedia);

// Create story - supports both file upload and mediaUrl
// Accepts 'media' (required) and 'thumbnail' (optional) files
router.post('/', authMiddleware, storyUpload.fields([{ name: 'media', maxCount: 1 }, { name: 'thumbnail', maxCount: 1 }]), storyController.createStory);

router.get('/contacts', authMiddleware, storyController.getContactsStories);

router.get('/my', authMiddleware, storyController.getMyStories);

router.get('/user/:userId', authMiddleware, storyController.getUserStories);

router.get('/:storyId', authMiddleware, storyController.getStory);

router.delete('/:storyId', authMiddleware, storyController.deleteStory);

router.post('/:storyId/view', authMiddleware, storyController.markStoryAsViewed);

router.get('/:storyId/viewers', authMiddleware, storyController.getStoryViewers);

export default router;
