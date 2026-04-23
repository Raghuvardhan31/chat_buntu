import { Router, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import User from '../db/models/user.model';

const router = Router();

/**
 * Test endpoint to generate a JWT token for socket testing
 * DELETE THIS IN PRODUCTION!
 */
router.post('/generate-token', async (req: Request, res: Response) => {
	try {
		const { userId, mobileNo } = req.body;

		if (!userId) {
			return res.status(400).json({ error: 'userId is required' });
		}

		// Check if user exists
		const user = await User.findByPk(userId);
		if (!user) {
			return res.status(404).json({ error: 'User not found' });
		}

		// Generate token with same structure as auth service
		const token = jwt.sign(
			{
				userId: userId,
				mobileNo: mobileNo || user.mobileNo,
			},
			config.jwt?.secret || 'dev-secret-key',
			{
				expiresIn: '7d'
			}
		);

		res.json({
			success: true,
			token,
			userId,
			expiresIn: '7 days',
			note: 'This token is for testing purposes only. Remove this endpoint in production!'
		});
	} catch (error) {
		console.error('Error generating token:', error);
		res.status(500).json({ error: 'Failed to generate token' });
	}
});

/**
 * Test endpoint to verify a JWT token
 */
router.post('/verify-token', async (req: Request, res: Response) => {
	try {
		const { token } = req.body;

		if (!token) {
			return res.status(400).json({ error: 'token is required' });
		}

		const decoded = jwt.verify(token, config.jwt?.secret || 'dev-secret-key') as any;

		res.json({
			success: true,
			decoded,
			valid: true
		});
	} catch (error: any) {
		res.status(400).json({
			success: false,
			valid: false,
			error: error.message
		});
	}
});

/**
 * Get all users for testing
 */
router.get('/users', async (req: Request, res: Response) => {
	try {
		const users = await User.findAll({
			attributes: ['id', 'firstName', 'lastName', 'mobileNo', 'isVerified'],
			limit: 20
		});

		res.json({
			success: true,
			count: users.length,
			users
		});
	} catch (error) {
		console.error('Error fetching users:', error);
		res.status(500).json({ error: 'Failed to fetch users' });
	}
});

export default router;
