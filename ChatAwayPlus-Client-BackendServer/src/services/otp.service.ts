import { v4 as uuidv4 } from "uuid";

import { sendSmsRequest } from "./sms.service";
import OTP from "../db/models/otp.model";

export class OTPService {
  private static readonly OTP_EXPIRY_MINUTES = 5;
  private static readonly MAX_ATTEMPTS = 3;

  // Default test users with their predefined OTPs
  private static readonly DEFAULT_TEST_USERS = {
    "9999999991": "123456",
    "9999999992": "654321",
  };

  static generateOTP(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  static async sendOTP(mobileNo: string): Promise<string> {
    console.log(`[OTP] Generating OTP for ${mobileNo}...`);
    
    // Check if this is a default test user
    const isTestUser = mobileNo in this.DEFAULT_TEST_USERS;
    
    // In Mock Mode (dummy key), use "123456" as the default OTP for all users
    const isMockMode = !process.env.SMS_KEY || process.env.SMS_KEY === "dummy" || process.env.SMS_KEY === "";
    
    let otp: string;
    if (isTestUser) {
      otp = this.DEFAULT_TEST_USERS[mobileNo as keyof typeof this.DEFAULT_TEST_USERS];
    } else if (isMockMode) {
      otp = "123456";
    } else {
      otp = this.generateOTP();
    }

    // Skip database operations for test users
    if (!isTestUser) {
      const expiresAt = new Date();
      expiresAt.setMinutes(expiresAt.getMinutes() + this.OTP_EXPIRY_MINUTES);

      try {
        // Try to find and delete ANY existing OTPs for this mobile number (regardless of verification status)
        const deletedCount = await OTP.destroy({
          where: { mobileNo },
          force: true,
        });

        // Create new OTP record only for non-test users
        await OTP.create({
          mobileNo,
          otp,
          expiresAt,
          attempts: 0,
          isVerified: false,
        });
      } catch (error: any) {
        // If still get duplicate error, try to update existing record instead
        if (error.name === "SequelizeUniqueConstraintError") {
          console.log(
            "Duplicate error caught, trying to update existing OTP...",
          );
          // Update ANY record with this mobile number, not just unverified ones
          const [affectedCount] = await OTP.update(
            {
              otp,
              expiresAt,
              attempts: 0,
              isVerified: false, // Reset to unverified
              updatedAt: new Date(),
            },
            {
              where: { mobileNo },
              individualHooks: true,
            },
          );

          // Verify the update worked
          const verifyRecord = await OTP.findOne({
            where: { mobileNo, isVerified: false },
            raw: true,
          });
        } else {
          throw error;
        }
      }

    await sendSmsRequest(`+91${mobileNo}`, otp);
    console.log(`✅ [OTP] Lifecycle: New OTP created for ${mobileNo}: ${otp}`);
    }

    // Log the OTP for development purposes
    if (isTestUser) {
      console.log(`ℹ️ [OTP] Test User Detected. Predefined OTP: ${otp}`);
    }

    return otp;
  }

  static async verifyOTP(mobileNo: string, inputOTP: string): Promise<boolean> {
    // Handle test users
    if (mobileNo in this.DEFAULT_TEST_USERS) {
      const expectedOTP =
        this.DEFAULT_TEST_USERS[
        mobileNo as keyof typeof this.DEFAULT_TEST_USERS
        ];
      if (inputOTP === expectedOTP) {
        return true;
      }
      throw new Error("Invalid OTP");
    }

    // Original verification flow for non-test users
    const otpRecord = await OTP.findOne({
      where: { mobileNo, isVerified: false },
      raw: true,
    });

    console.log(`🔍 [OTP Verification] Checking ${mobileNo}...`);
    console.log(`   - Input OTP: ${inputOTP}`);
    console.log(`   - DB Record:`, otpRecord ? `Found (OTP: ${otpRecord.otp})` : "Not Found");

    if (!otpRecord) {
      console.warn(`❌ [OTP Verification] No unverified record found for ${mobileNo}`);
      throw new Error("OTP not found or expired");
    }

    if (otpRecord.attempts >= this.MAX_ATTEMPTS) {
      await OTP.update(
        { isVerified: true },
        { where: { mobileNo: otpRecord.mobileNo } },
      );
      throw new Error("Maximum verification attempts exceeded");
    }

    if (new Date() > otpRecord.expiresAt) {
      await OTP.update(
        { isVerified: true },
        { where: { mobileNo: otpRecord.mobileNo } },
      );
      throw new Error("OTP expired");
    }

    await OTP.increment("attempts", {
      where: { mobileNo: otpRecord.mobileNo },
    });

    if (otpRecord.otp !== inputOTP) {
      throw new Error("Invalid OTP");
    }

    await OTP.update(
      { isVerified: true },
      { where: { mobileNo: otpRecord.mobileNo } },
    );
    return true;
  }
}
