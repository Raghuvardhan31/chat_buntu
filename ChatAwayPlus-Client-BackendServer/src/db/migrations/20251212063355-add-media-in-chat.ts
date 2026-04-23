import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	async up(queryInterface: QueryInterface) {
		await queryInterface.changeColumn('chats', 'message', {
			type: DataTypes.TEXT,
			allowNull: true,
		});

		await queryInterface.addColumn('chats', 'messageType', {
			type: DataTypes.ENUM('text', 'image', 'pdf'),
			allowNull: false,
			defaultValue: 'text',
		});

		await queryInterface.addColumn('chats', 'fileUrl', {
			type: DataTypes.TEXT,
			allowNull: true,
		});

		await queryInterface.addColumn('chats', 'mimeType', {
			type: DataTypes.STRING,
			allowNull: true,
		});
	},

	async down(queryInterface: QueryInterface) {
		await queryInterface.changeColumn('chats', 'message', {
			type: DataTypes.TEXT,
			allowNull: false,
		});

		await queryInterface.removeColumn('chats', 'fileUrl');
		await queryInterface.removeColumn('chats', 'mimeType');

		await queryInterface.removeColumn('chats', 'messageType');
	}
};
