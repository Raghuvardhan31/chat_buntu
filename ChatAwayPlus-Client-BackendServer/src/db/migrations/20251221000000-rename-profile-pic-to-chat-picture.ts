import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	up: async (queryInterface: QueryInterface) => {
		const tableDescription = await queryInterface.describeTable('users');

		// Rename profile_pic to chat_picture
		if (tableDescription.profile_pic && !tableDescription.chat_picture) {
			await queryInterface.renameColumn('users', 'profile_pic', 'chat_picture');
		}

		// Rename profilePicVersion to chat_picture_version
		if (tableDescription.profilePicVersion && !tableDescription.chat_picture_version) {
			await queryInterface.renameColumn('users', 'profilePicVersion', 'chat_picture_version');
		}
	},

	down: async (queryInterface: QueryInterface) => {
		const tableDescription = await queryInterface.describeTable('users');

		// Revert chat_picture to profile_pic
		if (tableDescription.chat_picture && !tableDescription.profile_pic) {
			await queryInterface.renameColumn('users', 'chat_picture', 'profile_pic');
		}

		// Revert chat_picture_version to profilePicVersion
		if (tableDescription.chat_picture_version && !tableDescription.profilePicVersion) {
			await queryInterface.renameColumn('users', 'chat_picture_version', 'profilePicVersion');
		}
	},
};
