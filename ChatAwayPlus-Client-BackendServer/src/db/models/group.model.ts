import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';
import User from './user.model';

class Group extends Model {
  declare id: string;
  declare name: string;
  declare icon: string | null;
  declare createdBy: string;
  declare description: string | null;
  declare isRestricted: boolean; // only admins can send messages
  declare isDeleted: boolean;
  declare readonly createdAt: Date;
  declare readonly updatedAt: Date;
}

Group.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    name: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    icon: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'S3 URL for group icon/avatar image',
    },
    createdBy: {
      type: DataTypes.UUID,
      allowNull: false,
      references: { model: User, key: 'id' },
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    isRestricted: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
      comment: 'When true, only admins can send messages',
    },
    isDeleted: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    },
  },
  {
    sequelize,
    modelName: 'Group',
    tableName: 'groups',
  }
);

Group.belongsTo(User, { foreignKey: 'createdBy', as: 'creator' });

export default Group;
