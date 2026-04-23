/// <reference lib="dom" />
import { io, Socket } from 'socket.io-client';

declare const window: Window & typeof globalThis & {
  WEBSOCKET_URL?: string;
};

export interface ChatServiceConfig {
  baseUrl?: string;
  autoReconnect?: boolean;
  reconnectAttempts?: number;
  reconnectDelay?: number;
  debug?: boolean;
}

export interface Message {
  id: string;
  senderId: string;
  receiverId: string;
  message: string;
  createdAt: Date;
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
  private token: string = '';
  private userId: string = '';
  private baseUrl: string;
  private messageHandlers: ((message: Message) => void)[] = [];
  private config: ChatServiceConfig;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 5;
  private isConnected: boolean = false;
  private messageQueue: any[] = [];

  constructor(config: ChatServiceConfig = {}) {
    this.config = {
      baseUrl: process.env.WEBSOCKET_URL || 'http://192.168.1.16:3200',
      autoReconnect: true,
      reconnectAttempts: 5,
      reconnectDelay: 3000, // 3 seconds
      debug: process.env.NODE_ENV !== 'production',
      ...config
    };

    this.baseUrl = this.config.baseUrl!;
    this.maxReconnectAttempts = this.config.reconnectAttempts!;
  }

  /**
   * Initialize the chat service with user credentials
   */
  public async initialize(token: string, loadHistory: boolean = true): Promise<void> {
    try {
      this.token = token;

      // Log the base URL being used
      const isBrowser = typeof window !== 'undefined';
      const envUrl = isBrowser ? (window as any).WEBSOCKET_URL : process.env.WEBSOCKET_URL;

      if (this.config.debug) {
        console.log('[ChatService] Initializing with config:', {
          baseUrl: this.baseUrl,
          isBrowser,
          envUrl,
          autoReconnect: this.config.autoReconnect
        });
      }

      // Connect to Socket.IO with enhanced options for mobile
      this.socket = io(this.baseUrl, {
        auth: { token, loadHistory },
        reconnection: this.config.autoReconnect,
        reconnectionAttempts: this.config.reconnectAttempts,
        reconnectionDelay: this.config.reconnectDelay,
        timeout: 10000, // 10 seconds
        transports: ['websocket', 'polling'],
        autoConnect: true,
        forceNew: true
      });

      this.setupSocketHandlers();

      // Get user info from token
      const userInfo = await this.getUserInfo();
      this.userId = userInfo.id;

      // Authenticate socket connection
      this.socket.emit('authenticate', { userId: this.userId, loadHistory });

      if (this.config.debug) {
        console.log('[ChatService] Initialization complete');
      }
    } catch (error) {
      console.error('[ChatService] Initialization failed:', error);
      throw error;
    }
  }

  private setupSocketHandlers(): void {
    if (!this.socket) return;

    this.socket.on('connect', () => {
      this.isConnected = true;
      this.reconnectAttempts = 0;
      if (this.config.debug) {
        console.log('[ChatService] Connected to server');
      }

      // Process any queued messages
      this.processMessageQueue();
    });

    this.socket.on('disconnect', (reason: string) => {
      this.isConnected = false;
      if (this.config.debug) {
        console.log(`[ChatService] Disconnected: ${reason}`);
      }
    });

    this.socket.on('connect_error', (error: Error) => {
      console.error('[ChatService] Connection error:', error);
      this.handleReconnect();
    });

    this.socket.on('new-message', (message: Message) => {
      if (this.config.debug) {
        console.log('[ChatService] New message received:', message);
      }
      this.messageHandlers.forEach(handler => handler(message));
    });

    this.socket.on('message-sent', (data: any) => {
      if (this.config.debug) {
        console.log('[ChatService] Message sent confirmation:', data);
      }
    });

    this.socket.on('message-error', (error: any) => {
      console.error('[ChatService] Message error:', error);
    });
  }

  private handleReconnect(): void {
    if (!this.config.autoReconnect || this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('[ChatService] Max reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.config.reconnectDelay! * Math.pow(2, this.reconnectAttempts - 1);

    if (this.config.debug) {
      console.log(`[ChatService] Attempting to reconnect (${this.reconnectAttempts}/${this.maxReconnectAttempts}) in ${delay}ms`);
    }

    setTimeout(() => {
      if (this.socket && !this.socket.connected) {
        this.socket.connect();
      }
    }, delay);
  }

  private async processMessageQueue(): Promise<void> {
    while (this.messageQueue.length > 0 && this.isConnected) {
      const { type, data, resolve, reject } = this.messageQueue.shift()!;
      try {
        if (type === 'sendMessage') {
          await this.sendMessageInternal(data.receiverId, data.message);
          resolve(undefined);
        }
      } catch (error) {
        reject(error);
      }
    }
  }

  /**
   * Send a message to another user
   */
  private async sendMessageInternal(receiverId: string, message: string): Promise<void> {
    if (!this.socket) {
      throw new Error('Chat service not initialized');
    }

    return new Promise((resolve, reject) => {
      if (!this.socket?.connected) {
        if (this.config.debug) {
          console.log('[ChatService] Queueing message - not connected');
        }
        this.messageQueue.push({
          type: 'sendMessage',
          data: { receiverId, message },
          resolve,
          reject
        });
        return;
      }

      this.socket.emit('private-message', {
        senderId: this.userId,
        receiverId,
        message
      });

      // For now, resolve immediately. In production, you might want to wait for confirmation
      resolve();
    });
  }

  public async sendMessage(receiverId: string, message: string): Promise<void> {
    try {
      if (this.config.debug) {
        console.log(`[ChatService] Sending message to ${receiverId}`);
      }
      await this.sendMessageInternal(receiverId, message);
    } catch (error) {
      console.error('[ChatService] Error sending message:', error);
      throw error;
    }
  }

  /**
   * Get chat history with another user
   */
  public async getChatHistory(otherUserId: string): Promise<Message[]> {
    try {
      const response = await fetch(
        `${this.baseUrl}/api/chats/history/${this.userId}/${otherUserId}`,
        {
          headers: {
            'Authorization': `Bearer ${this.token}`,
            'Content-Type': 'application/json'
          }
        }
      );

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('[ChatService] Error fetching chat history:', error);
      throw error;
    }
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
    const index = this.messageHandlers.indexOf(handler);
    if (index > -1) {
      this.messageHandlers.splice(index, 1);
    }
  }

  /**
   * Disconnect from the chat server
   */
  public disconnect(): void {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
      this.isConnected = false;
      this.messageQueue = [];
    }
  }

  /**
   * Check if connected to the chat server
   */
  public isSocketConnected(): boolean {
    return this.isConnected && this.socket?.connected === true;
  }

  /**
   * Get current user ID
   */
  public getCurrentUserId(): string {
    return this.userId;
  }

  /**
   * Get connection status
   */
  public getConnectionStatus(): {
    connected: boolean;
    reconnectAttempts: number;
    queuedMessages: number;
  } {
    return {
      connected: this.isConnected,
      reconnectAttempts: this.reconnectAttempts,
      queuedMessages: this.messageQueue.length
    };
  }

  private async getUserInfo(): Promise<ChatUser> {
    try {
      if (this.config.debug) {
        console.log('Fetching user info with token:', this.token);
      }

      const response = await fetch(`${this.baseUrl}/api/auth/me`, {
        headers: {
          'Authorization': `Bearer ${this.token}`,
          'Content-Type': 'application/json'
        }
      });

      if (this.config.debug) {
        console.log('Response status:', response.status);
      }

      if (!response.ok) {
        throw new Error(`Failed to get user info: ${response.status}`);
      }

      const data: ApiResponse = await response.json();

      if (this.config.debug) {
        console.log('User info response:', data);
      }

      return {
        id: data.data.user.id,
        mobileNo: data.data.user.mobileNo,
        firstName: data.data.user.firstName,
        lastName: data.data.user.lastName
      };
    } catch (error) {
      console.error('Error in getUserInfo:', error);
      throw error;
    }
  }
}

export default ChatService;
