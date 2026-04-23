import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
  async up(queryInterface: QueryInterface) {
    await queryInterface.createTable('story_views', {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      storyId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
          model: 'stories',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      viewerId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
          model: 'users',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      viewedAt: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
    });

    // Add indexes only if they don't exist
    const indexes = [
      { fields: ['storyId', 'viewerId'], name: 'unique_story_viewer', unique: true },
      { fields: ['storyId'], name: 'story_views_story_id' },
      { fields: ['viewerId'], name: 'story_views_viewer_id' }
    ];

    for (const index of indexes) {
      try {
        await queryInterface.addIndex('story_views', index.fields, {
          name: index.name,
          unique: index.unique || false
        });
      } catch (error: any) {
        if (!error.message.includes('Duplicate key name')) {
          throw error;
        }
      }
    }
  },

  async down(queryInterface: QueryInterface) {
    await queryInterface.dropTable('story_views');
  },
};
