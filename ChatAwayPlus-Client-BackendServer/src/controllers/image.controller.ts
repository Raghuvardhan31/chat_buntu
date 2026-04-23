import { Request, Response } from 'express';
import fs from 'fs';
import path from 'path';
import { isS3Configured } from '../config/s3.config';
import { getS3ObjectStream, getS3ObjectAsBase64, getS3ObjectWithBase64, validateS3Key, getS3ObjectHead, getS3ObjectStreamWithRange, getContentTypeFromKey } from '../utils/s3.util';

/**
 * Stream media (images/videos) directly from S3 or Local Filesystem
 * For images: simple stream with correct Content-Type
 * For videos: supports Range headers for seeking/buffering (WhatsApp-like playback)
 * Usage: GET /api/images/stream/stories/userId/filename.mp4
 */
export const streamImage = async (req: Request, res: Response) => {
	try {
		const key = req.params.key;

		if (!key) {
			return res.status(400).json({ success: false, message: 'Invalid media key' });
		}

		const isValid = validateS3Key(key);

		if (!isValid) {
			return res.status(400).json({ success: false, message: 'Invalid media key' });
		}

		const contentType = getContentTypeFromKey(key);
		const isVideo = contentType.startsWith('video/');

		// --- LOCAL STORAGE FALLBACK ---
		if (!isS3Configured) {
			const localPath = path.join(__dirname, '../../uploads', key);
			
			if (!fs.existsSync(localPath)) {
				return res.status(404).json({ success: false, message: 'Media not found on local storage' });
			}

			const stats = fs.statSync(localPath);
			const fileSize = stats.size;

			if (isVideo) {
				const range = req.headers.range;
				if (range) {
					const parts = range.replace(/bytes=/, '').split('-');
					const start = parseInt(parts[0], 10);
					const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
					const chunkSize = end - start + 1;

					res.status(206);
					res.setHeader('Content-Range', `bytes ${start}-${end}/${fileSize}`);
					res.setHeader('Accept-Ranges', 'bytes');
					res.setHeader('Content-Length', chunkSize);
					res.setHeader('Content-Type', contentType);
					res.setHeader('Cache-Control', 'public, max-age=86400');

					fs.createReadStream(localPath, { start, end }).pipe(res);
				} else {
					res.status(200);
					res.setHeader('Content-Length', fileSize);
					res.setHeader('Content-Type', contentType);
					res.setHeader('Accept-Ranges', 'bytes');
					res.setHeader('Cache-Control', 'public, max-age=86400');
					fs.createReadStream(localPath).pipe(res);
				}
			} else {
				res.setHeader('Content-Type', contentType);
				res.setHeader('Cache-Control', 'public, max-age=31536000');
				fs.createReadStream(localPath).pipe(res);
			}
			return;
		}

		// --- S3 STORAGE ---
		// For video files, handle Range requests for seeking/buffering
		if (isVideo) {
			const range = req.headers.range;

			// Get file size first
			const headData = await getS3ObjectHead(key);
			const fileSize = headData.contentLength;

			if (range) {
				// Parse Range header: "bytes=start-end"
				const parts = range.replace(/bytes=/, '').split('-');
				const start = parseInt(parts[0], 10);
				const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
				const chunkSize = end - start + 1;

				const response = await getS3ObjectStreamWithRange(key, `bytes=${start}-${end}`);

				res.status(206);
				res.setHeader('Content-Range', `bytes ${start}-${end}/${fileSize}`);
				res.setHeader('Accept-Ranges', 'bytes');
				res.setHeader('Content-Length', chunkSize);
				res.setHeader('Content-Type', contentType);
				res.setHeader('Cache-Control', 'public, max-age=86400');

				const body = response.Body as any;
				if (body.pipe && typeof body.pipe === 'function') {
					body.pipe(res);
				} else if (body[Symbol.asyncIterator]) {
					for await (const chunk of body) {
						res.write(chunk);
					}
					res.end();
				}
			} else {
				// No Range header - send full file with Accept-Ranges hint
				const response = await getS3ObjectStreamWithRange(key);

				res.status(200);
				res.setHeader('Content-Length', fileSize);
				res.setHeader('Content-Type', contentType);
				res.setHeader('Accept-Ranges', 'bytes');
				res.setHeader('Cache-Control', 'public, max-age=86400');

				const body = response.Body as any;
				if (body.pipe && typeof body.pipe === 'function') {
					body.pipe(res);
				} else if (body[Symbol.asyncIterator]) {
					for await (const chunk of body) {
						res.write(chunk);
					}
					res.end();
				}
			}
		} else {
			// For images and other files: simple stream
			const stream = await getS3ObjectStream(key);

			res.setHeader('Content-Type', contentType);
			res.setHeader('Cache-Control', 'public, max-age=31536000');

			if (stream) {
				const body = stream as any;
				if (body.pipe && typeof body.pipe === 'function') {
					body.pipe(res);
				} else if (body[Symbol.asyncIterator]) {
					(async () => {
						try {
							for await (const chunk of body) {
								res.write(chunk);
							}
							res.end();
						} catch (error: any) {
							if (!res.headersSent) {
								res.status(500).json({ success: false, message: 'Stream error' });
							}
						}
					})();
				}
			} else {
				return res.status(500).json({ success: false, message: 'Failed to stream media' });
			}
		}
	} catch (error: any) {
		if (!res.headersSent) {
			res.status(500).json({ success: false, message: error.message });
		}
	}
};

/**
 * Get image as base64 in JSON response
 * Usage: GET /api/images/base64/profile/userId/filename.jpg
 */
export const getImageBase64 = async (req: Request, res: Response) => {
	try {
		const key = req.params.key;



		if (!key || !validateS3Key(key)) {
			return res.status(400).json({ success: false, message: 'Invalid image key' });
		}

		const base64 = await getS3ObjectAsBase64(key);

		res.json({
			success: true,
			data: {
				base64,
				key,
			}
		});
	} catch (error: any) {

		res.status(500).json({ success: false, message: error.message });
	}
};

/**
 * Get image as base64 with metadata
 * Usage: GET /api/images/base64-meta/profile/userId/filename.jpg
 */
export const getImageBase64WithMeta = async (req: Request, res: Response) => {
	try {
		const key = req.params.key;



		if (!key || !validateS3Key(key)) {
			return res.status(400).json({ success: false, message: 'Invalid image key' });
		}

		const data = await getS3ObjectWithBase64(key);

		res.json({
			success: true,
			data: {
				...data,
				key,
			}
		});
	} catch (error: any) {

		res.status(500).json({ success: false, message: error.message });
	}
};
