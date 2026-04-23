import { QueryInterface, DataTypes } from 'sequelize';

export async function up(queryInterface: QueryInterface) {

	await queryInterface.addColumn('chats', 'isFollowUp', {
		type: DataTypes.BOOLEAN,
		defaultValue: false,
	});

}

export async function down(queryInterface: QueryInterface) {
	await queryInterface.removeColumn('chats', 'isFollowUp');
}
