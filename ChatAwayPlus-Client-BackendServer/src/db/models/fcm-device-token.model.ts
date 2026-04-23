import { Model, DataTypes } from 'sequelize';
import sequelize from '../config/database';

class FcmDeviceToken extends Model {
	declare id: string;
	declare userId: string;
	declare deviceId: string;
	declare fcmToken: string;
	declare platform: 'android' | 'ios' | 'web';
	declare appVersion?: string;
	declare lastSeenAt: Date;
	declare isActive: boolean;
	declare readonly createdAt: Date;
	declare readonly updatedAt: Date;
}

FcmDeviceToken.init(
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
				key: 'id'
			},
			onDelete: 'CASCADE'
		},
		deviceId: {
			type: DataTypes.STRING,
			allowNull: false,
			comment: 'Stable device identifier (per install/device)'
		},
		fcmToken: {
			type: DataTypes.STRING(255),
			allowNull: false,
			comment: 'Firebase Cloud Messaging token'
		},
		platform: {
			type: DataTypes.ENUM('android', 'ios', 'web'),
			allowNull: false
		},
		appVersion: {
			type: DataTypes.STRING,
			allowNull: true,
			comment: 'App version for debugging'
		},
		lastSeenAt: {
			type: DataTypes.DATE,
			allowNull: false,
			defaultValue: DataTypes.NOW,
			comment: 'Last time this device updated its token'
		},
		isActive: {
			type: DataTypes.BOOLEAN,
			allowNull: false,
			defaultValue: true,
			comment: 'Set to false when token is invalid/expired'
		}
	},
	{
		sequelize,
		modelName: 'FcmDeviceToken',
		tableName: 'fcm_device_tokens',
		timestamps: true,
		indexes: [
			{
				unique: true,
				fields: ['userId', 'deviceId'],
				name: 'unique_user_device'
			},
			{
				fields: ['userId', 'isActive'],
				name: 'idx_user_active_tokens'
			},
			{
				fields: ['fcmToken'],
				name: 'idx_fcm_token'
			}
		]
	}
);

// Define associations after all models are defined
setTimeout(() => {
	const User = require('./user.model').default;
	FcmDeviceToken.belongsTo(User, { foreignKey: 'userId', as: 'user' });
}, 0);

export default FcmDeviceToken;
