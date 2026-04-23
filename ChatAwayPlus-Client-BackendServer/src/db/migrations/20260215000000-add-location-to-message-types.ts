import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	async up(queryInterface: QueryInterface) {
		// Add 'location' to messageType ENUM
		await queryInterface.changeColumn('chats', 'messageType', {
			type: DataTypes.ENUM('text', 'image', 'pdf', 'video', 'audio', 'contact', 'poll', 'location'),
			allowNull: false,
			defaultValue: 'text',
		});

		// Add 'location' to replyToMessageType ENUM
		await queryInterface.changeColumn('chats', 'replyToMessageType', {
			type: DataTypes.ENUM('text', 'image', 'pdf', 'video', 'audio', 'contact', 'poll', 'location'),
			allowNull: true,
			comment: 'Type of the replied message',
		});
	},

	async down(queryInterface: QueryInterface) {
		// Remove 'location' from messageType ENUM
		await queryInterface.changeColumn('chats', 'messageType', {
			type: DataTypes.ENUM('text', 'image', 'pdf', 'video', 'audio', 'contact', 'poll'),
			allowNull: false,
			defaultValue: 'text',
		});

		// Remove 'location' from replyToMessageType ENUM
		await queryInterface.changeColumn('chats', 'replyToMessageType', {
			type: DataTypes.ENUM('text', 'image', 'pdf', 'video', 'audio', 'contact', 'poll'),
			allowNull: true,
			comment: 'Type of the replied message',
		});
	},
};
