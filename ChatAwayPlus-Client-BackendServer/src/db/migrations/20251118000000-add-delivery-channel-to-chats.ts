import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	up: async (queryInterface: QueryInterface) => {
		const tableDescription = await queryInterface.describeTable('chats');

		// Add deliveryChannel field to track whether message was sent via socket or FCM
		if (!tableDescription.deliveryChannel) {
			await queryInterface.addColumn('chats', 'deliveryChannel', {
				type: DataTypes.ENUM('socket', 'fcm'),
				allowNull: false,
				defaultValue: 'socket',
				comment: 'Indicates whether the message was delivered via WebSocket or FCM push notification'
			});

			// Add index for better query performance on delivery channel filtering
			await queryInterface.addIndex('chats', ['deliveryChannel']);
		}
	},

	down: async (queryInterface: QueryInterface) => {
		// Remove index first
		await queryInterface.removeIndex('chats', ['deliveryChannel']);

		// Remove the column
		await queryInterface.removeColumn('chats', 'deliveryChannel');

		// Remove the ENUM type
		await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_chats_deliveryChannel";');
	},
};
