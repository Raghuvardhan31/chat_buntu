import { Model, DataTypes } from 'sequelize';

import sequelize from '../config/database';
import User from './user.model';

class Chat extends Model {
  declare id: string;
  declare senderId: string;
  declare receiverId: string;
  declare message: string | null;

  declare messageType: 'text' | 'image' | 'pdf' | 'video' | 'audio' | 'contact' | 'poll' | 'location';
  declare fileUrl?: string | null;
  declare mimeType?: string | null;
  declare deletedForSender?: boolean;
  declare deletedForReceiver?: boolean;
  declare isFollowUp?: boolean;

  declare pollPayload?: {
    question: string;
    options: {
      id: string;
      text: string;
    }[];
  } | null;

  declare deletedAt?: Date;

  declare contactPayload?: {
    name: string;
    phone: string;
  }[] | null;

  declare fileMetadata?: {
    fileName: string;
    fileSize: number;
    pageCount?: number;
  } | null;

  declare audioDuration?: number | null;

  declare videoThumbnailUrl?: string | null;
  declare videoDuration?: number | null;

  declare replyToMessageId?: string | null;
  declare replyToMessageText?: string | null;
  declare replyToMessageSenderId?: string | null;
  declare replyToMessageType?: 'text' | 'image' | 'pdf' | 'video' | 'audio' | 'contact' | 'poll' | 'location' | null;

  declare isEdited?: boolean;
  declare editedAt?: Date;

  declare messageStatus: 'sent' | 'delivered' | 'read';
  declare isRead: boolean;
  declare deliveryChannel: 'socket' | 'fcm'; // How sender sent the message (always 'socket' for now)
  declare receiverDeliveryChannel?: 'socket' | 'fcm'; // How receiver actually received/acknowledged the message
  declare deliveredAt?: Date;
  declare readAt?: Date;

  // Last activity tracking for chat list preview
  declare lastActivityType?: string | null;
  declare lastActivityAt?: Date | null;
  declare lastActivityActorId?: string | null;
  declare lastActivityEmoji?: string | null;
  declare lastActivityMessageId?: string | null;

  declare readonly createdAt: Date;
  declare readonly updatedAt: Date;

}


Chat.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    senderId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: User,
        key: 'id',
      },
    },
    receiverId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: User,
        key: 'id',
      },
    },
    message: {
      type: DataTypes.TEXT,
      allowNull: true,
    },

    messageType: {
      type: DataTypes.ENUM('text', 'image', 'pdf', 'video', 'audio', 'contact', 'poll', 'location'),
      allowNull: false,
      defaultValue: 'text',
    },

    fileUrl: {
      type: DataTypes.TEXT,
      allowNull: true,
    },

    contactPayload: {
      type: DataTypes.JSON,
      allowNull: true
    },

    pollPayload: {
      type: DataTypes.JSON,
      allowNull: true,
    },

    fileMetadata: {
      type: DataTypes.JSON,
      allowNull: true
    },

    mimeType: {
      type: DataTypes.STRING,
      allowNull: true,
    },

    imageWidth: {
      type: DataTypes.INTEGER,
      allowNull: true,
      comment: 'Width of image in pixels for dynamic aspect ratio display'
    },

    imageHeight: {
      type: DataTypes.INTEGER,
      allowNull: true,
      comment: 'Height of image in pixels for dynamic aspect ratio display'
    },

    messageStatus: {
      type: DataTypes.ENUM('sent', 'delivered', 'read'),
      defaultValue: 'sent',
      allowNull: false,
    },
    isRead: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },
    deliveryChannel: {
      type: DataTypes.ENUM('socket', 'fcm'),
      defaultValue: 'socket',
      allowNull: false,
    },
    receiverDeliveryChannel: {
      type: DataTypes.ENUM('socket', 'fcm'),
      allowNull: true,
    },
    deliveredAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    readAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },

    deletedForSender: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },

    deletedForReceiver: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },

    deletedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },

    isEdited: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },

    editedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },

    lastActivityType: {
      type: DataTypes.STRING(20),
      allowNull: true,
      comment: 'Type of last activity: reaction, typing, etc.'
    },

    lastActivityAt: {
      type: DataTypes.DATE,
      allowNull: true,
      comment: 'Timestamp of last activity'
    },

    lastActivityActorId: {
      type: DataTypes.UUID,
      allowNull: true,
      comment: 'User ID who performed the last activity'
    },

    lastActivityEmoji: {
      type: DataTypes.STRING(10),
      allowNull: true,
      comment: 'Emoji used in last reaction activity'
    },

    lastActivityMessageId: {
      type: DataTypes.UUID,
      allowNull: true,
      comment: 'Message ID related to last activity'
    },
    isFollowUp: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },

    audioDuration: {
      type: DataTypes.FLOAT,
      allowNull: true,
      comment: 'Duration of audio message in seconds',
    },

    videoThumbnailUrl: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'S3 URL for video thumbnail image',
    },

    videoDuration: {
      type: DataTypes.FLOAT,
      allowNull: true,
      comment: 'Actual video duration in seconds (null for non-video messages)',
    },

    replyToMessageId: {
      type: DataTypes.UUID,
      allowNull: true,
      comment: 'ID of the message being replied to (swipe reply)',
    },

    replyToMessageText: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Snapshot of replied message text content',
    },

    replyToMessageSenderId: {
      type: DataTypes.UUID,
      allowNull: true,
      comment: 'ID of the user who sent the replied message',
    },

    replyToMessageType: {
      type: DataTypes.ENUM('text', 'image', 'pdf', 'video', 'audio', 'contact', 'poll', 'location'),
      allowNull: true,
      comment: 'Type of the replied message',
    },

  },
  {
    sequelize,
    modelName: 'Chat',
    tableName: 'chats',
  }
);

// Define associations
Chat.belongsTo(User, { foreignKey: 'senderId', as: 'sender' });
Chat.belongsTo(User, { foreignKey: 'receiverId', as: 'receiver' });
Chat.belongsTo(Chat, { foreignKey: 'replyToMessageId', as: 'replyToMessage' });

// Association with message reactions (load lazily to avoid circular dependency)
setTimeout(() => {
  const MessageReaction = require('./message-reaction.model').default;
  Chat.hasMany(MessageReaction, { foreignKey: 'messageId', as: 'reactions' });

  const PollVote = require('./poll-vote.model').default;
  Chat.hasMany(PollVote, { foreignKey: 'pollMessageId', as: 'pollVotes' });
}, 0);

export default Chat;
