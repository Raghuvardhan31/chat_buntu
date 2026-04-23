import { DataTypes, Model, Optional } from "sequelize";
import sequelize from "../config/database";
import User from "./user.model";

export interface CallLogAttributes {
	id: string;
	callId: string;
	callerId: string;
	calleeId: string;
	callType: "voice" | "video";
	status:
	| "initiated"
	| "ringing"
	| "accepted"
	| "rejected"
	| "missed"
	| "ended"
	| "busy"
	| "unavailable";
	channelName: string;
	startedAt: Date;
	answeredAt?: Date | null;
	endedAt?: Date | null;
	duration?: number | null; // in seconds
	endedBy?: string | null;
	createdAt?: Date;
	updatedAt?: Date;
}

export interface CallLogCreationAttributes
	extends Optional<
		CallLogAttributes,
		| "id"
		| "answeredAt"
		| "endedAt"
		| "duration"
		| "endedBy"
		| "createdAt"
		| "updatedAt"
	> { }

class CallLog
	extends Model<CallLogAttributes, CallLogCreationAttributes>
	implements CallLogAttributes {
	public id!: string;
	public callId!: string;
	public callerId!: string;
	public calleeId!: string;
	public callType!: "voice" | "video";
	public status!:
		| "initiated"
		| "ringing"
		| "accepted"
		| "rejected"
		| "missed"
		| "ended"
		| "busy"
		| "unavailable";
	public channelName!: string;
	public startedAt!: Date;
	public answeredAt!: Date | null;
	public endedAt!: Date | null;
	public duration!: number | null;
	public endedBy!: string | null;

	public readonly createdAt!: Date;
	public readonly updatedAt!: Date;

	// Association properties (populated when included in queries)
	public readonly caller?: User;
	public readonly callee?: User;
	public readonly ender?: User;
}

CallLog.init(
	{
		id: {
			type: DataTypes.CHAR(36),
			defaultValue: DataTypes.UUIDV4,
			primaryKey: true,
		},
		callId: {
			type: DataTypes.STRING,
			allowNull: false,
			unique: true,
			comment: "Unique identifier for the call session",
		},
		callerId: {
			type: DataTypes.CHAR(36),
			allowNull: false,
			references: {
				model: "users",
				key: "id",
			},
			comment: "User who initiated the call",
		},
		calleeId: {
			type: DataTypes.CHAR(36),
			allowNull: false,
			references: {
				model: "users",
				key: "id",
			},
			comment: "User who received the call",
		},
		callType: {
			type: DataTypes.ENUM("voice", "video"),
			allowNull: false,
			comment: "Type of call: voice or video",
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
		},
		startedAt: {
			type: DataTypes.DATE,
			allowNull: false,
			defaultValue: DataTypes.NOW,
			comment: "When the call was initiated",
		},
		answeredAt: {
			type: DataTypes.DATE,
			allowNull: true,
			comment: "When the call was answered",
		},
		endedAt: {
			type: DataTypes.DATE,
			allowNull: true,
			comment: "When the call ended",
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
			comment: "User who ended the call",
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
	},
	{
		sequelize,
		tableName: "call_logs",
		timestamps: true,
		indexes: [
			{
				fields: ["callerId"],
				name: "idx_call_logs_caller_id",
			},
			{
				fields: ["calleeId"],
				name: "idx_call_logs_callee_id",
			},
			{
				fields: ["callId"],
				name: "idx_call_logs_call_id",
				unique: true,
			},
			{
				fields: ["status"],
				name: "idx_call_logs_status",
			},
			{
				fields: ["startedAt"],
				name: "idx_call_logs_started_at",
			},
		],
	}
);

export default CallLog;
