import { Model, DataTypes } from "sequelize";
import sequelize from "../config/database";
import User from "./user.model";

class Contact extends Model {
  declare id: string;
  declare userId: string;
  declare contactUserId: string;
}

Contact.init(
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
    contactUserId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
  },
  {
    sequelize,
    modelName: "contact",
    timestamps: true,
  }
);

setTimeout(() => {
    Contact.belongsTo(User, { foreignKey: 'userId' });
}, 0)


export default Contact;
