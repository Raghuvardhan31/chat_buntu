import { QueryInterface, DataTypes } from 'sequelize';

export const up = async (queryInterface: QueryInterface): Promise<void> => {
	// Add columns for tracking last activity in conversations
	await queryInterface.addColumn('chats', 'lastActivityType', {
		type: DataTypes.STRING(20),
		allowNull: true,
		comment: 'Type of last activity: reaction, typing, etc.'
	});

	await queryInterface.addColumn('chats', 'lastActivityAt', {
		type: DataTypes.DATE,
		allowNull: true,
		comment: 'Timestamp of last activity'
	});

	await queryInterface.addColumn('chats', 'lastActivityActorId', {
		type: DataTypes.UUID,
		allowNull: true,
		comment: 'User ID who performed the last activity'
	});

	await queryInterface.addColumn('chats', 'lastActivityEmoji', {
		type: DataTypes.STRING(10),
		allowNull: true,
		comment: 'Emoji used in last reaction activity'
	});

	await queryInterface.addColumn('chats', 'lastActivityMessageId', {
		type: DataTypes.UUID,
		allowNull: true,
		comment: 'Message ID related to last activity'
	});

	// Add index for faster queries on lastActivityAt
	await queryInterface.addIndex('chats', ['lastActivityAt'], {
		name: 'idx_chats_last_activity_at'
	});
};

export const down = async (queryInterface: QueryInterface): Promise<void> => {
	await queryInterface.removeIndex('chats', 'idx_chats_last_activity_at');
	await queryInterface.removeColumn('chats', 'lastActivityMessageId');
	await queryInterface.removeColumn('chats', 'lastActivityEmoji');
	await queryInterface.removeColumn('chats', 'lastActivityActorId');
	await queryInterface.removeColumn('chats', 'lastActivityAt');
	await queryInterface.removeColumn('chats', 'lastActivityType');
};
