import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';
import User from './user.model';
import GroupMessage from './group-message.model';

class GroupMessageStatus extends Model {
  declare id: string;
  declare messageId: string;
  declare userId: string;
  declare status: 'sent' | 'delivered' | 'read';
  declare readAt: Date | null;
  declare deliveredAt: Date | null;
  declare readonly createdAt: Date;
  declare readonly updatedAt: Date;
}

GroupMessageStatus.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    messageId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: GroupMessage, key: 'id' },
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: User, key: 'id' },
    },
    status: {
      type: DataTypes.ENUM('sent', 'delivered', 'read'),
      allowNull: false,
      defaultValue: 'sent',
    },
    deliveredAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    readAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    sequelize,
    modelName: 'GroupMessageStatus',
    tableName: 'group_message_statuses',
    indexes: [
      { unique: true, fields: ['messageId', 'userId'] },
    ],
  }
);

GroupMessageStatus.belongsTo(GroupMessage, { foreignKey: 'messageId', as: 'message' });
GroupMessageStatus.belongsTo(User, { foreignKey: 'userId', as: 'user' });
GroupMessage.hasMany(GroupMessageStatus, { foreignKey: 'messageId', as: 'statuses' });

export default GroupMessageStatus;
