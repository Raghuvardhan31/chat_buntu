import { RtcTokenBuilder, RtcRole } from "agora-token";

const AGORA_APP_ID = process.env.AGORA_APP_ID || "fdae42cbb6f74e03ae0756be1ed3be67";
const AGORA_APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE || "";

// Token validity: 24 hours (in seconds)
const TOKEN_EXPIRATION_SECONDS = 86400;
// Privilege validity: 24 hours (in seconds)
const PRIVILEGE_EXPIRATION_SECONDS = 86400;

/**
 * Generate an Agora RTC token for a given channel.
 * Uses uid=0 so any user can join with this token on the specified channel.
 *
 * @param channelName - The Agora channel name (must match what clients use to join)
 * @param uid - User ID (0 = wildcard, any uid can use this token)
 * @returns The generated RTC token string
 */
export function generateAgoraToken(channelName: string, uid: number = 0): string {
  // Support for Static Token Method (Test Mode)
  // If AGORA_STATIC_TOKEN is provided in .env, use it.
  // If AGORA_TEST_MODE is true, return an empty string (works if Agora project has no certificate or is in testing mode)
  
  const staticToken = process.env.AGORA_STATIC_TOKEN;
  if (staticToken) {
    console.log(`🎫 Using static Agora token for channel: ${channelName}`);
    return staticToken;
  }

  const isTestMode = process.env.AGORA_TEST_MODE === 'true';
  // If no certificate is provided, we MUST return an empty string or the token builder will fail
  if (isTestMode || !AGORA_APP_CERTIFICATE || AGORA_APP_CERTIFICATE === "") {
    console.log(`🎫 Agora Test Mode active (or certificate missing): returning empty token for channel: ${channelName}`);
    return "";
  }

  const role = RtcRole.PUBLISHER;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const tokenExpireTimestamp = currentTimestamp + TOKEN_EXPIRATION_SECONDS;
  const privilegeExpireTimestamp = currentTimestamp + PRIVILEGE_EXPIRATION_SECONDS;

  try {
    const token = RtcTokenBuilder.buildTokenWithUid(
      AGORA_APP_ID,
      AGORA_APP_CERTIFICATE,
      channelName,
      uid,
      role,
      tokenExpireTimestamp,
      privilegeExpireTimestamp
    );

    console.log(`🔑 Agora token generated for channel: ${channelName}, uid: ${uid}`);
    return token;
  } catch (error) {
    console.error("❌ Failed to generate Agora token:", error);
    return ""; // Fallback to empty token (works in test mode)
  }
}

/**
 * Get the Agora App ID (needed by clients to initialize the Agora SDK)
 */
export function getAgoraAppId(): string {
  return AGORA_APP_ID;
}
