import { Model, DataTypes } from 'sequelize';

import sequelize from '../config/database';
import User from './user.model';

class StatusLike extends Model {
  declare id: string;
  declare statusId: string;
  declare userId: string;
  declare readonly createdAt: Date;
  declare readonly updatedAt: Date;
}

StatusLike.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      allowNull: false,
      primaryKey: true,
    },
    statusId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'statuses',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onDelete: 'CASCADE',
    },
  },
  {
    sequelize,
    modelName: 'status_like',
    tableName: 'status_likes',
    timestamps: true,
    indexes: [
      {
        unique: true,
        fields: ['statusId', 'userId'],
      },
    ],
  }
);

// Define associations
const Status = require('./status.model').default;
StatusLike.belongsTo(Status, { foreignKey: 'statusId' });
StatusLike.belongsTo(User, { foreignKey: 'userId' });

export default StatusLike;
