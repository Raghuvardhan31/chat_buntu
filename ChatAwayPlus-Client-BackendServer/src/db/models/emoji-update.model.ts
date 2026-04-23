import { Model, DataTypes } from 'sequelize';

import sequelize from '../config/database';

class EmojiUpdate extends Model {
	declare id: string;
	declare userId: string;
	declare emojis_update: string;
	declare emojis_caption?: string;
	declare readonly createdAt: Date;
	declare readonly updatedAt: Date;
	declare readonly deletedAt: Date | null;
}

EmojiUpdate.init(
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
		},
		emojis_update: {
			type: DataTypes.STRING(50),
			allowNull: false,
			validate: {
				notEmpty: true,
				len: [1, 50]
			}
		},
		emojis_caption: {
			type: DataTypes.TEXT,
			allowNull: true,
		},
		deletedAt: {
			type: DataTypes.DATE,
			allowNull: true,
			defaultValue: null,
		}
	},
	{
		sequelize,
		modelName: 'EmojiUpdate',
		tableName: 'emoji_updates',
		timestamps: true,
		paranoid: true, // Enable soft deletes
	}
);

// Define associations after all models are defined
setTimeout(() => {
	const User = require('./user.model').default;
	EmojiUpdate.belongsTo(User, { foreignKey: 'userId' });
}, 0);

export default EmojiUpdate;
