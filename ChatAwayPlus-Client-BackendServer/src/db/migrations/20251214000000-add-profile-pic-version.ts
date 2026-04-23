import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	up: async (queryInterface: QueryInterface) => {
		const tableDescription = await queryInterface.describeTable('users');

		// Add profilePicVersion column to users table
		if (!tableDescription.profilePicVersion) {
			await queryInterface.addColumn('users', 'profilePicVersion', {
				type: DataTypes.STRING,
				allowNull: true,
				comment: 'Version/ID of current profile picture for like tracking',
			});

			// Generate initial profilePicVersion for users who already have profile pictures
			await queryInterface.sequelize.query(`
				UPDATE users
				SET profilePicVersion = UUID()
				WHERE profile_pic IS NOT NULL AND profilePicVersion IS NULL
			`);
		}
	},

	down: async (queryInterface: QueryInterface) => {
		await queryInterface.removeColumn('users', 'profilePicVersion');
	},
};
