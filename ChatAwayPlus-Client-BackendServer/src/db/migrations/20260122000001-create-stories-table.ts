import { QueryInterface, DataTypes } from 'sequelize';

module.exports = {
  async up(queryInterface: QueryInterface) {
    await queryInterface.createTable('stories', {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
      },
      userId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
          model: 'users',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      mediaUrl: {
        type: DataTypes.TEXT,
        allowNull: false,
        comment: 'S3 URL for story image/video',
      },
      mediaType: {
        type: DataTypes.ENUM('image', 'video'),
        allowNull: false,
        defaultValue: 'image',
      },
      caption: {
        type: DataTypes.TEXT,
        allowNull: true,
        comment: 'Optional caption for the story',
      },
      duration: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 5,
        comment: 'Display duration in seconds',
      },
      viewsCount: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
        allowNull: false,
      },
      expiresAt: {
        type: DataTypes.DATE,
        allowNull: false,
        comment: 'Story expires after 24 hours',
      },
      backgroundColor: {
        type: DataTypes.STRING(20),
        allowNull: true,
        comment: 'Background color for text-only stories',
      },
      createdAt: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      updatedAt: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      deletedAt: {
        type: DataTypes.DATE,
        allowNull: true,
      },
    });

    // Add indexes only if they don't exist (some might already be created)
    const indexes = [
      { fields: ['userId'], name: 'stories_user_id' },
      { fields: ['expiresAt'], name: 'stories_expires_at' },
      { fields: ['createdAt'], name: 'stories_created_at' }
    ];

    for (const index of indexes) {
      try {
        await queryInterface.addIndex('stories', index.fields, {
          name: index.name
        });
      } catch (error: any) {
        if (!error.message.includes('Duplicate key name')) {
          throw error;
        }
      }
    }
  },

  async down(queryInterface: QueryInterface) {
    await queryInterface.dropTable('stories');
  },
};
