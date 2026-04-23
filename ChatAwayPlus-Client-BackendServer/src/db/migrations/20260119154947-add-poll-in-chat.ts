import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
  async up(queryInterface: QueryInterface, ) {
    await queryInterface.addColumn('chats', 'pollPayload', {
      type: DataTypes.JSON,
      allowNull: true,
    });

    await queryInterface.changeColumn('chats', 'messageType', {
      type: DataTypes.ENUM('text', 'image', 'pdf', 'video', 'contact', 'poll'),
      allowNull: false,
      defaultValue: 'text',
    });
  },

  async down(queryInterface: QueryInterface) {
    await queryInterface.removeColumn('chats', 'pollPayload');
  },
};