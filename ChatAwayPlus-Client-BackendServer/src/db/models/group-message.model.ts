import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';
import User from './user.model';
import Group from './group.model';

class GroupMessage extends Model {
  declare id: string;
  declare groupId: string;
  declare senderId: string;
  declare message: string | null;
  declare messageType: 'text' | 'image' | 'pdf' | 'video' | 'audio' | 'contact' | 'poll' | 'location' | 'system';
  declare fileUrl: string | null;
  declare mimeType: string | null;
  declare pollPayload: { question: string; options: { id: string; text: string }[] } | null;
  declare contactPayload: { name: string; phone: string }[] | null;
  declare fileMetadata: { fileName: string; fileSize: number; pageCount?: number } | null;
  declare audioDuration: number | null;
  declare videoThumbnailUrl: string | null;
  declare videoDuration: number | null;
  declare imageWidth: number | null;
  declare imageHeight: number | null;
  declare replyToMessageId: string | null;
  declare replyToMessageText: string | null;
  declare replyToMessageSenderId: string | null;
  declare replyToMessageType: string | null;
  declare clientMessageId: string | null;
  declare isDeleted: boolean;
  declare readonly createdAt: Date;
  declare readonly updatedAt: Date;
}

GroupMessage.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    groupId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: Group, key: 'id' },
    },
    senderId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: User, key: 'id' },
    },
    message: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    messageType: {
      type: DataTypes.ENUM('text', 'image', 'pdf', 'video', 'audio', 'contact', 'poll', 'location', 'system'),
      allowNull: false,
      defaultValue: 'text',
    },
    fileUrl: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    mimeType: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    pollPayload: {
      type: DataTypes.JSON,
      allowNull: true,
    },
    contactPayload: {
      type: DataTypes.JSON,
      allowNull: true,
    },
    fileMetadata: {
      type: DataTypes.JSON,
      allowNull: true,
    },
    audioDuration: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    videoThumbnailUrl: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    videoDuration: {
      type: DataTypes.FLOAT,
      allowNull: true,
    },
    imageWidth: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    imageHeight: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    replyToMessageId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    replyToMessageText: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    replyToMessageSenderId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    replyToMessageType: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    clientMessageId: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    isDeleted: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },
  },
  {
    sequelize,
    modelName: 'GroupMessage',
    tableName: 'group_messages',
    indexes: [
      { fields: ['groupId', 'createdAt'] },
      { unique: true, fields: ['clientMessageId'] },
      { fields: ['senderId'] },
    ],
  }
);

GroupMessage.belongsTo(Group, { foreignKey: 'groupId', as: 'group' });
GroupMessage.belongsTo(User, { foreignKey: 'senderId', as: 'sender' });
GroupMessage.belongsTo(GroupMessage, { foreignKey: 'replyToMessageId', as: 'replyToMessage' });
Group.hasMany(GroupMessage, { foreignKey: 'groupId', as: 'messages' });

export default GroupMessage;
