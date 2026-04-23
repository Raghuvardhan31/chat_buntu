import { QueryInterface, DataTypes } from 'sequelize';

export const up = async (queryInterface: QueryInterface): Promise<void> => {
	await queryInterface.createTable('fcm_device_tokens', {
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
			type: DataTypes.TEXT,
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
		},
		createdAt: {
			type: DataTypes.DATE,
			allowNull: false,
			defaultValue: DataTypes.NOW
		},
		updatedAt: {
			type: DataTypes.DATE,
			allowNull: false,
			defaultValue: DataTypes.NOW
		}
	});

	// Create unique index on userId + deviceId
	await queryInterface.addIndex('fcm_device_tokens', ['userId', 'deviceId'], {
		unique: true,
		name: 'unique_user_device'
	});

	// Create index for querying active tokens by user
	await queryInterface.addIndex('fcm_device_tokens', ['userId', 'isActive'], {
		name: 'idx_user_active_tokens'
	});

	// Create index for fcmToken lookups
	await queryInterface.addIndex('fcm_device_tokens', ['fcmToken'], {
		name: 'idx_fcm_token'
	});
};

export const down = async (queryInterface: QueryInterface): Promise<void> => {
	await queryInterface.dropTable('fcm_device_tokens');
};
