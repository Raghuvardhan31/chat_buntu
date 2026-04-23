import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';

class ChatPictureLike extends Model { }

ChatPictureLike.init(
	{
		id: {
			type: DataTypes.UUID,
			defaultValue: DataTypes.UUIDV4,
			allowNull: false,
			primaryKey: true,
		},
		userId: {
			type: DataTypes.UUID,
			allowNull: false,
			references: {
				model: 'users',
				key: 'id',
			},
			onDelete: 'CASCADE',
		},
		likedUserId: {
			type: DataTypes.UUID,
			allowNull: false,
			references: {
				model: 'users',
				key: 'id',
			},
			onDelete: 'CASCADE',
		},
		target_chat_picture_id: {
			type: DataTypes.STRING,
			allowNull: false,
			comment: 'ID/version of the chat picture that was liked',
			field: 'target_chat_picture_id',
		},
	},
	{
		sequelize,
		tableName: 'profile_likes',
		timestamps: true,
		indexes: [
			{
				unique: true,
				fields: ['userId', 'likedUserId', 'target_chat_picture_id'],
				name: 'unique_user_liked_user_pic',
			},
			{
				fields: ['likedUserId'],
			},
			{
				fields: ['target_chat_picture_id'],
			},
		],
	}
);

// Define associations
const User = require('./user.model').default;

ChatPictureLike.belongsTo(User, {
	foreignKey: 'userId',
	as: 'userWhoLiked',
});

ChatPictureLike.belongsTo(User, {
	foreignKey: 'likedUserId',
	as: 'likedUser',
});

export default ChatPictureLike;
