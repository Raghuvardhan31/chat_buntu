import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';
import User from './user.model';
import Chat from './chat.model';

class PollVote extends Model {
  public id!: string;
  public pollMessageId!: string;
  public userId!: string;
  public optionId!: string;
}

PollVote.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },

    pollMessageId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: Chat,
        key: 'id',
      },
      onDelete: 'CASCADE',
    },

    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: User,
        key: 'id',
      },
    },

    optionId: {
      type: DataTypes.STRING,
      allowNull: false,
    },
  },
  {
    sequelize,
    tableName: 'poll_votes',
    modelName: 'PollVote',
     timestamps: false,
    indexes: [
      {
        unique: true,
        fields: ['pollMessageId', 'userId', 'optionId'],
      },
    ],
  }
);

export default PollVote;