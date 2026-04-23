import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
	async up(queryInterface: QueryInterface) {
		await queryInterface.addColumn('chats', 'videoThumbnailUrl', {
			type: DataTypes.TEXT,
			allowNull: true,
			comment: 'S3 URL for video thumbnail image',
		});

		await queryInterface.addColumn('chats', 'videoDuration', {
			type: DataTypes.FLOAT,
			allowNull: true,
			comment: 'Actual video duration in seconds (null for non-video messages)',
		});

		// Add index for faster lookups of video messages
		await queryInterface.addIndex('chats', ['messageType'], {
			name: 'idx_chats_message_type',
			where: {
				messageType: 'video',
			},
		});
	},

	async down(queryInterface: QueryInterface) {
		await queryInterface.removeIndex('chats', 'idx_chats_message_type');
		await queryInterface.removeColumn('chats', 'videoDuration');
		await queryInterface.removeColumn('chats', 'videoThumbnailUrl');
	},
};
