import axios from "axios";
import { config } from "../config";

interface ApiResponse {
  Details: string;
  Status: string;
}

export async function sendSmsRequest(mobileNo: string, otp: string) {
  const isMockMode = !config.smsKey || config.smsKey === "dummy" || config.smsKey === "";

  if (isMockMode) {
    console.log("------------------------------------------");
    console.log("📱 [MOCK SMS SERVICE]");
    console.log(`🚀 To: ${mobileNo}`);
    console.log(`💬 Message: Your OTP is ${otp}`);
    console.log("------------------------------------------");
    return { success: true, message: "Mock SMS sent successfully" };
  }

  try {
    const response = await axios.get<ApiResponse>(
      `https://2factor.in/API/V1/${config.smsKey}/SMS/${mobileNo}/${otp}/OTP1`,
    );
    console.log("✅ SMS API Status Code:", response.status);
    console.log("✅ SMS API Response:", response.data);
    return { success: true, data: response.data };
  } catch (error: any) {
    console.error("❌ SMS Request failed:");
    if (error.response) {
      console.error("Status:", error.response.status);
      console.error("Data:", error.response.data);
    } else {
      console.error("Error Message:", error.message);
    }
    // Return instead of throw to avoid breaking the signup flow
    return { success: false, error: error.message };
  }
}