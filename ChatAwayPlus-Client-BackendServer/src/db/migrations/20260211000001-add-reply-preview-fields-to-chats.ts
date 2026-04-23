import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	async up(queryInterface: QueryInterface) {
		// Add reply preview snapshot fields
		await queryInterface.addColumn('chats', 'replyToMessageText', {
			type: DataTypes.TEXT,
			allowNull: true,
			comment: 'Snapshot of replied message text content',
		});

		await queryInterface.addColumn('chats', 'replyToMessageSenderId', {
			type: DataTypes.UUID,
			allowNull: true,
			comment: 'ID of the user who sent the replied message',
		});

		await queryInterface.addColumn('chats', 'replyToMessageType', {
			type: DataTypes.ENUM('text', 'image', 'pdf', 'video', 'audio', 'contact', 'poll'),
			allowNull: true,
			comment: 'Type of the replied message',
		});

		// Add index on replyToMessageSenderId for faster lookups
		await queryInterface.addIndex('chats', ['replyToMessageSenderId'], {
			name: 'idx_chats_reply_to_message_sender_id',
		});
	},

	async down(queryInterface: QueryInterface) {
		await queryInterface.removeIndex('chats', 'idx_chats_reply_to_message_sender_id');
		await queryInterface.removeColumn('chats', 'replyToMessageType');
		await queryInterface.removeColumn('chats', 'replyToMessageSenderId');
		await queryInterface.removeColumn('chats', 'replyToMessageText');
	},
};
