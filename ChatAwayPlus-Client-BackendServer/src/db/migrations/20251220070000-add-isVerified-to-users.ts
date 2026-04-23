import { QueryInterface, DataTypes } from 'sequelize';

export async function up(queryInterface: QueryInterface) {
	const tableDescription = await queryInterface.describeTable('users');

	if (!tableDescription.isVerified) {
		await queryInterface.addColumn('users', 'isVerified', {
			type: DataTypes.BOOLEAN,
			defaultValue: false,
			allowNull: false,
		});
	}
}

export async function down(queryInterface: QueryInterface) {
	const tableDescription = await queryInterface.describeTable('users');

	if (tableDescription.isVerified) {
		await queryInterface.removeColumn('users', 'isVerified');
	}
}
