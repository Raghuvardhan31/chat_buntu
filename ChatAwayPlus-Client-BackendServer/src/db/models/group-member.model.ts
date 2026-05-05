import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';
import User from './user.model';
import Group from './group.model';

class GroupMember extends Model {
  declare id: string;
  declare groupId: string;
  declare userId: string;
  declare role: 'admin' | 'member';
  declare lastSeenMessageId: string | null;
  declare readonly createdAt: Date;
  declare readonly updatedAt: Date;
}

GroupMember.init(
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
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: User, key: 'id' },
    },
    role: {
      type: DataTypes.ENUM('admin', 'member'),
      allowNull: false,
      defaultValue: 'member',
    },
    lastSeenMessageId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
  },
  {
    sequelize,
    modelName: 'GroupMember',
    tableName: 'group_members',
    indexes: [
      { unique: true, fields: ['groupId', 'userId'] },
    ],
  }
);

GroupMember.belongsTo(Group, { foreignKey: 'groupId', as: 'group' });
GroupMember.belongsTo(User, { foreignKey: 'userId', as: 'user' });
Group.hasMany(GroupMember, { foreignKey: 'groupId', as: 'members' });

export default GroupMember;
