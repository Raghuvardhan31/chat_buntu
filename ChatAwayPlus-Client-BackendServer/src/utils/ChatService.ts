/// <reference lib="dom" />
import { io, Socket } from "socket.io-client";

declare const window: Window &
  typeof globalThis & {
    WEBSOCKET_URL?: string;
  };

export interface Message {
  id: string;
  senderId: string;
  receiverId: string;
  message: string;
  createdAt: Date;
}

export interface ProfileUpdateData {
  userId: string;
  updatedFields: {
    name?: string;
    chat_picture?: string;
    chat_picture_version?: string;
    chat_picture_caption?: string;
    share_your_voice?: string;
    emojis_update?: string;
    emojis_caption?: string;
  };
}

interface ApiResponse {
  data: {
    user: {
      id: string;
      mobileNo: string;
      firstName?: string;
      lastName?: string;
    };
  };
}

export interface ChatUser {
  id: string;
  mobileNo: string;
  firstName?: string;
  lastName?: string;
}

export class ChatService {
  private socket: Socket | null = null;
  private token: string;
  private userId: string;
  private baseUrl: string;
  private messageHandlers: ((message: Message) => void)[] = [];
  private profileUpdateHandlers: ((data: ProfileUpdateData) => void)[] = [];

  constructor(
    baseUrl: string = (typeof window !== "undefined" && window.WEBSOCKET_URL) ||
      "http://192.168.1.2:3200",
  ) {
    this.baseUrl = baseUrl;
    this.token = "";
    this.userId = "";
  }

  /**
   * Initialize the chat service with user credentials
   */
  public async initialize(
    token: string,
    loadHistory: boolean = true,
  ): Promise<void> {
    // Log the base URL being used
    const isBrowser = typeof window !== "undefined";
    const envUrl = isBrowser
      ? (window as any).WEBSOCKET_URL
      : process.env.WEBSOCKET_URL;

    console.log("Environment WEBSOCKET_URL:", envUrl);
    console.log("Using baseUrl:", this.baseUrl);
    console.log("Is browser environment:", isBrowser);
    this.token = token;

    // Connect to Socket.IO
    this.socket = io(this.baseUrl, {
      auth: { token, loadHistory },
    });

    // Get user info from token
    const userInfo = await this.getUserInfo();
    this.userId = userInfo.id;

    // Setup socket event handlers
    this.setupSocketHandlers();

    // Authenticate socket connection
    this.socket.emit("authenticate", { userId: this.userId, loadHistory });
  }

  /**
   * Send a message to another user
   */
  public async sendMessage(receiverId: string, message: string): Promise<void> {
    if (!this.socket?.connected) {
      throw new Error("Not connected to chat server");
    }

    this.socket.emit("private-message", {
      senderId: this.userId,
      receiverId,
      message,
    });
  }

  /**
   * Get chat history with another user
   */
  public async getChatHistory(otherUserId: string): Promise<Message[]> {
    const response = await fetch(
      `${this.baseUrl}/api/chats/history/${this.userId}/${otherUserId}`,
      {
        headers: {
          Authorization: `Bearer ${this.token}`,
        },
      },
    );

    if (!response.ok) {
      throw new Error("Failed to fetch chat history");
    }

    const data = (await response.json()) as Message[];
    return data;
  }

  /**
   * Register a handler for new messages
   */
  public onNewMessage(handler: (message: Message) => void): void {
    this.messageHandlers.push(handler);
  }

  /**
   * Remove a message handler
   */
  public removeMessageHandler(handler: (message: Message) => void): void {
    this.messageHandlers = this.messageHandlers.filter((h) => h !== handler);
  }

  /**
   * Register a handler for profile updates
   */
  public onProfileUpdated(handler: (data: ProfileUpdateData) => void): void {
    this.profileUpdateHandlers.push(handler);
  }

  /**
   * Remove a profile update handler
   */
  public removeProfileUpdateHandler(
    handler: (data: ProfileUpdateData) => void,
  ): void {
    this.profileUpdateHandlers = this.profileUpdateHandlers.filter(
      (h) => h !== handler,
    );
  }

  /**
   * Disconnect from the chat server
   */
  public disconnect(): void {
    this.socket?.disconnect();
    this.socket = null;
  }

  private async getUserInfo(): Promise<ChatUser> {
    try {
      console.log("Fetching user info with token:", this.token);
      const response = await fetch(`${this.baseUrl}/api/users/my-profile`, {
        headers: {
          Authorization: `Bearer ${this.token}`,
        },
      });

      console.log("Response status:", response.status);
      console.log("Response headers:", response.headers);

      if (!response.ok) {
        const errorText = await response.text();
        console.error("Error response:", errorText);
        throw new Error(
          `Failed to get user info: ${response.status} ${errorText}`,
        );
      }

      const data = (await response.json()) as ApiResponse;
      console.log("User info response:", data);
      return {
        id: data.data.user.id,
        mobileNo: data.data.user.mobileNo,
        firstName: data.data.user.firstName,
        lastName: data.data.user.lastName,
      };
    } catch (error) {
      console.error("Error in getUserInfo:", error);
      throw error;
    }
  }

  private setupSocketHandlers(): void {
    if (!this.socket) return;

    this.socket.on("connect", () => {
      console.log("Connected to chat server");
    });

    this.socket.on("new-message", (message: Message) => {
      this.messageHandlers.forEach((handler) => handler(message));
    });

    this.socket.on("profile-updated", (data: ProfileUpdateData) => {
      console.log("Profile updated:", data);
      this.profileUpdateHandlers.forEach((handler) => handler(data));
    });

    this.socket.on("connect_error", (error) => {
      console.error("Chat connection error:", error);
    });
  }
}
