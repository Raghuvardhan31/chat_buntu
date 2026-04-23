import { Router } from 'express';

import ChatController from '../controllers/chat.controller';
import { authenticateToken } from '../middleware/auth';
import multer from 'multer';
import { uploadFileController, getFileController } from "../controllers/chat.controller";
import { chatFileUpload } from '../middlewares/upload.middleware';
import { authMiddleware } from "../middlewares/auth.middleware"


const router = Router();

export default function setupChatRoutes(chatController: ChatController) {
  // Get chat history between two users
  router.get('/history/:userId/:otherUserId', authenticateToken, chatController.getChatHistory.bind(chatController));

  //Here file is both image and pdf, and optionally thumbnail for videos
  router.post("/upload-file", authMiddleware, chatFileUpload.fields([{ name: 'file', maxCount: 1 }, { name: 'thumbnail', maxCount: 1 }]), uploadFileController);
  router.get("/file/:key(*)", authMiddleware, getFileController);
  return router;
}
