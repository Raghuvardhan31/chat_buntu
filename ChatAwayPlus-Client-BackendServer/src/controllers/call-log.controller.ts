import { Request, Response } from "express";
import { Op } from "sequelize";
import CallLog from "../db/models/call-log.model";
import User from "../db/models/user.model";

/**
 * Get call history for a user (both incoming and outgoing calls)
 * @route GET /api/call-logs/history/:userId
 */
export const getCallHistory = async (req: Request, res: Response) => {
	try {
		const { userId } = req.params;
		const { limit = 50, offset = 0, callType, status } = req.query;

		// Build filter conditions
		const whereConditions: any = {
			[Op.or]: [{ callerId: userId }, { calleeId: userId }],
		};

		if (callType && (callType === "voice" || callType === "video")) {
			whereConditions.callType = callType;
		}

		if (status) {
			whereConditions.status = status;
		}

		const callLogs = await CallLog.findAll({
			where: whereConditions,
			include: [
				{
					model: User,
					as: "caller",
					attributes: ["id", "firstName", "lastName", "chat_picture", "mobileNo"],
				},
				{
					model: User,
					as: "callee",
					attributes: ["id", "firstName", "lastName", "chat_picture", "mobileNo"],
				},
			],
			order: [["startedAt", "DESC"]],
			limit: parseInt(limit as string),
			offset: parseInt(offset as string),
		});

		// Format response to include call direction
		const formattedLogs = callLogs.map((log: any) => {
			const isOutgoing = log.callerId === userId;
			const otherUser = isOutgoing ? log.callee : log.caller;

			return {
				id: log.id,
				callId: log.callId,
				callType: log.callType,
				status: log.status,
				direction: isOutgoing ? "outgoing" : "incoming",
				otherUser: {
					id: otherUser?.id,
					name: `${otherUser?.firstName || ""} ${otherUser?.lastName || ""}`.trim(),
					profilePicture: otherUser?.chat_picture,
					mobileNo: otherUser?.mobileNo,
				},
				startedAt: log.startedAt,
				answeredAt: log.answeredAt,
				endedAt: log.endedAt,
				duration: log.duration,
				channelName: log.channelName,
			};
		});

		res.json({
			success: true,
			data: formattedLogs,
			pagination: {
				limit: parseInt(limit as string),
				offset: parseInt(offset as string),
				total: await CallLog.count({ where: whereConditions }),
			},
		});
	} catch (error) {
		console.error("Error fetching call history:", error);
		res.status(500).json({
			success: false,
			error: "Failed to fetch call history",
		});
	}
};

/**
 * Get missed calls count for a user
 * @route GET /api/call-logs/missed-count/:userId
 */
export const getMissedCallsCount = async (req: Request, res: Response) => {
	try {
		const { userId } = req.params;

		const missedCount = await CallLog.count({
			where: {
				calleeId: userId, // Only incoming calls
				status: "missed",
			},
		});

		res.json({
			success: true,
			data: {
				missedCallsCount: missedCount,
			},
		});
	} catch (error) {
		console.error("Error fetching missed calls count:", error);
		res.status(500).json({
			success: false,
			error: "Failed to fetch missed calls count",
		});
	}
};

/**
 * Get missed calls for a user
 * @route GET /api/call-logs/missed/:userId
 */
export const getMissedCalls = async (req: Request, res: Response) => {
	try {
		const { userId } = req.params;
		const { limit = 50, offset = 0 } = req.query;

		const missedCalls = await CallLog.findAll({
			where: {
				calleeId: userId, // Only incoming calls
				status: "missed",
			},
			include: [
				{
					model: User,
					as: "caller",
					attributes: ["id", "firstName", "lastName", "chat_picture", "mobileNo"],
				},
			],
			order: [["startedAt", "DESC"]],
			limit: parseInt(limit as string),
			offset: parseInt(offset as string),
		});

		const formattedCalls = missedCalls.map((log: any) => ({
			id: log.id,
			callId: log.callId,
			callType: log.callType,
			status: log.status,
			caller: {
				id: log.caller?.id,
				name: `${log.caller?.firstName || ""} ${log.caller?.lastName || ""}`.trim(),
				profilePicture: log.caller?.chat_picture,
				mobileNo: log.caller?.mobileNo,
			},
			startedAt: log.startedAt,
			channelName: log.channelName,
		}));

		res.json({
			success: true,
			data: formattedCalls,
			pagination: {
				limit: parseInt(limit as string),
				offset: parseInt(offset as string),
				total: await CallLog.count({
					where: { calleeId: userId, status: "missed" },
				}),
			},
		});
	} catch (error) {
		console.error("Error fetching missed calls:", error);
		res.status(500).json({
			success: false,
			error: "Failed to fetch missed calls",
		});
	}
};

/**
 * Get call details by callId
 * @route GET /api/call-logs/details/:callId
 */
export const getCallDetails = async (req: Request, res: Response) => {
	try {
		const { callId } = req.params;

		const callLog = await CallLog.findOne({
			where: { callId },
			include: [
				{
					model: User,
					as: "caller",
					attributes: ["id", "firstName", "lastName", "chat_picture", "mobileNo"],
				},
				{
					model: User,
					as: "callee",
					attributes: ["id", "firstName", "lastName", "chat_picture", "mobileNo"],
				},
				{
					model: User,
					as: "ender",
					attributes: ["id", "firstName", "lastName"],
					required: false,
				},
			],
		});

		if (!callLog) {
			return res.status(404).json({
				success: false,
				error: "Call log not found",
			});
		}

		const logData: any = callLog;

		res.json({
			success: true,
			data: {
				id: logData.id,
				callId: logData.callId,
				callType: logData.callType,
				status: logData.status,
				caller: {
					id: logData.caller?.id,
					name: `${logData.caller?.firstName || ""} ${logData.caller?.lastName || ""}`.trim(),
					profilePicture: logData.caller?.chat_picture,
					mobileNo: logData.caller?.mobileNo,
				},
				callee: {
					id: logData.callee?.id,
					name: `${logData.callee?.firstName || ""} ${logData.callee?.lastName || ""}`.trim(),
					profilePicture: logData.callee?.chat_picture,
					mobileNo: logData.callee?.mobileNo,
				},
				ender: logData.ender
					? {
						id: logData.ender.id,
						name: `${logData.ender.firstName || ""} ${logData.ender.lastName || ""}`.trim(),
					}
					: null,
				startedAt: logData.startedAt,
				answeredAt: logData.answeredAt,
				endedAt: logData.endedAt,
				duration: logData.duration,
				channelName: logData.channelName,
			},
		});
	} catch (error) {
		console.error("Error fetching call details:", error);
		res.status(500).json({
			success: false,
			error: "Failed to fetch call details",
		});
	}
};

/**
 * Delete call history for a user (specific call or all calls)
 * @route DELETE /api/call-logs/:userId
 */
export const deleteCallHistory = async (req: Request, res: Response) => {
	try {
		const { userId } = req.params;
		const { callId, deleteAll } = req.body;

		if (deleteAll) {
			// Delete all call history for the user
			await CallLog.destroy({
				where: {
					[Op.or]: [{ callerId: userId }, { calleeId: userId }],
				},
			});

			return res.json({
				success: true,
				message: "All call history deleted successfully",
			});
		} else if (callId) {
			// Delete specific call
			const result = await CallLog.destroy({
				where: {
					callId,
					[Op.or]: [{ callerId: userId }, { calleeId: userId }],
				},
			});

			if (result === 0) {
				return res.status(404).json({
					success: false,
					error: "Call log not found or you don't have permission to delete it",
				});
			}

			return res.json({
				success: true,
				message: "Call log deleted successfully",
			});
		} else {
			return res.status(400).json({
				success: false,
				error: "Either callId or deleteAll flag must be provided",
			});
		}
	} catch (error) {
		console.error("Error deleting call history:", error);
		res.status(500).json({
			success: false,
			error: "Failed to delete call history",
		});
	}
};

/**
 * Get call statistics for a user
 * @route GET /api/call-logs/statistics/:userId
 */
export const getCallStatistics = async (req: Request, res: Response) => {
	try {
		const { userId } = req.params;
		const { startDate, endDate } = req.query;

		const whereConditions: any = {
			[Op.or]: [{ callerId: userId }, { calleeId: userId }],
		};

		if (startDate && endDate) {
			whereConditions.startedAt = {
				[Op.between]: [new Date(startDate as string), new Date(endDate as string)],
			};
		}

		// Get total calls
		const totalCalls = await CallLog.count({ where: whereConditions });

		// Get outgoing calls
		const outgoingCalls = await CallLog.count({
			where: { ...whereConditions, callerId: userId },
		});

		// Get incoming calls
		const incomingCalls = await CallLog.count({
			where: { ...whereConditions, calleeId: userId },
		});

		// Get calls by status
		const missedCalls = await CallLog.count({
			where: { ...whereConditions, status: "missed" },
		});

		const answeredCalls = await CallLog.count({
			where: { ...whereConditions, status: { [Op.in]: ["accepted", "ended"] } },
		});

		const rejectedCalls = await CallLog.count({
			where: { ...whereConditions, status: { [Op.in]: ["rejected", "busy"] } },
		});

		// Get calls by type
		const voiceCalls = await CallLog.count({
			where: { ...whereConditions, callType: "voice" },
		});

		const videoCalls = await CallLog.count({
			where: { ...whereConditions, callType: "video" },
		});

		// Calculate total call duration
		const callsWithDuration = await CallLog.findAll({
			where: { ...whereConditions, duration: { [Op.not]: null } },
			attributes: ["duration"],
		});

		const totalDuration = callsWithDuration.reduce(
			(sum, call) => sum + (call.duration || 0),
			0
		);

		const averageDuration =
			callsWithDuration.length > 0
				? Math.round(totalDuration / callsWithDuration.length)
				: 0;

		res.json({
			success: true,
			data: {
				totalCalls,
				outgoingCalls,
				incomingCalls,
				callsByStatus: {
					answered: answeredCalls,
					missed: missedCalls,
					rejected: rejectedCalls,
				},
				callsByType: {
					voice: voiceCalls,
					video: videoCalls,
				},
				duration: {
					total: totalDuration, // in seconds
					average: averageDuration, // in seconds
					totalHours: (totalDuration / 3600).toFixed(2),
				},
			},
		});
	} catch (error) {
		console.error("Error fetching call statistics:", error);
		res.status(500).json({
			success: false,
			error: "Failed to fetch call statistics",
		});
	}
};
