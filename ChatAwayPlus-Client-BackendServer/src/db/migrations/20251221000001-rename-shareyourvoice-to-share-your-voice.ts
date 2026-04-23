import { QueryInterface, DataTypes } from 'sequelize';

/**
 * Migration to consolidate status tables and add share_your_voice column
 *
 * Current situation:
 * - Two tables exist: 'status' (with statusUrl) and 'statuses' (with content)
 * - Model expects 'status' table with 'share_your_voice' column
 *
 * This migration:
 * 1. Checks which table has data
 * 2. Renames 'content' or 'statusUrl' to 'share_your_voice' in the correct table
 * 3. Ensures the model uses the correct table
 */

module.exports = {
	up: async (queryInterface: QueryInterface) => {
		try {
			// Check if 'status' table exists and its structure
			const statusTableExists = await queryInterface.describeTable('status').catch(() => null);
			const statusesTableExists = await queryInterface.describeTable('statuses').catch(() => null);

			if (statusesTableExists && statusesTableExists.content) {
				console.log('✅ Working with "statuses" table (has content field)');

				// Rename content to share_your_voice in statuses table
				if (!statusesTableExists.share_your_voice) {
					await queryInterface.renameColumn('statuses', 'content', 'share_your_voice');
					console.log('✅ Renamed statuses.content → statuses.share_your_voice');
				}
			} else if (statusTableExists && statusTableExists.statusUrl) {
				console.log('✅ Working with "status" table (has statusUrl field)');

				// Rename statusUrl to share_your_voice in status table
				if (!statusTableExists.share_your_voice) {
					await queryInterface.renameColumn('status', 'statusUrl', 'share_your_voice');
					console.log('✅ Renamed status.statusUrl → status.share_your_voice');
				}
			} else {
				console.log('⚠️ Neither table has content or statusUrl field - may already be migrated');
			}

			console.log('✅ Migration completed successfully');
		} catch (error) {
			console.error('❌ Migration error:', error);
			throw error;
		}
	},

	down: async (queryInterface: QueryInterface) => {
		try {
			// Check which table to revert
			const statusTableExists = await queryInterface.describeTable('status').catch(() => null);
			const statusesTableExists = await queryInterface.describeTable('statuses').catch(() => null);

			if (statusesTableExists && statusesTableExists.share_your_voice) {
				await queryInterface.renameColumn('statuses', 'share_your_voice', 'content');
				console.log('✅ Reverted statuses.share_your_voice → statuses.content');
			} else if (statusTableExists && statusTableExists.share_your_voice) {
				await queryInterface.renameColumn('status', 'share_your_voice', 'statusUrl');
				console.log('✅ Reverted status.share_your_voice → status.statusUrl');
			}
		} catch (error) {
			console.error('❌ Rollback error:', error);
			throw error;
		}
	},
};
