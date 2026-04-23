import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	async up(queryInterface: QueryInterface) {
		await queryInterface.addColumn('chats', 'imageWidth', {
			type: DataTypes.INTEGER,
			allowNull: true,
			comment: 'Width of image in pixels for dynamic aspect ratio display'
		});

		await queryInterface.addColumn('chats', 'imageHeight', {
			type: DataTypes.INTEGER,
			allowNull: true,
			comment: 'Height of image in pixels for dynamic aspect ratio display'
		});
	},

	async down(queryInterface: QueryInterface) {
		await queryInterface.removeColumn('chats', 'imageWidth');
		await queryInterface.removeColumn('chats', 'imageHeight');
	}
};
