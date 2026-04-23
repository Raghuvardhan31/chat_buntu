import { spawn } from 'child_process';
import { s3, s3Config } from '../config/s3.config';
import { GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import path from 'path';
import fs from 'fs';
import os from 'os';

/**
 * Get video duration in seconds using ffprobe
 * Downloads the video from S3 to a temp file, probes it, then cleans up
 */
export const getVideoDuration = async (s3Key: string): Promise<number | null> => {
  const tempDir = os.tmpdir();
  const tempFile = path.join(tempDir, `video-probe-${Date.now()}${path.extname(s3Key)}`);

  try {
    // Download video from S3 to temp file
    await downloadS3ToFile(s3Key, tempFile);

    // Use ffprobe to get duration
    const duration = await probeVideoDuration(tempFile);
    return duration;
  } catch (error) {
    console.error('❌ Error getting video duration:', error);
    return null;
  } finally {
    // Cleanup temp file
    try {
      if (fs.existsSync(tempFile)) {
        fs.unlinkSync(tempFile);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }
};

/**
 * Generate a thumbnail from a video and upload it to S3
 * Returns the S3 key of the uploaded thumbnail
 */
export const generateVideoThumbnail = async (
  videoS3Key: string,
  userId: string
): Promise<string | null> => {
  const tempDir = os.tmpdir();
  const tempVideoFile = path.join(tempDir, `video-thumb-${Date.now()}${path.extname(videoS3Key)}`);
  const tempThumbFile = path.join(tempDir, `thumb-${Date.now()}.jpg`);

  try {
    // Download video from S3 to temp file
    await downloadS3ToFile(videoS3Key, tempVideoFile);

    // Extract thumbnail at 0.5 seconds using ffmpeg
    await extractThumbnail(tempVideoFile, tempThumbFile);

    // Upload thumbnail to S3
    const thumbKey = `stories/${userId}/thumb-${Date.now()}.jpg`;
    await uploadFileToS3(tempThumbFile, thumbKey, 'image/jpeg');

    return thumbKey;
  } catch (error) {
    console.error('❌ Error generating video thumbnail:', error);
    return null;
  } finally {
    // Cleanup temp files
    try {
      if (fs.existsSync(tempVideoFile)) fs.unlinkSync(tempVideoFile);
      if (fs.existsSync(tempThumbFile)) fs.unlinkSync(tempThumbFile);
    } catch (e) {
      // Ignore cleanup errors
    }
  }
};

/**
 * Process a video story: extract duration and generate thumbnail in one pass
 * More efficient than calling getVideoDuration and generateVideoThumbnail separately
 */
export const processVideoStory = async (
  videoS3Key: string,
  userId: string
): Promise<{ thumbnailKey: string | null; videoDuration: number | null }> => {
  const tempDir = os.tmpdir();
  const tempVideoFile = path.join(tempDir, `video-story-${Date.now()}${path.extname(videoS3Key)}`);
  const tempThumbFile = path.join(tempDir, `story-thumb-${Date.now()}.jpg`);

  let thumbnailKey: string | null = null;
  let videoDuration: number | null = null;

  try {
    // Download video from S3 to temp file (only once)
    await downloadS3ToFile(videoS3Key, tempVideoFile);

    // Get duration
    try {
      videoDuration = await probeVideoDuration(tempVideoFile);
    } catch (e) {
      console.error('⚠️ Could not extract video duration:', e);
    }

    // Generate thumbnail
    try {
      await extractThumbnail(tempVideoFile, tempThumbFile);
      thumbnailKey = `stories/${userId}/thumb-${Date.now()}.jpg`;
      await uploadFileToS3(tempThumbFile, thumbnailKey, 'image/jpeg');
    } catch (e) {
      console.error('⚠️ Could not generate video thumbnail:', e);
    }
  } catch (error) {
    console.error('❌ Error processing video story:', error);
  } finally {
    // Cleanup temp files
    try {
      if (fs.existsSync(tempVideoFile)) fs.unlinkSync(tempVideoFile);
      if (fs.existsSync(tempThumbFile)) fs.unlinkSync(tempThumbFile);
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  return { thumbnailKey, videoDuration };
};

// ==========================================
// Internal helper functions
// ==========================================

/**
 * Download an S3 object to a local file
 */
async function downloadS3ToFile(s3Key: string, filePath: string): Promise<void> {
  const command = new GetObjectCommand({
    Bucket: s3Config.bucketName,
    Key: s3Key,
  });

  const response = await s3.send(command);
  const body = response.Body as any;

  return new Promise((resolve, reject) => {
    const writeStream = fs.createWriteStream(filePath);
    if (body.pipe && typeof body.pipe === 'function') {
      body.pipe(writeStream);
      writeStream.on('finish', resolve);
      writeStream.on('error', reject);
    } else if (body[Symbol.asyncIterator]) {
      (async () => {
        try {
          for await (const chunk of body) {
            writeStream.write(chunk);
          }
          writeStream.end();
          writeStream.on('finish', resolve);
        } catch (err) {
          reject(err);
        }
      })();
    } else {
      reject(new Error('Unsupported S3 body stream type'));
    }
  });
}

/**
 * Upload a local file to S3
 */
async function uploadFileToS3(filePath: string, s3Key: string, contentType: string): Promise<void> {
  const fileBuffer = fs.readFileSync(filePath);

  const command = new PutObjectCommand({
    Bucket: s3Config.bucketName,
    Key: s3Key,
    Body: fileBuffer,
    ContentType: contentType,
  });

  await s3.send(command);
}

/**
 * Use ffprobe to get video duration in seconds
 */
function probeVideoDuration(filePath: string): Promise<number> {
  return new Promise((resolve, reject) => {
    const ffprobe = spawn('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      filePath,
    ]);

    let output = '';
    let errorOutput = '';

    ffprobe.stdout.on('data', (data) => {
      output += data.toString();
    });

    ffprobe.stderr.on('data', (data) => {
      errorOutput += data.toString();
    });

    ffprobe.on('close', (code) => {
      if (code === 0) {
        const duration = parseFloat(output.trim());
        if (!isNaN(duration)) {
          resolve(Math.round(duration * 10) / 10); // Round to 1 decimal
        } else {
          reject(new Error(`Could not parse duration from ffprobe output: ${output}`));
        }
      } else {
        reject(new Error(`ffprobe exited with code ${code}: ${errorOutput}`));
      }
    });

    ffprobe.on('error', (err) => {
      reject(new Error(`ffprobe not found. Please install ffmpeg. Error: ${err.message}`));
    });
  });
}

/**
 * Use ffmpeg to extract a thumbnail from a video
 * Takes a frame at 0.5 seconds (or first frame if video is shorter)
 */
function extractThumbnail(videoPath: string, outputPath: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const ffmpeg = spawn('ffmpeg', [
      '-y',                    // Overwrite output
      '-i', videoPath,         // Input file
      '-ss', '00:00:00.500',   // Seek to 0.5 seconds
      '-vframes', '1',         // Extract 1 frame
      '-vf', 'scale=480:-2',   // Scale to 480px width, maintain aspect ratio
      '-q:v', '3',             // JPEG quality (2-5 is good, lower = better)
      outputPath,
    ]);

    let errorOutput = '';

    ffmpeg.stderr.on('data', (data) => {
      errorOutput += data.toString();
    });

    ffmpeg.on('close', (code) => {
      if (code === 0 && fs.existsSync(outputPath)) {
        resolve();
      } else {
        reject(new Error(`ffmpeg thumbnail extraction failed (code ${code}): ${errorOutput.slice(-200)}`));
      }
    });

    ffmpeg.on('error', (err) => {
      reject(new Error(`ffmpeg not found. Please install ffmpeg. Error: ${err.message}`));
    });
  });
}
