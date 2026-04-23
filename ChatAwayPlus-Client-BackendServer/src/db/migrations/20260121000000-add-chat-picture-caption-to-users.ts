import { QueryInterface, DataTypes } from "sequelize";

module.exports = {
	up: async (queryInterface: QueryInterface): Promise<void> => {
		await queryInterface.addColumn("users", "chat_picture_caption", {
			type: DataTypes.TEXT,
			allowNull: true,
			comment: "Caption/description for the profile picture",
		});

		console.log(
			"✅ Successfully added chat_picture_caption column to users table",
		);
	},

	down: async (queryInterface: QueryInterface): Promise<void> => {
		await queryInterface.removeColumn("users", "chat_picture_caption");
		console.log(
			"✅ Successfully removed chat_picture_caption column from users table",
		);
	},
};
