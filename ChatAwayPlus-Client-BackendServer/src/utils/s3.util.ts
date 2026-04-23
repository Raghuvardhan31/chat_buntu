import { GetObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
import { s3, s3Config } from '../config/s3.config';
import path from 'path';

/**
 * Download S3 object and return as stream (for efficient file serving)
 */
export const getS3ObjectStream = async (key: string) => {
	try {
		const command = new GetObjectCommand({
			Bucket: s3Config.bucketName,
			Key: key,
		});
		const response = await s3.send(command);
		return response.Body;
	} catch (error: any) {
		throw new Error(`Failed to download S3 object: ${error.message}`);
	}
};

export const getS3ObjectStreamWithMetaData = async (key: string) => {
	try {
		const command = new GetObjectCommand({
			Bucket: s3Config.bucketName,
			Key: key,
		});
		const response = await s3.send(command);
		return response;
	} catch (error: any) {
		throw new Error(`Failed to download S3 object: ${error.message}`);
	}
}

/**
 * Download S3 object and convert to base64
 */
export const getS3ObjectAsBase64 = async (key: string): Promise<string> => {
	try {
		const command = new GetObjectCommand({
			Bucket: s3Config.bucketName,
			Key: key,
		});
		const response = await s3.send(command);

		// Convert stream to buffer
		const chunks: Buffer[] = [];
		const body = response.Body as any;

		for await (const chunk of body) {
			chunks.push(chunk);
		}

		const buffer = Buffer.concat(chunks);
		return buffer.toString('base64');
	} catch (error: any) {
		throw new Error(`Failed to download S3 object: ${error.message}`);
	}
};

/**
 * Download S3 object and return metadata + base64
 */
export const getS3ObjectWithBase64 = async (key: string) => {
	try {
		const command = new GetObjectCommand({
			Bucket: s3Config.bucketName,
			Key: key,
		});
		const response = await s3.send(command);

		// Convert stream to buffer
		const chunks: Buffer[] = [];
		const body = response.Body as any;

		for await (const chunk of body) {
			chunks.push(chunk);
		}

		const buffer = Buffer.concat(chunks);
		const base64 = buffer.toString('base64');

		return {
			base64,
			contentType: response.ContentType || 'application/octet-stream',
			size: response.ContentLength || 0,
		};
	} catch (error: any) {
		throw new Error(`Failed to download S3 object: ${error.message}`);
	}
};

/**
 * Get S3 object metadata (HEAD request) - used for Range-based video streaming
 */
export const getS3ObjectHead = async (key: string) => {
	try {
		const command = new HeadObjectCommand({
			Bucket: s3Config.bucketName,
			Key: key,
		});
		const response = await s3.send(command);
		return {
			contentLength: response.ContentLength || 0,
			contentType: response.ContentType || 'application/octet-stream',
		};
	} catch (error: any) {
		throw new Error(`Failed to get S3 object metadata: ${error.message}`);
	}
};

/**
 * Get S3 object stream with Range header support (for video seeking/buffering)
 */
export const getS3ObjectStreamWithRange = async (key: string, range?: string) => {
	try {
		const commandParams: any = {
			Bucket: s3Config.bucketName,
			Key: key,
		};

		if (range) {
			commandParams.Range = range;
		}

		const command = new GetObjectCommand(commandParams);
		const response = await s3.send(command);
		return response;
	} catch (error: any) {
		throw new Error(`Failed to stream S3 object with range: ${error.message}`);
	}
};

/**
 * Get the correct Content-Type based on file extension
 */
export const getContentTypeFromKey = (key: string): string => {
	const ext = path.extname(key).toLowerCase();
	const mimeTypes: Record<string, string> = {
		'.jpg': 'image/jpeg',
		'.jpeg': 'image/jpeg',
		'.png': 'image/png',
		'.gif': 'image/gif',
		'.webp': 'image/webp',
		'.mp4': 'video/mp4',
		'.mov': 'video/quicktime',
		'.avi': 'video/x-msvideo',
		'.webm': 'video/webm',
		'.mp3': 'audio/mpeg',
		'.aac': 'audio/aac',
		'.ogg': 'audio/ogg',
		'.wav': 'audio/wav',
		'.m4a': 'audio/mp4',
		'.wma': 'audio/x-ms-wma',
		'.opus': 'audio/opus',
		'.pdf': 'application/pdf',
	};
	return mimeTypes[ext] || 'application/octet-stream';
};

/**
 * Validate S3 key format (security check to prevent directory traversal)
 */
export const validateS3Key = (key: string): boolean => {
	console.log('🔐 Validating S3 key:', key);

	// Prevent directory traversal attacks
	if (key.includes('..')) {
		console.log('  ❌ Failed: Contains .. (directory traversal)');
		return false;
	}

	if (key.startsWith('/')) {
		console.log('  ❌ Failed: Starts with / (absolute path)');
		return false;
	}

	// Allow common file extensions for images/videos
	const validExtensions = /\.(jpg|jpeg|png|gif|webp|mp4|mp3|mov|avi|pdf|aac|ogg|wav|m4a|wma|opus)$/i;
	const hasValidExt = validExtensions.test(key);

	console.log('  Extension check:', hasValidExt);

	if (!hasValidExt) {
		console.log('  ❌ Failed: No valid extension found');
		console.log('  Valid extensions: jpg, jpeg, png, gif, webp, mp4, mp3, mov, avi, pdf, aac, ogg, wav, m4a, wma, opus');
		return false;
	}

	console.log('  ✅ Validation passed');
	return true;
};
