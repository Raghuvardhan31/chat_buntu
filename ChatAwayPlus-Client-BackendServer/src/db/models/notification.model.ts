import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';
import User from './user.model';

class Notification extends Model {
  declare id: string;
  declare senderId: string;
  declare receiverId: string;
  declare message: string;
  declare type: string;
  declare isRead: boolean;
  declare metadata: any | null;
  declare readonly createdAt: Date;
  declare readonly updatedAt: Date;
}

Notification.init(
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
      allowNull: false,
    },
    type: {
      type: DataTypes.STRING(50),
      allowNull: false,
      comment: 'e.g., message_reaction, chat_picture_like, etc.',
    },
    isRead: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },
    metadata: {
      type: DataTypes.JSON,
      allowNull: true,
      comment: 'Additional data like messageId, emoji, etc.',
    },
  },
  {
    sequelize,
    modelName: 'Notification',
    tableName: 'notifications',
    timestamps: true,
  }
);

// Define associations
Notification.belongsTo(User, { foreignKey: 'senderId', as: 'sender' });
Notification.belongsTo(User, { foreignKey: 'receiverId', as: 'receiver' });

export default Notification;
