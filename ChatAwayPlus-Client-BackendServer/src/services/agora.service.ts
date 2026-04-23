import { RtcTokenBuilder, RtcRole } from "agora-token";

const AGORA_APP_ID = process.env.AGORA_APP_ID || "7c90c7a383ec49bc9d8a82d35c7c5be2";
const AGORA_APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE || "e842a3c71db440219865f55f0324c936";

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
  const role = RtcRole.PUBLISHER;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const tokenExpireTimestamp = currentTimestamp + TOKEN_EXPIRATION_SECONDS;
  const privilegeExpireTimestamp = currentTimestamp + PRIVILEGE_EXPIRATION_SECONDS;

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
}

/**
 * Get the Agora App ID (needed by clients to initialize the Agora SDK)
 */
export function getAgoraAppId(): string {
  return AGORA_APP_ID;
}
