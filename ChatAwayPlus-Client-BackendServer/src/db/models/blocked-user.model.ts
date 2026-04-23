import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';
import User from './user.model';

class BlockedUser extends Model {
  declare id: string;
  declare blockerId: string;
  declare blockedId: string;
  declare createdAt: Date;
  declare updatedAt: Date;
}

BlockedUser.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    blockerId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE',
    },
    blockedId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE',
    },
  },
  {
    sequelize,
    modelName: 'blockedUser',
    tableName: 'blocked_users',
    timestamps: true,
  }
);

// Set up associations
User.belongsToMany(User, {
  through: BlockedUser,
  as: 'blockedUsers',
  foreignKey: 'blockerId',
  otherKey: 'blockedId'
});

User.belongsToMany(User, {
  through: BlockedUser,
  as: 'blockedBy',
  foreignKey: 'blockedId',
  otherKey: 'blockerId'
});

export default BlockedUser;
