
import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
  async up(queryInterface: QueryInterface) {
    await queryInterface.addColumn('chats', 'isEdited', {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      allowNull: false,
    });

    await queryInterface.addColumn('chats', 'editedAt', {
      type: DataTypes.DATE,
      allowNull: true,
    });
  },

  async down(queryInterface: QueryInterface) {
    await queryInterface.removeColumn('chats', 'isEdited');
    await queryInterface.removeColumn('chats', 'editedAt');
  },
};
