import express from 'express';
import { streamImage, getImageBase64, getImageBase64WithMeta } from '../controllers/image.controller';
import { authMiddleware } from '../middlewares/auth.middleware';

const router = express.Router();

/**
 * Stream image directly from S3 (recommended - best performance)
 * GET /api/images/stream/profile/userId/filename.jpg
 */
router.get('/stream/:key(*)', authMiddleware, streamImage);

/**
 * Get image as base64 string in JSON
 * GET /api/images/base64/profile/userId/filename.jpg
 */
router.get('/base64/:key(*)', authMiddleware, getImageBase64);

/**
 * Get image as base64 with metadata (contentType, size)
 * GET /api/images/base64-meta/profile/userId/filename.jpg
 */
router.get('/base64-meta/:key(*)', authMiddleware, getImageBase64WithMeta);

export default router;
