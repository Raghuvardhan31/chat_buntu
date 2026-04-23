import { Model, DataTypes } from 'sequelize';

import sequelize from '../config/database';
import User from './user.model';

class OTP extends Model {
  declare id: string;
  declare mobileNo: string;
  declare otp: string;
  declare expiresAt: Date;
  declare attempts: number;
  declare isVerified: boolean;
}

OTP.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    mobileNo: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    otp: {
      type: DataTypes.STRING(6),
      allowNull: false,
    },
    expiresAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    attempts: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    isVerified: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
  },
  {
    sequelize,
    modelName: 'otp',
    timestamps: true,
    defaultScope: {
      raw: true
    }
  },
);

export default OTP;
