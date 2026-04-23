import { QueryInterface } from "sequelize";

export default {
	up: async (queryInterface: QueryInterface) => {
		const tableDescription =
			await queryInterface.describeTable("emoji_updates");

		// Rename emoji column to emojis_update (only if emoji exists and emojis_update doesn't)
		if (tableDescription.emoji && !tableDescription.emojis_update) {
			await queryInterface.renameColumn(
				"emoji_updates",
				"emoji",
				"emojis_update",
			);
		}

		// Rename caption column to emojis_caption (only if caption exists and emojis_caption doesn't)
		if (tableDescription.caption && !tableDescription.emojis_caption) {
			await queryInterface.renameColumn(
				"emoji_updates",
				"caption",
				"emojis_caption",
			);
		}
	},

	down: async (queryInterface: QueryInterface) => {
		const tableDescription =
			await queryInterface.describeTable("emoji_updates");

		// Revert: rename emojis_update back to emoji
		if (tableDescription.emojis_update && !tableDescription.emoji) {
			await queryInterface.renameColumn(
				"emoji_updates",
				"emojis_update",
				"emoji",
			);
		}

		// Revert: rename emojis_caption back to caption
		if (tableDescription.emojis_caption && !tableDescription.caption) {
			await queryInterface.renameColumn(
				"emoji_updates",
				"emojis_caption",
				"caption",
			);
		}
	},
};
