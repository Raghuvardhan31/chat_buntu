import { Model, DataTypes } from 'sequelize';

import sequelize from '../config/database';
import User from './user.model';

class Location extends Model {
  declare id: string;
  declare userId: string;
  declare name: string;
  declare description?: string;
  declare photos?: string[];
  declare readonly createdAt: Date;
  declare readonly updatedAt: Date;
}

Location.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      allowNull: false,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id',
      },
    },
    name: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    photos: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: []
    },
  },
  {
    sequelize,
    modelName: 'Location',
    tableName: 'locations',
    defaultScope: {
      raw: true
    }
  }
);

// Define association with User model
// Location.belongsTo(User, {
//   foreignKey: 'userId',
//   as: 'user',
// });

export default Location;
