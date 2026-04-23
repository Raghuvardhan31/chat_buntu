import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	async up(queryInterface: QueryInterface) {
		await queryInterface.addColumn('chats', 'deletedForSender', {
			type: DataTypes.BOOLEAN,
			allowNull: false,
			defaultValue: false,
		});

		await queryInterface.addColumn('chats', 'deletedForReceiver', {
			type: DataTypes.BOOLEAN,
			allowNull: false,
			defaultValue: false,
		});

		await queryInterface.addColumn('chats', 'deletedAt', {
			type: DataTypes.DATE,
			allowNull: true,
			defaultValue: null,
		});
	},

	async down(queryInterface: QueryInterface) {
		await queryInterface.removeColumn('chats', 'deletedForSender');
		await queryInterface.removeColumn('chats', 'deletedForReceiver');
		await queryInterface.removeColumn('chats', 'deletedAt');
	},
};
