import { S3Client } from '@aws-sdk/client-s3';
import dotenv from 'dotenv';

dotenv.config();

// Create S3 client (AWS SDK v3)
export const s3 = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || '',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || '',
  },
});

// S3 configuration constants
export const s3Config = {
  bucketName: process.env.AWS_S3_BUCKET_NAME || '',
  region: process.env.AWS_REGION || 'us-east-1',
  acl: 'public-read' as const,
};

// Validate S3 configuration
export const validateS3Config = (): boolean => {
  if (!process.env.AWS_ACCESS_KEY_ID) {
    console.warn('⚠️  AWS_ACCESS_KEY_ID is not set');
    return false;
  }
  if (!process.env.AWS_SECRET_ACCESS_KEY) {
    console.warn('⚠️  AWS_SECRET_ACCESS_KEY is not set');
    return false;
  }
  if (!process.env.AWS_S3_BUCKET_NAME) {
    console.warn('⚠️  AWS_S3_BUCKET_NAME is not set');
    return false;
  }
  console.log('✅ S3 configuration validated successfully');
  return true;
};

// Explicit flag for other modules to check if S3 is usable
export const isS3Configured = process.env.AWS_ACCESS_KEY_ID && 
                             process.env.AWS_ACCESS_KEY_ID !== 'dummy' && 
                             process.env.AWS_S3_BUCKET_NAME !== 'dummy';

export default s3;
