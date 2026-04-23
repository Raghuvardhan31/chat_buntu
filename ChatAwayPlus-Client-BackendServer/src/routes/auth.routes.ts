import { Router } from 'express';

import { AuthController } from '../controllers/auth.controller';
import { otpLimiter } from '../controllers/auth.controller';

const router = Router();
const authController = new AuthController();

// Initiate signup with mobile number
router.post('/signup', otpLimiter, (req, res) => authController.initiateSignup(req, res));

// Verify OTP and create/login user
router.post('/verify-otp', (req, res) => authController.verifyOTP(req, res));

export default router; 