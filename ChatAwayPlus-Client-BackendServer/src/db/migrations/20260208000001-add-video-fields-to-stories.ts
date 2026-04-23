import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
  async up(queryInterface: QueryInterface) {
    await queryInterface.addColumn('stories', 'thumbnailUrl', {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'S3 URL for video thumbnail image',
    });

    await queryInterface.addColumn('stories', 'videoDuration', {
      type: DataTypes.FLOAT,
      allowNull: true,
      comment: 'Actual video duration in seconds (null for images)',
    });
  },

  async down(queryInterface: QueryInterface) {
    await queryInterface.removeColumn('stories', 'thumbnailUrl');
    await queryInterface.removeColumn('stories', 'videoDuration');
  },
};
