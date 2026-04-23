import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';
import User from './user.model';
import Story from './story.model';

class StoryView extends Model {
  declare id: string;
  declare storyId: string;
  declare viewerId: string;
  declare viewedAt: Date;
}

StoryView.init(
  {
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
      onDelete: 'CASCADE',
    },
    viewerId: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: User,
        key: 'id',
      },
    },
    viewedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    sequelize,
    modelName: 'StoryView',
    tableName: 'story_views',
    timestamps: false,
    indexes: [
      {
        unique: true,
        fields: ['storyId', 'viewerId'],
        name: 'unique_story_viewer',
      },
      {
        fields: ['storyId'],
      },
      {
        fields: ['viewerId'],
      },
    ],
  }
);

// Define associations
StoryView.belongsTo(Story, { foreignKey: 'storyId', as: 'story' });
StoryView.belongsTo(User, { foreignKey: 'viewerId', as: 'viewer' });

export default StoryView;
