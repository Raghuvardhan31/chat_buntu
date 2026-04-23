import { Model, DataTypes } from "sequelize";

import sequelize from "../config/database";
import User from "./user.model";

class Status extends Model {
  declare id: string;
  declare userId: string;
  declare share_your_voice: string;
  declare likesCount: number;
  declare readonly createdAt: Date;
  declare readonly updatedAt: Date;
  declare readonly deletedAt: Date | null;
}

Status.init(
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
    },
    share_your_voice: {
      type: DataTypes.STRING,
      allowNull: false,
      field: "share_your_voice", // Maps to 'share_your_voice' column in database
    },
    likesCount: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    deletedAt: {
      type: DataTypes.DATE,
      allowNull: true,
      defaultValue: null,
    },
  },
  {
    sequelize,
    modelName: 'status',
    tableName: 'statuses', // Use 'statuses' table created by migrations
    timestamps: true,
    paranoid: true, // Enable soft deletes
  },
);

// Define associations after all models are defined
setTimeout(() => {
  const StatusLike = require("./status-like.model").default;
  Status.belongsTo(User, { foreignKey: "userId" });
  Status.hasMany(StatusLike, { foreignKey: "statusId" });
}, 0);

export default Status;
