import { Router } from "express";
import {
	getCallHistory,
	getMissedCallsCount,
	getMissedCalls,
	getCallDetails,
	deleteCallHistory,
	getCallStatistics,
} from "../controllers/call-log.controller";
import { authMiddleware } from "../middlewares/auth.middleware"

const router = Router();

// All routes require authentication
router.use(authMiddleware);

/**
 * @route   GET /api/call-logs/history/:userId
 * @desc    Get call history for a user (both incoming and outgoing)
 * @query   limit, offset, callType (voice|video), status
 * @access  Private
 */
router.get("/history/:userId", getCallHistory);

/**
 * @route   GET /api/call-logs/missed-count/:userId
 * @desc    Get count of missed calls for a user
 * @access  Private
 */
router.get("/missed-count/:userId", getMissedCallsCount);

/**
 * @route   GET /api/call-logs/missed/:userId
 * @desc    Get list of missed calls for a user
 * @query   limit, offset
 * @access  Private
 */
router.get("/missed/:userId", getMissedCalls);

/**
 * @route   GET /api/call-logs/details/:callId
 * @desc    Get detailed information about a specific call
 * @access  Private
 */
router.get("/details/:callId", getCallDetails);

/**
 * @route   GET /api/call-logs/statistics/:userId
 * @desc    Get call statistics for a user
 * @query   startDate, endDate (optional date range)
 * @access  Private
 */
router.get("/statistics/:userId", getCallStatistics);

/**
 * @route   DELETE /api/call-logs/:userId
 * @desc    Delete call history (specific call or all calls)
 * @body    { callId?: string, deleteAll?: boolean }
 * @access  Private
 */
router.delete("/:userId", deleteCallHistory);

export default router;
