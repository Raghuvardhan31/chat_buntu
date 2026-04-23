import { Model, DataTypes, HasManyGetAssociationsMixin } from "sequelize";

import sequelize from "../config/database";

class User extends Model {
  declare status?: any[];
  declare locations?: any[];
  declare blockedUsers?: any[];
  declare blockedBy?: any[];
  declare emojiUpdates?: any[];
  declare emojiLikes?: any[];
  declare contacts?: any[];
  declare getContacts: HasManyGetAssociationsMixin<any>;
  declare getstatus: HasManyGetAssociationsMixin<any>;
  declare getLocations: HasManyGetAssociationsMixin<any>;
  declare getBlockedUsers: HasManyGetAssociationsMixin<any>;
  declare getBlockedBy: HasManyGetAssociationsMixin<any>;
  declare getEmojiUpdates: HasManyGetAssociationsMixin<any>;
  declare getEmojiLikes: HasManyGetAssociationsMixin<any>;
  declare id: string;
  declare email: string;
  declare password: string;
  declare firstName?: string;
  declare lastName?: string;
  declare mobileNo: string;
  declare isVerified: boolean;
  declare metadata: string;
  declare chat_picture?: string;
  declare chat_picture_version?: string;
  declare chat_picture_caption?: string;
  declare readonly createdAt: Date;
  declare readonly updatedAt: Date;
}

User.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      allowNull: false,
      primaryKey: true,
    },
    email: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    password: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    firstName: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    lastName: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    mobileNo: {
      type: DataTypes.STRING,
      primaryKey: true,
      allowNull: false,
      unique: true,
    },
    isVerified: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    metadata: {
      type: DataTypes.TEXT,
      defaultValue: "{}",
      get() {
        const rawValue = this.getDataValue("metadata");
        return rawValue ? JSON.parse(rawValue) : {};
      },
      set(value: any) {
        this.setDataValue("metadata", JSON.stringify(value));
      },
      allowNull: true,
    },
    chat_picture: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    chat_picture_version: {
      type: DataTypes.STRING,
      allowNull: true,
      comment: "Version/ID of current profile picture for like tracking",
    },
    chat_picture_caption: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: "Caption/description for the profile picture",
    },
  },
  {
    sequelize,
    modelName: "user",
    timestamps: true,
    defaultScope: {
      raw: true,
    },
    hooks: {
      beforeUpdate: async (user: any) => {
        // Auto-generate new chat_picture_version when chat_picture changes
        if (user.changed("chat_picture") && user.chat_picture) {
          const { v4: uuidv4 } = require("uuid");
          user.chat_picture_version = uuidv4();
        }
      },
    },
  },
);

// Define associations
// setTimeout(() => {
const Status = require("./status.model").default;
const Location = require("./location.model").default;
const Contact = require("./contact.model").default;

User.hasMany(Contact, {
  foreignKey: "userId",
  as: "contacts",
});

User.hasMany(Status, {
  foreignKey: "userId",
  as: "status",
});

User.hasMany(Location, {
  foreignKey: "userId",
  as: "locations",
});

// Add EmojiUpdate associations
const EmojiUpdate = require("./emoji-update.model").default;

User.hasMany(EmojiUpdate, {
  foreignKey: "userId",
  as: "emojiUpdates",
});
// });

export default User;
