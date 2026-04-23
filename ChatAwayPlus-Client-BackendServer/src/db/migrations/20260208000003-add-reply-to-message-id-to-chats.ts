import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
  async up(queryInterface: QueryInterface) {
    await queryInterface.addColumn('chats', 'replyToMessageId', {
      type: DataTypes.UUID,
      allowNull: true,
      references: {
        model: 'chats',
        key: 'id',
      },
      onDelete: 'SET NULL',
      comment: 'ID of the message being replied to (swipe reply)',
    });

    // Add index for faster lookups of replies
    await queryInterface.addIndex('chats', ['replyToMessageId'], {
      name: 'idx_chats_reply_to_message_id',
    });
  },

  async down(queryInterface: QueryInterface) {
    await queryInterface.removeIndex('chats', 'idx_chats_reply_to_message_id');
    await queryInterface.removeColumn('chats', 'replyToMessageId');
  },
};
