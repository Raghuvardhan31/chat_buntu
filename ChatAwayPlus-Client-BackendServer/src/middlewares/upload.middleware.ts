import multer from 'multer';
import path from 'path';
import fs from 'fs';
import multerS3 from 'multer-s3';
import { Request } from 'express';
import { s3, s3Config, isS3Configured } from '../config/s3.config';
// Import auth middleware to ensure the Request type augmentation is loaded
import '../middlewares/auth.middleware';

// ==========================================
// DIRECTORY HELPERS
// ==========================================
const ensureDir = (dirPath: string) => {
  const absolutePath = path.isAbsolute(dirPath) ? dirPath : path.join(__dirname, '../../', dirPath);
  if (!fs.existsSync(absolutePath)) {
    fs.mkdirSync(absolutePath, { recursive: true });
    console.log(`📁 Created directory: ${absolutePath}`);
  }
  return absolutePath;
};

// ==========================================
// STORAGE CONFIGURATION (S3 vs DISK)
// ==========================================

const getStorage = (subDir: string) => {
  if (isS3Configured) {
    console.log(`☁️ Using S3 storage for ${subDir}`);
    return multerS3({
      s3: s3,
      bucket: s3Config.bucketName,
      metadata: (req: any, file, cb) => {
        cb(null, { fieldName: file.fieldname });
      },
      key: (req: any, file, cb) => {
        const userId = req.user?.id;
        if (!userId) return cb(new Error('Unauthorized'));
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const filename = file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname);
        cb(null, `${subDir}/${userId}/${filename}`);
      }
    });
  } else {
    console.log(`💾 Using Local Disk storage for ${subDir}`);
    return multer.diskStorage({
      destination: (req, file, cb) => {
        const userId = (req as any).user?.id || 'unknown';
        const dir = ensureDir(`uploads/${subDir}/${userId}`);
        cb(null, dir);
      },
      filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, `${file.fieldname}-${uniqueSuffix}${path.extname(file.originalname)}`);
      }
    });
  }
};

// Default profile upload instance
const upload = multer({
  storage: getStorage('profile'),
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Not an image! Please upload an image.'));
    }
  }
});

// Location photos upload instance
const locationUpload = multer({
  storage: getStorage('locations'),
  limits: {
    fileSize: 20 * 1024 * 1024,
    files: 10
  },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  }
});

// Middleware wrapper to handle errors
export const uploadProfile = (req: any, res: any, next: any) => {
  upload.single('chat_picture')(req, res, (err: any) => {
    if (err instanceof multer.MulterError) {
      return res.status(400).json({
        success: false,
        message: `Upload error: ${err.message}`
      });
    } else if (err) {
      return res.status(400).json({
        success: false,
        message: err.message
      });
    }
    next();
  });
};

// Chat images and pdf
export const chatFileUpload = multer({
  storage: getStorage('chat'),
  limits: { fileSize: 60 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const isImage = file.mimetype.startsWith('image/');
    const isVideo = file.mimetype.startsWith('video/');
    const isAudio = file.mimetype.startsWith('audio/');
    const isPdf =
      file.mimetype === 'application/pdf' ||
      (file.mimetype === 'application/octet-stream' && ext === '.pdf');

    if (isImage || isPdf || isVideo || isAudio) {
      cb(null, true);
    } else {
      cb(new Error('Only images, PDFs, videos, and audio files are allowed'));
    }
  }
});

// Export location photo uploader
export const uploadLocationPhotos = locationUpload;

// Create multer upload instance for stories
export const storyUpload = multer({
  storage: getStorage('stories'),
  limits: {
    fileSize: 100 * 1024 * 1024,
  },
  fileFilter: (_req, file, cb) => {
    const isImage = file.mimetype.startsWith('image/');
    const isVideo = file.mimetype.startsWith('video/');

    if (isImage || isVideo) {
      cb(null, true);
    } else {
      cb(new Error('Only image and video files are allowed for stories'));
    }
  }
});
