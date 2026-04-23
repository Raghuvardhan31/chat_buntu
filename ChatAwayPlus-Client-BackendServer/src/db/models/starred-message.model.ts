import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';
import User from './user.model';
import Chat from './chat.model';

class StarredMessage extends Model {
  declare id: string;
  declare userId: string;
  declare chatId: string;
  declare readonly createdAt: Date;
}

StarredMessage.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },

    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: User,
        key: 'id',
      },
    },

    chatId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: Chat,
        key: 'id',
      },
    },
  },
  {
    sequelize,
    tableName: 'starred_messages',
    modelName: 'StarredMessage',
    timestamps: true,
    updatedAt: false,
    indexes: [
      {
        unique: true,
        fields: ['userId', 'chatId'],
      },
    ],
  }
);


StarredMessage.belongsTo(Chat, {
  foreignKey: 'chatId',
  as: 'chat',
});

StarredMessage.belongsTo(User, {
  foreignKey: 'userId',
  as: 'user',
});


export default StarredMessage;
