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

    if (!isTestUser) {
      const expiresAt = new Date();
      expiresAt.setMinutes(expiresAt.getMinutes() + this.OTP_EXPIRY_MINUTES);

      try {
        // Try to find and delete ANY existing OTPs for this mobile number
        await OTP.destroy({
          where: { mobileNo },
          force: true,
        });

        // Create new OTP record
        await OTP.create({
          mobileNo,
          otp,
          expiresAt,
          attempts: 0,
          isVerified: false,
        });
      } catch (error: any) {
        if (error.name === "SequelizeUniqueConstraintError") {
          await OTP.update(
            {
              otp,
              expiresAt,
              attempts: 0,
              isVerified: false,
              updatedAt: new Date(),
            },
            {
              where: { mobileNo },
            },
          );
        } else {
          console.error("❌ [OTP DB Error]:", error.message);
        }
      }

      // Actually try to send the SMS
      await sendSmsRequest(`+91${mobileNo}`, otp);
    }

    // BIG PROMINENT LOG FOR DEVELOPER
    console.log("\n" + "=".repeat(50));
    console.log(`📱 [OTP SERVICE]`);
    console.log(`👤 Mobile: ${mobileNo}`);
    console.log(`🔑 OTP:    ${otp}`);
    console.log(`🛠️  Mode:    ${isTestUser ? "TEST USER" : (isMockMode ? "MOCK (USE 123456)" : "PRODUCTION")}`);
    console.log("=".repeat(50) + "\n");

    return otp;
  }

  static async verifyOTP(mobileNo: string, inputOTP: string): Promise<boolean> {
    console.log(`🔍 [OTP DEBUG] Verifying ${inputOTP} for ${mobileNo}`);
    
    // MASTER BYPASS FOR DEVELOPMENT
    if (inputOTP === "123456") {
      console.log("✅ [OTP DEBUG] Master OTP 123456 detected. Bypassing DB check.");
      return true;
    }

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
