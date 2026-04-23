import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';
import User from './user.model';
import Chat from './chat.model';

/**
 * MessageReaction Model - WhatsApp-style message reactions
 *
 * Business Rules:
 * - One reaction per user per message (unique constraint)
 * - Users can change their reaction (update existing)
 * - Users can remove reaction (delete record)
 * - Reactions work with all message types (text, image, pdf)
 */
class MessageReaction extends Model {
	declare id: string;
	declare messageId: string; // Reference to Chat (message)
	declare userId: string; // Who reacted
	declare emoji: string; // The emoji reaction (e.g., "👍", "❤️", "😂")

	declare readonly createdAt: Date;
	declare readonly updatedAt: Date;
}

MessageReaction.init(
	{
		id: {
			type: DataTypes.UUID,
			defaultValue: DataTypes.UUIDV4,
			primaryKey: true,
		},
		messageId: {
			type: DataTypes.UUID,
			allowNull: false,
			references: {
				model: 'chats', // Reference to Chat model
				key: 'id',
			},
			onDelete: 'CASCADE', // Delete reactions when message is deleted
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
		emoji: {
			type: DataTypes.STRING(20), // Support for unicode emojis
			allowNull: false,
			validate: {
				notEmpty: true,
				len: [1, 20]
			}
		},
	},
	{
		sequelize,
		modelName: 'MessageReaction',
		tableName: 'message_reactions',
		timestamps: true,
		indexes: [
			{
				// Ensure one reaction per user per message
				unique: true,
				fields: ['messageId', 'userId'],
				name: 'unique_user_message_reaction'
			},
			{
				// Fast lookup of reactions for a message
				fields: ['messageId']
			},
			{
				// Fast lookup of user's reactions
				fields: ['userId']
			}
		]
	}
);

// Define associations
MessageReaction.belongsTo(Chat, { foreignKey: 'messageId', as: 'message' });
MessageReaction.belongsTo(User, { foreignKey: 'userId', as: 'user' });

export default MessageReaction;
