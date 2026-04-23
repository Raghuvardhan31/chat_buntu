import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
  async up(queryInterface: QueryInterface) {
    // Step 1: Add 'audio' to the messageType ENUM
    // MySQL requires replacing the ENUM definition
    await queryInterface.changeColumn('chats', 'messageType', {
      type: DataTypes.ENUM('text', 'image', 'pdf', 'video', 'audio', 'contact', 'poll'),
      allowNull: false,
      defaultValue: 'text',
    });

    // Step 2: Add audioDuration column
    await queryInterface.addColumn('chats', 'audioDuration', {
      type: DataTypes.FLOAT,
      allowNull: true,
      comment: 'Duration of audio message in seconds',
    });
  },

  async down(queryInterface: QueryInterface) {
    // Remove audioDuration column
    await queryInterface.removeColumn('chats', 'audioDuration');

    // Revert messageType ENUM (remove 'audio')
    await queryInterface.changeColumn('chats', 'messageType', {
      type: DataTypes.ENUM('text', 'image', 'pdf', 'video', 'contact', 'poll'),
      allowNull: false,
      defaultValue: 'text',
    });
  },
};
