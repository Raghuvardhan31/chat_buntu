import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	async up(queryInterface: QueryInterface) {
		await queryInterface.changeColumn('chats', 'messageType', {
			type: DataTypes.ENUM('text', 'image', 'pdf', 'video'),
			allowNull: false,
			defaultValue: 'text',
		});
	},

	async down(queryInterface: QueryInterface) {
		await queryInterface.changeColumn('chats', 'messageType', {
			type: DataTypes.ENUM('text', 'image', 'pdf'),
			allowNull: false,
			defaultValue: 'text',
		});
	}
};
