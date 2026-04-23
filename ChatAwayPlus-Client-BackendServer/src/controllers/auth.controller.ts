import { Request, Response } from "express";
import { AuthService } from "../services/auth.service";
import rateLimit from "express-rate-limit";

export const otpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 requests per window
  message: "Too many OTP requests, please try again later",
});

export class AuthController {
  private authService: AuthService;

  constructor() {
    this.authService = new AuthService();
  }

  async initiateSignup(req: Request, res: Response) {
    console.log("Initiate signup called");
    try {
      const { mobileNo } = req.body;

      if (!mobileNo) {
        return res.status(400).json({
          success: false,
          error: "Mobile number is required",
        });
      }

      const result = await this.authService.initiateSignup(mobileNo);

      res.status(200).json({
        success: true,
        message: result.message,
        otp: process.env.NODE_ENV === "development" ? result.otp : undefined,
        devNote: "If you don't receive an SMS, you can use '123456' or check the backend server console."
      });
    } catch (error) {
      console.error('Signup error:', error);
      res.status(400).json({
        success: false,
        error: (error as Error).message,
      });
    }
  }

  async verifyOTP(req: Request, res: Response) {
    try {
      const { mobileNo, otp } = req.body;

      if (!mobileNo || !otp) {
        return res.status(400).json({
          success: false,
          error: "Mobile number and OTP are required",
        });
      }

      const user = await this.authService.verifyOTPAndCreateUser(mobileNo, otp);

      res.status(200).json({
        success: true,
        data: user,
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        error: (error as Error).message,
      });
    }
  }
}
