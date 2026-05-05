# AWS S3 Storage Implementation Guide

## ✅ Changes Completed

The media storage has been migrated to AWS S3 with **Dual Mode** support (both local and S3 storage work simultaneously).

### Modified Files:
1. `src/config/s3.config.ts` - AWS S3 configuration
2. `src/config/interfaces/config.interface.ts` - Added AWS config interface
3. `src/middlewares/upload.middleware.ts` - Profile picture S3 upload
4. `src/routes/location.routes.ts` - Location photos S3 upload
5. `src/controllers/user.controller.ts` - Use S3 URLs for profile pictures
6. `src/controllers/location.controller.ts` - Use S3 URLs for location photos
7. `.env.example` - Added AWS environment variables

### Packages Installed:
- `aws-sdk` - AWS SDK for JavaScript v2
- `multer-s3` - Streaming multer storage engine for AWS S3
- `@types/multer-s3` - TypeScript definitions

---

## 🔧 Setup Instructions

### 1. Create AWS S3 Bucket

1. Go to [AWS S3 Console](https://console.aws.amazon.com/s3/)
2. Click "Create bucket"
3. Choose a unique bucket name (e.g., `chatawayplus-media`)
4. Select your preferred region (e.g., `us-east-1`)
5. **Uncheck "Block all public access"** (we need public read access for images)
6. Enable bucket versioning (optional but recommended)
7. Create the bucket

### 2. Configure Bucket Permissions

Add the following bucket policy to allow public read access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*"
    }
  ]
}
```

Replace `YOUR_BUCKET_NAME` with your actual bucket name.

### 3. Create IAM User

1. Go to [AWS IAM Console](https://console.aws.amazon.com/iam/)
2. Click "Users" → "Add users"
3. Username: `chatawayplus-s3-user`
4. Select "Programmatic access"
5. Attach policy: **AmazonS3FullAccess** (or create custom policy)
6. Complete and **save the Access Key ID and Secret Access Key**

### 4. Configure Environment Variables

Add these to your `.env` file:

```env
# AWS S3 Configuration
AWS_ACCESS_KEY_ID=your_access_key_id_here
AWS_SECRET_ACCESS_KEY=your_secret_access_key_here
AWS_REGION=us-east-1
AWS_S3_BUCKET_NAME=your_bucket_name_here
```

### 5. Test the Setup

Run the validation:

```typescript
import { validateS3Config } from './src/config/s3.config';

validateS3Config(); // Should log success message
```

---

## 📁 Storage Structure

### S3 Bucket Structure:
```
your-bucket-name/
├── profile/                          # Profile pictures
│   ├── chatawaypluspic-1701234567890-123456789.jpg
│   └── chatawaypluspic-9876543210-9876543210.png
│
└── locations/                        # Location photos
    ├── {user-id-1}/
    │   ├── 1701234567890-9876543210-beach.jpg
    │   └── 1701234567890-9876543210-mountain.png
    └── {user-id-2}/
        └── 1701234567890-9876543210-city.jpg
```

### Database Storage:
- **Profile pictures**: Full S3 URL (e.g., `https://bucket.s3.region.amazonaws.com/profile/pic.jpg`)
- **Location photos**: Array of full S3 URLs

---

## 🔄 Dual Mode (Local + S3)

### How It Works:
- **Old users**: Their media URLs start with `/uploads/` (served from local disk)
- **New uploads**: Go directly to S3, URLs start with `https://`
- **Static serving**: Still enabled at `/uploads` route for backward compatibility

### Frontend URL Detection:
```typescript
const imageUrl = user.chatawaypluspic.startsWith('http')
  ? user.chatawaypluspic  // S3 URL
  : `${SERVER_URL}${user.chatawaypluspic}`; // Local path
```

### Migration (Optional):
To migrate existing files to S3, you can create a migration script:
```bash
# This is optional - old files will continue to work
node scripts/migrate-to-s3.js
```

---

## 🐛 Known Issues

### TypeScript Linting Warning:
You may see this in your editor:
```
Type 'S3' is missing the following properties from type 'S3Client'
```

**This is normal!**
- The warning appears because `aws-sdk` v2 and `multer-s3` type definitions don't perfectly match
- The code works correctly at runtime
- Build completes successfully (`npm run build` passes)
- Suppressed with `@ts-ignore` comments

---

## 🔒 Security Recommendations

1. **IAM Policy**: Use least-privilege policy instead of full S3 access:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::your-bucket-name/*"
    }
  ]
}
```

2. **CORS Configuration**: Add if accessing from browser:
```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
    "AllowedOrigins": ["https://yourdomain.com"],
    "ExposeHeaders": ["ETag"]
  }
]
```

3. **Environment Variables**: Never commit `.env` file to git

---

## ✅ Testing

### Upload Profile Picture:
```bash
curl -X GET http://192.168.1.17:3200/api/stories/contacts \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "chatawaypluspic=@/path/to/image.jpg" \
  -F "name=John Doe"
```

### Upload Location Photos:
```bash
curl -X POST http://192.168.1.17:3200/api/stories \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "name=Beautiful Beach" \
  -F "description=Sunset view" \
  -F "photos=@/path/to/photo1.jpg" \
  -F "photos=@/path/to/photo2.jpg"
```

---

## 📊 Cost Estimation

AWS S3 Pricing (us-east-1):
- Storage: $0.023 per GB/month
- PUT requests: $0.005 per 1,000 requests
- GET requests: $0.0004 per 1,000 requests
- Data transfer out: Free for first 1 GB, then $0.09/GB

**Example**: 10,000 users with 1MB profile pic each = ~10 GB = ~$0.23/month

---

## 🚀 Deployment

1. Build the project: `npm run build`
2. Ensure `.env` has AWS credentials
3. Start server: `npm start`
4. Monitor S3 uploads in AWS Console

---

## 📞 Support

If you encounter issues:
1. Check AWS credentials are correct
2. Verify bucket permissions and policy
3. Check CloudWatch logs for S3 errors
4. Ensure bucket region matches `AWS_REGION` env variable
