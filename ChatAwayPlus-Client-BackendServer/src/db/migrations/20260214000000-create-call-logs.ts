import { QueryInterface, DataTypes } from "sequelize";

export default {
	up: async (queryInterface: QueryInterface): Promise<void> => {
		await queryInterface.createTable("call_logs", {
			id: {
				type: DataTypes.CHAR(36),
				defaultValue: DataTypes.UUIDV4,
				primaryKey: true,
				allowNull: false,
			},
			callId: {
				type: DataTypes.STRING,
				allowNull: false,
				unique: true,
				comment: "Unique identifier for the call session",
				field: "call_id",
			},
			callerId: {
				type: DataTypes.CHAR(36),
				allowNull: false,
				references: {
					model: "users",
					key: "id",
				},
				onUpdate: "CASCADE",
				onDelete: "CASCADE",
				comment: "User who initiated the call",
				field: "caller_id",
			},
			calleeId: {
				type: DataTypes.CHAR(36),
				allowNull: false,
				references: {
					model: "users",
					key: "id",
				},
				onUpdate: "CASCADE",
				onDelete: "CASCADE",
				comment: "User who received the call",
				field: "callee_id",
			},
			callType: {
				type: DataTypes.ENUM("voice", "video"),
				allowNull: false,
				comment: "Type of call: voice or video",
				field: "call_type",
			},
			status: {
				type: DataTypes.ENUM(
					"initiated",
					"ringing",
					"accepted",
					"rejected",
					"missed",
					"ended",
					"busy",
					"unavailable"
				),
				allowNull: false,
				defaultValue: "initiated",
				comment: "Current status of the call",
			},
			channelName: {
				type: DataTypes.STRING,
				allowNull: false,
				comment: "Agora channel name for the call",
				field: "channel_name",
			},
			startedAt: {
				type: DataTypes.DATE,
				allowNull: false,
				defaultValue: DataTypes.NOW,
				comment: "When the call was initiated",
				field: "started_at",
			},
			answeredAt: {
				type: DataTypes.DATE,
				allowNull: true,
				comment: "When the call was answered",
				field: "answered_at",
			},
			endedAt: {
				type: DataTypes.DATE,
				allowNull: true,
				comment: "When the call ended",
				field: "ended_at",
			},
			duration: {
				type: DataTypes.INTEGER,
				allowNull: true,
				comment: "Call duration in seconds (only if answered)",
			},
			endedBy: {
				type: DataTypes.CHAR(36),
				allowNull: true,
				references: {
					model: "users",
					key: "id",
				},
				onUpdate: "CASCADE",
				onDelete: "SET NULL",
				comment: "User who ended the call",
				field: "ended_by",
			},
			createdAt: {
				type: DataTypes.DATE,
				allowNull: false,
				defaultValue: DataTypes.NOW,
				field: "created_at",
			},
			updatedAt: {
				type: DataTypes.DATE,
				allowNull: false,
				defaultValue: DataTypes.NOW,
				field: "updated_at",
			},
		});

		// Create indexes
		await queryInterface.addIndex("call_logs", ["caller_id"], {
			name: "idx_call_logs_caller_id",
		});

		await queryInterface.addIndex("call_logs", ["callee_id"], {
			name: "idx_call_logs_callee_id",
		});

		await queryInterface.addIndex("call_logs", ["call_id"], {
			name: "idx_call_logs_call_id",
			unique: true,
		});

		await queryInterface.addIndex("call_logs", ["status"], {
			name: "idx_call_logs_status",
		});

		await queryInterface.addIndex("call_logs", ["started_at"], {
			name: "idx_call_logs_started_at",
		});
	},

	down: async (queryInterface: QueryInterface): Promise<void> => {
		await queryInterface.dropTable("call_logs");
	},
};
