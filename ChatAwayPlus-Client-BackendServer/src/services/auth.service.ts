import jwt from "jsonwebtoken";

import User from "../db/models/user.model";
import { OTPService } from "./otp.service";
import { notifyContactsAboutNewUser } from "./user.service";

export class AuthService {
  async initiateSignup(mobileNo: string): Promise<{ message: string, otp: string }> {
    // Normalize mobile number: remove all non-digits, then handle prefix
    let normalizedMobile = mobileNo.replace(/\D/g, "");
    console.log(`🔍 [AuthService] Normalizing: "${mobileNo}" -> "${normalizedMobile}"`);
    
    if (normalizedMobile.length === 12 && normalizedMobile.startsWith("91")) {
      normalizedMobile = normalizedMobile.substring(2);
    } else if (normalizedMobile.length === 11 && normalizedMobile.startsWith("0")) {
      normalizedMobile = normalizedMobile.substring(1);
    }

    // Validate normalized mobile number format
    if (!this.isValidMobileNumber(normalizedMobile)) {
      throw new Error(`Invalid mobile number format: ${mobileNo}. Please enter a 10-digit number.`);
    }

    // Generate and send OTP using normalized number
    const otp = await OTPService.sendOTP(normalizedMobile);

    return { message: "OTP sent successfully", otp };
  }

  async verifyOTPAndCreateUser(mobileNo: string, otp: string): Promise<any> {
    // Normalize mobile number for consistency
    const normalizedMobile = mobileNo.trim().replace(/^(\+91|91|0)/, "");

    // Verify OTP
    const isValid = await OTPService.verifyOTP(normalizedMobile, otp);

    if (!isValid) {
      throw new Error("Invalid OTP");
    }

    // Check if user exists
    let user = await User.findOne({ where: { mobileNo: normalizedMobile } });

    if (!user) {
      // Create new user
      user = await User.create({
        mobileNo: normalizedMobile,
        isVerified: true,
      });
    } else {
      // Update existing user
      await User.update({ isVerified: true }, { where: { mobileNo: normalizedMobile } });
    }

    const plainUser: any = user;
    notifyContactsAboutNewUser({
      id: plainUser.id || plainUser.dataValues?.id,
      firstName: plainUser.firstName || plainUser.dataValues?.firstName,
      lastName: plainUser.lastName || plainUser.dataValues?.lastName,
      mobileNo: plainUser.mobileNo || plainUser.dataValues?.mobileNo,
      chat_picture:
        plainUser.chat_picture || plainUser.dataValues?.chat_picture,
    }).catch(() => { });

    const token = jwt.sign(
      {
        userId: user.id || user.dataValues.id,
        mobileNo: user.mobileNo || user.dataValues.mobileNo,
      },
      process.env.JWT_SECRET || "your-secret-key", // Make sure to set JWT_SECRET in your environment variables
      {
        expiresIn: "180d", // Token expires in 180 days
      },
    );

    return { user, token };
  }

  private isValidMobileNumber(mobileNo: string): boolean {
    // Should be exactly 10 digits after normalization
    const mobileRegex = /^[0-9]{10}$/;
    return mobileRegex.test(mobileNo);
  }
}
