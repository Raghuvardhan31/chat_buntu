import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';
import User from './user.model';

class Story extends Model {
  declare id: string;
  declare userId: string;
  declare mediaUrl: string;
  declare mediaType: 'image' | 'video';
  declare thumbnailUrl: string | null;
  declare videoDuration: number | null;
  declare caption: string | null;
  declare duration: number;
  declare viewsCount: number;
  declare expiresAt: Date;
  declare backgroundColor: string | null;
  declare readonly createdAt: Date;
  declare readonly updatedAt: Date;
  declare readonly deletedAt: Date | null;
}

Story.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: User,
        key: 'id',
      },
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
    thumbnailUrl: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'S3 URL for video thumbnail image',
    },
    videoDuration: {
      type: DataTypes.FLOAT,
      allowNull: true,
      comment: 'Actual video duration in seconds (null for images)',
    },
    backgroundColor: {
      type: DataTypes.STRING(20),
      allowNull: true,
      comment: 'Background color for text-only stories',
    },
    deletedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    sequelize,
    modelName: 'Story',
    tableName: 'stories',
    timestamps: true,
    paranoid: true,
    indexes: [
      {
        fields: ['userId'],
      },
      {
        fields: ['expiresAt'],
      },
      {
        fields: ['createdAt'],
      },
    ],
  }
);

// Define associations
setTimeout(() => {
  const StoryView = require('./story-view.model').default;
  Story.belongsTo(User, { foreignKey: 'userId', as: 'user' });
  Story.hasMany(StoryView, { foreignKey: 'storyId', as: 'views' });
}, 0);

export default Story;
