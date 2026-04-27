const AGORA_APP_ID = "fdae42cbb6f74e03ae0756be1ed3be67";

/**
 * Get the Agora RTC token for a given channel.
 * Static mode: returns empty string as tokens are disabled in Agora Console.
 */
export function generateAgoraToken(channelName: string, uid: number = 0): string {
  console.log(`🎫 Static mode: returning empty token for channel: ${channelName}`);
  return "";
}

/**
 * Get the Agora App ID
 */
export function getAgoraAppId(): string {
  return AGORA_APP_ID;
}

