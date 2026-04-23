import { Request, Response } from 'express';
import { Op, QueryTypes } from 'sequelize';
import Chat from '../db/models/chat.model';
import User from '../db/models/user.model';
import StarredMessage from '../db/models/starred-message.model';
import ChatController from './chat.controller';
import { raw } from 'mysql2';
import { sendDataMessage, sendChatMessageToUser } from '../services/fcm.service';
import { getById } from '../services/user.service';

interface AuthenticatedRequest extends Request {
	user?: {
		id: string;
		email: string;
		mobileNo?: string;
		firstName?: string;
		lastName?: string;
	};
}

class MobileChatController {
	private chatController?: ChatController;

	constructor(chatController?: ChatController) {
		this.chatController = chatController;
	}
	/**
	 * Send a message via REST API (for mobile apps when WebSocket is not available)
	 */
	async sendMessage(req: AuthenticatedRequest, res: Response) {
		try {
			const { receiverId, message, messageType, fileUrl, mimeType, contactPayload, imageWidth, imageHeight, audioDuration, videoThumbnailUrl, videoDuration, replyToMessageId } = req.body;
			const senderId = req.user?.id;

			if (!senderId) {
				return res.status(401).json({ error: 'User not authenticated' });
			}

			if (!receiverId) {
				return res.status(400).json({
					error: 'Missing required fields: receiverId'
				});
			}

			if (!messageType) {
				return res.status(400).json({ error: 'Message type is required' });
			}

			if (messageType === "text" && (!message || message.trim().length === 0)) {
				return res.status(400).json({ error: 'Message cannot be empty' });
			}

			if ((messageType === "image" || messageType === "pdf" || messageType === "video" || messageType === "audio") && !fileUrl) {
				return res.status(400).json({ error: 'File URL is required' });
			}

			if (messageType === "contact" && !contactPayload || contactPayload && contactPayload.length === 0) {
				return res.status(400).json({ error: 'Contact payload is required' });
			}

			// Validate receiver exists
			const receiver = await User.findByPk(receiverId);
			if (!receiver) {
				return res.status(404).json({ error: 'Receiver not found' });
			}

			// Get sender and receiver details
			const sender = await getById(senderId);
			let receiverMetadata: any = {};
			try {
				receiverMetadata = JSON.parse(receiver?.metadata || '{}');
			} catch (error) {
				console.error('❌ Error parsing receiver metadata for FCM (REST):', {
					receiverId,
					error
				});
				receiverMetadata = {};
			}
			// Need to review

			// Auto-populate reply preview fields if replying to a message
			let replyToMessageText: string | null = null;
			let replyToMessageSenderId: string | null = null;
			let replyToMessageType: 'text' | 'image' | 'pdf' | 'video' | 'audio' | 'contact' | 'poll' | 'location' | null = null;

			if (replyToMessageId) {
				try {
					const repliedMessage = await Chat.findByPk(replyToMessageId, {
						attributes: ['message', 'senderId', 'messageType']
					});
					if (repliedMessage) {
						replyToMessageText = repliedMessage.message;
						replyToMessageSenderId = repliedMessage.senderId;
						replyToMessageType = repliedMessage.messageType;
					}
				} catch (error) {
					console.error('❌ Error fetching replied message (REST):', error);
				}
			}

			// Save message to database
			const chat = await Chat.create({
				senderId,
				receiverId,
				messageType,
				message: message || null,
				fileUrl: fileUrl || null,
				mimeType: mimeType || null,
				imageWidth: messageType === 'image' && imageWidth ? parseInt(imageWidth) : null,
				imageHeight: messageType === 'image' && imageHeight ? parseInt(imageHeight) : null,
				contactPayload: contactPayload || null,
				audioDuration: messageType === 'audio' && audioDuration ? parseFloat(audioDuration) : null,
				videoThumbnailUrl: messageType === 'video' && videoThumbnailUrl ? videoThumbnailUrl : null,
				videoDuration: messageType === 'video' && videoDuration ? parseFloat(videoDuration) : null,
				replyToMessageId: replyToMessageId || null,
				replyToMessageText: replyToMessageText,
				replyToMessageSenderId: replyToMessageSenderId,
				replyToMessageType: replyToMessageType,
				messageStatus: 'sent',
				isRead: false,
				deliveryChannel: 'fcm' // Message sent via REST API/FCM
			});

			const chatId = chat.dataValues.id;

			// Check if receiver is online via ChatController
			const receiverSocketId = this.chatController?.getConnectedUsers().get(receiverId);
			const receiverInActiveChat = this.chatController?.getActiveChatFor(receiverId) === senderId;

			// Notify sender if they're online (via socket)
			const senderSocketId = this.chatController?.getConnectedUsers().get(senderId);
			if (senderSocketId && this.chatController) {
				this.chatController.emitToSocket(senderSocketId, 'message-sent', {
					chatId: chatId,
					receiverId,
					messageType: messageType,
					message: message || null,
					fileUrl: fileUrl || null,
					mimeType: mimeType || null,
					imageWidth: chat.dataValues.imageWidth || null,
					imageHeight: chat.dataValues.imageHeight || null,
					contactPayload: contactPayload || null,
					audioDuration: messageType === 'audio' ? chat.dataValues.audioDuration || null : null,
					videoThumbnailUrl: messageType === 'video' ? chat.dataValues.videoThumbnailUrl || null : null,
					videoDuration: messageType === 'video' ? chat.dataValues.videoDuration || null : null,
					replyToMessageId: chat.dataValues.replyToMessageId || null,
					messageStatus: 'sent',
					deliveryChannel: 'fcm',
					receiverDeliveryChannel: null, // Will be set when receiver acknowledges
					createdAt: chat.dataValues.createdAt,
					reactions: [] // New message has no reactions yet
				});
			}

			// Handle receiver notification
			if (receiverSocketId && this.chatController) {
				// Receiver is online - emit socket event
				this.chatController.emitToSocket(receiverSocketId, 'new-message', {
					chatId: chatId,
					senderId,
					receiverId,
					messageType: messageType,
					message: message || null,
					fileUrl: fileUrl || null,
					mimeType: mimeType || null,
					imageWidth: chat.dataValues.imageWidth || null,
					imageHeight: chat.dataValues.imageHeight || null,
					contactPayload: contactPayload || null,
					audioDuration: messageType === 'audio' ? chat.dataValues.audioDuration || null : null,
					videoThumbnailUrl: messageType === 'video' ? chat.dataValues.videoThumbnailUrl || null : null,
					videoDuration: messageType === 'video' ? chat.dataValues.videoDuration || null : null,
					replyToMessageId: chat.dataValues.replyToMessageId || null,
					replyToMessageText: replyToMessageText,
					replyToMessageSenderId: replyToMessageSenderId,
					replyToMessageType: replyToMessageType,
					messageStatus: 'sent',
					deliveryChannel: 'fcm',
					receiverDeliveryChannel: null, // Will be set when receiver acknowledges
					createdAt: chat.dataValues.createdAt,
					reactions: [] // New message has no reactions yet
				});

				// Send FCM to all devices of online user (multi-device support)
				try {
					console.log('📨 Sending FCM to all devices of online user', {
						receiverId,
						chatId,
						inActiveChatWithSender: receiverInActiveChat
					});

					// Generate descriptive text for media messages (avoids empty notifications)
					let displayText = message;
					if (!message || message.trim() === '') {
						switch (messageType) {
							case 'image':
								displayText = '📷 Photo';
								break;
							case 'video':
								displayText = '🎥 Video';
								break;
							case 'pdf':
								displayText = '📄 Document';
								break;
							case 'contact':
								displayText = '👤 Contact';
								break;
							case 'audio':
								displayText = '🎤 Voice message';
								break;
							default:
								displayText = 'New message';
						}
					}

					const fcmResult = await sendChatMessageToUser({
						receiverId,
						chatId,
						senderId,
						senderFirstName: sender?.firstName || '',
						senderChatPicture: sender?.chat_picture || '',
						senderMobileNumber: sender?.mobileNo || '',
						messageText: displayText,
						conversationId: senderId // conversationId is the sender's userId for private chats
					});

					console.log(`✅ FCM sent to ${fcmResult.successCount}/${fcmResult.tokenCount} devices for online user ${receiverId}`, {
						chatId,
						invalidTokens: fcmResult.invalidTokenCount
					});
				} catch (fcmError) {
					console.error('❌ Error sending FCM to online user:', fcmError);
				}

				// Auto-mark as delivered since receiver is online and connected
				setTimeout(async () => {
					try {
						// Only update if receiver is still online
						if (this.chatController?.getConnectedUsers().get(receiverId)) {
							await Chat.update(
								{ messageStatus: 'delivered', deliveredAt: new Date() },
								{ where: { id: chatId, messageStatus: 'sent' } }
							);

							// Notify sender about delivery (double checkmark)
							if (senderSocketId && this.chatController) {
								this.chatController.emitToSocket(senderSocketId, 'message-status-update', {
									chatId: chatId,
									status: 'delivered'
								});
							}

							console.log(`✅ Auto-marked message ${chatId} as delivered via REST API`);
						}
					} catch (error) {
						console.error('Error auto-updating delivery status via REST API:', error);
					}
				}, 500); // Increased delay to handle burst messages

			} else {
				// Receiver is offline - send FCM to all devices
				try {
					console.log('📨 Sending FCM to all devices of offline user', { receiverId, chatId });

					// Generate descriptive text for media messages (avoids empty notifications)
					let displayText = message;
					if (!message || message.trim() === '') {
						switch (messageType) {
							case 'image':
								displayText = '📷 Photo';
								break;
							case 'video':
								displayText = '🎥 Video';
								break;
							case 'pdf':
								displayText = '📄 Document';
								break;
							case 'contact':
								displayText = '👤 Contact';
								break;
							case 'audio':
								displayText = '🎤 Voice message';
								break;
							default:
								displayText = 'New message';
						}
					}

					const fcmResult = await sendChatMessageToUser({
						receiverId,
						chatId,
						senderId,
						senderFirstName: sender?.firstName || '',
						senderChatPicture: sender?.chat_picture || '',
						senderMobileNumber: sender?.mobileNo || '',
						messageText: displayText,
						conversationId: senderId // conversationId is the sender's userId for private chats
					});

					console.log(`✅ FCM sent to ${fcmResult.successCount}/${fcmResult.tokenCount} devices for offline user ${receiverId}`, {
						chatId,
						invalidTokens: fcmResult.invalidTokenCount
					});
				} catch (fcmError) {
					console.error('❌ Error sending FCM notification:', fcmError);
				}
			}

			res.status(201).json({
				success: true,
				data: {
					chatId: chat.dataValues.id,
					senderId: chat.dataValues.senderId,
					receiverId: chat.dataValues.receiverId,
					message: chat.dataValues.message,
					messageType: chat.dataValues.messageType,
					fileUrl: chat.dataValues.fileUrl,
					mimeType: chat.dataValues.mimeType,
					messageStatus: chat.dataValues.messageStatus,
					contactPayload: chat.dataValues.contactPayload,
					audioDuration: chat.dataValues.audioDuration || null,
					videoThumbnailUrl: chat.dataValues.videoThumbnailUrl || null,
					videoDuration: chat.dataValues.videoDuration || null,
					replyToMessageId: chat.dataValues.replyToMessageId || null,
					replyToMessageText: replyToMessageText,
					replyToMessageSenderId: replyToMessageSenderId,
					replyToMessageType: replyToMessageType,
					deliveryChannel: chat.dataValues.deliveryChannel,
					createdAt: chat.dataValues.createdAt,
					updatedAt: chat.dataValues.updatedAt,
					isRead: chat.dataValues.isRead,
					reactions: [] // New message has no reactions yet
				}
			});
		} catch (error) {
			console.error('Error sending message via REST:', error);
			res.status(500).json({ error: 'Failed to send message' });
		}
	}

	/**
	 * Get chat history between two users
	 * Supports incremental sync via sincechatId parameter
	 *
	 * Query params:
	 * - page: Page number (default: 1)
	 * - limit: Messages per page (default: 50)
	 * - sincechatId: (optional) Only return messages AFTER this message ID
	 *                   Used for incremental sync - 20x reduction in data transfer
	 */
	async getChatHistory(req: AuthenticatedRequest, res: Response) {
		try {
			const { otherUserId } = req.params;
			const { page = 1, limit = 50, sincechatId } = req.query;
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: 'User not authenticated' });
			}

			const pageNum = Number(page);
			const limitNum = Number(limit);
			const offset = (pageNum - 1) * limitNum;

			// Base query: messages between these two users
			const whereCondition: any = {
				[Op.or]: [
					{ senderId: userId, receiverId: otherUserId },
					{ senderId: otherUserId, receiverId: userId }
				]
			};

			// INCREMENTAL SYNC: If sincechatId provided, only fetch newer messages
			let isIncremental = false;
			if (sincechatId && typeof sincechatId === 'string') {
				const referenceMessage = await Chat.findByPk(sincechatId, {
					attributes: ['id', 'createdAt']
				});

				if (referenceMessage) {
					// Only get messages created AFTER the reference message
					whereCondition.createdAt = {
						[Op.gt]: referenceMessage.createdAt
					};
					isIncremental = true;
					console.log(`📊 Incremental sync: fetching messages after ${sincechatId} (${referenceMessage.createdAt})`);
				} else {
					console.warn(`⚠️ sincechatId ${sincechatId} not found, falling back to full sync`);
				}
			}

			// Import MessageReaction model for including reactions with messages
			const MessageReaction = require('../db/models/message-reaction.model').default;

			const chats = await Chat.findAndCountAll({
				where: whereCondition,
				order: [['createdAt', 'DESC']],
				limit: limitNum,
				offset,
				attributes: ['id', 'senderId', 'receiverId', 'message', 'contactPayload', 'pollPayload', 'messageType', 'fileUrl', 'mimeType', 'deletedForSender', 'deletedForReceiver', 'deletedAt', 'messageStatus', 'isRead', 'deliveryChannel', 'receiverDeliveryChannel', 'deliveredAt', 'readAt', 'createdAt', 'updatedAt', 'isFollowUp', 'audioDuration', 'videoThumbnailUrl', 'videoDuration', 'replyToMessageId', 'replyToMessageText', 'replyToMessageSenderId', 'replyToMessageType'],
				include: [
					{
						model: User,
						as: 'sender',
						attributes: ['id', 'firstName', 'lastName', 'mobileNo']
					},
					{
						model: User,
						as: 'receiver',
						attributes: ['id', 'firstName', 'lastName', 'mobileNo']
					},
					{
						model: MessageReaction,
						as: 'reactions',
						attributes: ['id', 'userId', 'emoji', 'createdAt'],
						include: [
							{
								model: User,
								as: 'user',
								attributes: ['id', 'firstName', 'lastName', 'chat_picture']
							}
						],
						required: false // LEFT JOIN - include messages even without reactions
					},
					{
						model: Chat,
						as: 'replyToMessage',
						attributes: ['id', 'senderId', 'message', 'messageType', 'fileUrl', 'mimeType', 'audioDuration'],
						include: [
							{
								model: User,
								as: 'sender',
								attributes: ['id', 'firstName', 'lastName']
							}
						],
						required: false
					}
				]
			});

			const hasMore = chats.rows.length === limitNum;

			res.json({
				success: true,
				data: {
					messages: chats.rows.reverse(), // Reverse to get chronological order
					hasMore,
					isIncremental,
					pagination: {
						page: pageNum,
						limit: limitNum,
						total: chats.count,
						totalPages: Math.ceil(chats.count / limitNum)
					}
				}
			});

			if (isIncremental) {
				console.log(`✅ Incremental sync: returned ${chats.rows.length} new messages (vs ${chats.count} total)`);
			}
		} catch (error) {
			console.error('Error fetching chat history:', error);
			res.status(500).json({ error: 'Failed to fetch chat history' });
		}
	}

	/**
	 * Sync chat messages - Get new/updated messages since last sync
	 * This is more efficient than fetching entire chat history
	 * Supports pagination for handling large number of messages
	 */
	async syncChatMessages(req: AuthenticatedRequest, res: Response) {
		try {
			const { otherUserId, lastSyncTime, page = 1, limit = 100 } = req.body;
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: 'User not authenticated' });
			}

			if (!lastSyncTime) {
				return res.status(400).json({
					error: 'lastSyncTime is required in request body (ISO 8601 format)'
				});
			}

			// Validate lastSyncTime is a valid date
			const syncDate = new Date(lastSyncTime as string);
			if (isNaN(syncDate.getTime())) {
				return res.status(400).json({
					error: 'Invalid lastSyncTime format. Use ISO 8601 format (e.g., 2025-10-29T10:30:00Z)'
				});
			}

			// Calculate pagination
			const pageNum = Number(page);
			const limitNum = Number(limit);
			const offset = (pageNum - 1) * limitNum;

			// Build where clause for syncing messages
			const whereClause: any = {
				// Get messages created or updated after lastSyncTime
				[Op.or]: [
					{ createdAt: { [Op.gt]: syncDate } },
					{ updatedAt: { [Op.gt]: syncDate } }
				]
			};

			// If syncing specific conversation
			if (otherUserId) {
				whereClause[Op.and] = [
					{
						[Op.or]: [
							{ senderId: userId, receiverId: otherUserId },
							{ senderId: otherUserId, receiverId: userId }
						]
					}
				];
			} else {
				// Sync all conversations - user must be sender or receiver
				whereClause[Op.and] = [
					{
						[Op.or]: [
							{ senderId: userId },
							{ receiverId: userId }
						]
					}
				];
			}

			// Import MessageReaction model
			const MessageReaction = require('../db/models/message-reaction.model').default;

			const result = await Chat.findAndCountAll({
				where: whereClause,
				order: [['createdAt', 'ASC']],
				limit: limitNum,
				offset: offset,
				attributes: [
					'id',
					'senderId',
					'receiverId',
					'message',
					'messageStatus',
					'isRead',
					'deliveryChannel',
					'receiverDeliveryChannel',
					'deliveredAt',
					'readAt',
					'messageType',
					'fileUrl',
					'mimeType',
					'contactPayload',
					'pollPayload',
					'deletedForSender',
					'deletedForReceiver',
					'deletedAt',
					'createdAt',
					'updatedAt',
					'isFollowUp',
					'audioDuration',
					'videoThumbnailUrl',
					'videoDuration',
					'replyToMessageId',
					'replyToMessageText',
					'replyToMessageSenderId',
					'replyToMessageType'
				],
				include: [
					{
						model: User,
						as: 'sender',
						attributes: ['id', 'firstName', 'lastName', 'mobileNo']
					},
					{
						model: User,
						as: 'receiver',
						attributes: ['id', 'firstName', 'lastName', 'mobileNo']
					},
					{
						model: MessageReaction,
						as: 'reactions',
						attributes: ['id', 'userId', 'emoji', 'createdAt'],
						include: [
							{
								model: User,
								as: 'user',
								attributes: ['id', 'firstName', 'lastName', 'chat_picture']
							}
						],
						required: false
					},
					{
						model: Chat,
						as: 'replyToMessage',
						attributes: ['id', 'senderId', 'message', 'messageType', 'fileUrl', 'mimeType', 'audioDuration'],
						include: [
							{
								model: User,
								as: 'sender',
								attributes: ['id', 'firstName', 'lastName']
							}
						],
						required: false
					}
				]
			});

			const totalPages = Math.ceil(result.count / limitNum);
			const hasMore = pageNum < totalPages;
			const currentSyncTime = new Date().toISOString();

			res.json({
				success: true,
				data: {
					messages: result.rows,
					syncInfo: {
						lastSyncTime: lastSyncTime,
						currentSyncTime: currentSyncTime,
						conversationWith: otherUserId || 'all'
					},
					pagination: {
						page: pageNum,
						limit: limitNum,
						total: result.count,
						totalPages: totalPages,
						hasMore: hasMore,
						currentPageCount: result.rows.length
					}
				}
			});
		} catch (error) {
			console.error('Error syncing chat messages:', error);
			res.status(500).json({ error: 'Failed to sync chat messages' });
		}
	}

	/**
	 * Get list of users that the current user has chatted with
	 */
	async getChatContacts(req: AuthenticatedRequest, res: Response) {
		try {
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: 'User not authenticated' });
			}

			// Get all chats involving the user
			const chats = await Chat.findAll({
				where: {
					[Op.or]: [
						{ senderId: userId },
						{ receiverId: userId }
					]
				},
				attributes: ['senderId', 'receiverId'],
				raw: true
			});

			// console.log({ "all chats found": chats.length, "sample": chats.slice(0, 3) });

			// Extract unique contact IDs
			const contactIdsSet = new Set<string>();
			chats.forEach((chat: any) => {
				if (chat.senderId === userId) {
					contactIdsSet.add(chat.receiverId);
				} else {
					contactIdsSet.add(chat.senderId);
				}
			});

			const contactIds = Array.from(contactIdsSet);
			// console.log({ "extracted contactIds": contactIds });

			if (contactIds.length === 0) {
				return res.json({
					success: true,
					data: []
				});
			}

			const contactDetails = await User.findAll({
				where: {
					id: {
						[Op.in]: contactIds
					}
				},
				attributes: ['id', 'firstName', 'lastName', 'mobileNo'],
				raw: true
			});

			// Get last message for each contact
			const contactsWithLastMessage = await Promise.all(
				contactDetails.map(async (contact: any) => {
					const lastMessage = await Chat.findOne({
						where: {
							[Op.or]: [
								{ senderId: userId, receiverId: contact.id },
								{ senderId: contact.id, receiverId: userId }
							]
						},
						order: [['createdAt', 'DESC']],
						limit: 1,
						attributes: [
							'id',
							'senderId',
							'receiverId',
							'messageType',
							'fileUrl',
							'mimeType',
							'message',
							'messageStatus',
							'isRead',
							'deliveredAt',
							'readAt',
							'contactPayload',
							'deletedForSender',
							'deletedForReceiver',
							'deletedAt',
							'createdAt',
							'lastActivityType',
							'lastActivityAt',
							'lastActivityActorId',
							'lastActivityEmoji',
							'lastActivityMessageId'
						],
						raw: true
					});

					const unreadCount = await Chat.count({
						where: {
							senderId: contact.id,
							receiverId: userId,
							isRead: false
						}
					});

					return {
						id: contact.id,
						firstName: contact.firstName,
						lastName: contact.lastName,
						mobileNo: contact.mobileNo,
						lastMessage: lastMessage ? {
							chatId: lastMessage.id,
							message: lastMessage.message,
							createdAt: lastMessage.createdAt,
							senderId: lastMessage.senderId,
							isFromCurrentUser: lastMessage ? lastMessage.senderId === userId : false,
							messageStatus: lastMessage.messageStatus,
							isRead: lastMessage.isRead,
							deliveredAt: lastMessage.deliveredAt,
							readAt: lastMessage.readAt,
							messageType: lastMessage.messageType,
							fileUrl: lastMessage.fileUrl,
							mimeType: lastMessage.mimeType,
							contactPayload: lastMessage.contactPayload,
							deletedForSender: lastMessage.deletedForSender,
							deletedForReceiver: lastMessage.deletedForReceiver,
							deletedAt: lastMessage.deletedAt
						} : null,
						lastActivity: lastMessage && lastMessage.lastActivityType ? {
							type: lastMessage.lastActivityType,
							actorId: lastMessage.lastActivityActorId,
							emoji: lastMessage.lastActivityEmoji,
							messageId: lastMessage.lastActivityMessageId,
							timestamp: lastMessage.lastActivityAt
						} : null,
						unreadCount: unreadCount || 0

					};
				})
			);
			res.json({
				success: true,
				data: contactsWithLastMessage
			});
		} catch (error) {
			console.error('Error fetching chat contacts:', error);
			res.status(500).json({ error: 'Failed to fetch chat contacts' });
		}
	}

	/**
	 * Get unread message count
	 */
	async getUnreadCount(req: AuthenticatedRequest, res: Response) {
		try {
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: 'User not authenticated' });
			}

			// Count all unread messages where the current user is the receiver
			const unreadCount = await Chat.count({
				where: {
					receiverId: userId,
					isRead: false
				}
			});

			res.json({
				success: true,
				data: {
					unreadCount
				}
			});
		} catch (error) {
			console.error('Error getting unread count:', error);
			res.status(500).json({ error: 'Failed to get unread count' });
		}
	}

	/**
	 * Mark messages as read
	 */
	async markMessagesAsRead(req: AuthenticatedRequest, res: Response) {
		try {
			const { chatIds, receiverDeliveryChannel = 'fcm' } = req.body;
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: 'User not authenticated' });
			}

			if (!chatIds || !Array.isArray(chatIds) || chatIds.length === 0) {
				return res.status(400).json({ error: 'chatIds array is required' });
			}

			// Update all messages where the user is the receiver and the message is unread
			const [updatedCount] = await Chat.update(
				{
					isRead: true,
					messageStatus: 'read',
					readAt: new Date(),
					receiverDeliveryChannel: receiverDeliveryChannel // Track how receiver opened the message
				},
				{
					where: {
						id: {
							[Op.in]: chatIds
						},
						receiverId: userId,
						isRead: false
					}
				}
			);

			// Notify socket users about read status
			if (this.chatController && updatedCount > 0) {
				console.log('═══════════════════════════════════════════════════════');
				console.log('📱 REST API: Mark messages as READ (offline device)');
				console.log('📋 Message IDs:', chatIds);
				console.log('═══════════════════════════════════════════════════════');

				const MessageReaction = require('../db/models/message-reaction.model').default;

				const messages = await Chat.findAll({
					where: { id: { [Op.in]: chatIds } },
					attributes: ['id', 'senderId', 'receiverId', 'messageType', 'contactPayload', 'fileUrl', 'mimeType', 'message', 'messageStatus', 'deliveryChannel', 'receiverDeliveryChannel', 'deliveredAt', 'readAt', 'createdAt'],
					include: [
						{
							model: MessageReaction,
							as: 'reactions',
							attributes: ['id', 'userId', 'emoji', 'createdAt'],
							include: [
								{
									model: User,
									as: 'user',
									attributes: ['id', 'firstName', 'lastName', 'chat_picture']
								}
							],
							required: false
						}
					]
				});

				messages.forEach((msg: any) => {
					console.log(`📤 Broadcasting 'read' status to sender: ${msg.senderId}`);

					const msgData = msg.toJSON ? msg.toJSON() : msg;

					// Broadcast full message object to sender
					this.chatController!.notifyMessageStatusUpdateWithObject(
						msgData.id,
						msgData.senderId,
						'read',
						{
							chatId: msgData.id,
							senderId: msgData.senderId,
							receiverId: msgData.receiverId,
							messageType: msgData.messageType,
							fileUrl: msgData.fileUrl,
							mimeType: msgData.mimeType,
							message: msgData.message,
							contactPayload: msgData.contactPayload,
							messageStatus: msgData.messageStatus,
							deliveryChannel: msgData.deliveryChannel,
							receiverDeliveryChannel: msgData.receiverDeliveryChannel,
							deliveredAt: msgData.deliveredAt,
							readAt: msgData.readAt,
							createdAt: msgData.createdAt,
							reactions: msgData.reactions || []
						}
					);

					console.log(`✅ WebSocket event sent to ${msgData.senderId}`);
				});

				console.log('═══════════════════════════════════════════════════════');
				console.log(`✅ REST API complete: ${updatedCount} messages marked as read`);
				console.log('═══════════════════════════════════════════════════════');
			}

			res.json({
				success: true,
				data: {
					updatedCount
				}
			});
		} catch (error) {
			console.error('Error marking messages as read:', error);
			res.status(500).json({ error: 'Failed to mark messages as read' });
		}
	}

	/**
	 * Search messages
	 */
	async searchMessages(req: AuthenticatedRequest, res: Response) {
		try {
			const { query, otherUserId } = req.query;
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: 'User not authenticated' });
			}

			if (!query) {
				return res.status(400).json({ error: 'Search query is required' });
			}

			const whereClause: any = {
				message: {
					[Op.iLike]: `%${query}%`
				},
				deletedAt: null
			};

			// If searching within a specific conversation
			if (otherUserId) {
				whereClause[Op.or] = [
					{ senderId: userId, receiverId: otherUserId },
					{ senderId: otherUserId, receiverId: userId }
				];
			} else {
				// Search across all conversations involving the user
				whereClause[Op.or] = [
					{ senderId: userId },
					{ receiverId: userId }
				];
			}

			const messages = await Chat.findAll({
				where: whereClause,
				order: [['createdAt', 'DESC']],
				limit: 50,
				include: [
					{
						model: User,
						as: 'sender',
						attributes: ['id', 'firstName', 'lastName', 'mobileNo']
					},
					{
						model: User,
						as: 'receiver',
						attributes: ['id', 'firstName', 'lastName', 'mobileNo']
					}
				]
			});

			res.json({
				success: true,
				data: messages
			});
		} catch (error) {
			console.error('Error searching messages:', error);
			res.status(500).json({ error: 'Failed to search messages' });
		}
	}

	/**
	 * Mark messages as delivered (when app receives them)
	 * Accepts both 'messageIds' (from native Android FCM handler) and 'chatIds' (legacy) for compatibility
	 */
	async markMessagesAsDelivered(req: AuthenticatedRequest, res: Response) {
		try {
			// Accept both 'messageIds' (native Android sends this) and 'chatIds' (legacy)
			const { messageIds, chatIds, receiverDeliveryChannel = 'fcm' } = req.body;
			const ids = messageIds || chatIds; // Prefer messageIds, fallback to chatIds
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: 'User not authenticated' });
			}

			// Validate ids parameter (accept either messageIds or chatIds)
			if (!ids || !Array.isArray(ids) || ids.length === 0) {
				return res.status(400).json({ error: 'messageIds (or chatIds) must be a non-empty array' });
			}

			// Update messages to delivered status
			const [updatedCount] = await Chat.update(
				{
					messageStatus: 'delivered',
					deliveredAt: new Date(),
					receiverDeliveryChannel: receiverDeliveryChannel // Track how receiver got the message
				},
				{
					where: {
						id: { [Op.in]: ids },
						receiverId: userId,
						messageStatus: 'sent' // Only update if currently 'sent'
					}
				}
			);

			// Notify socket users about delivery status
			if (this.chatController && updatedCount > 0) {


				const MessageReaction = require('../db/models/message-reaction.model').default;

				const messages = await Chat.findAll({
					where: { id: { [Op.in]: ids } },
					attributes: ['id', 'senderId', 'receiverId', 'message', 'messageType', 'fileUrl', 'mimeType', 'messageStatus', 'deliveryChannel', 'contactPayload', 'receiverDeliveryChannel', 'deliveredAt', 'readAt', 'createdAt'],
					include: [
						{
							model: MessageReaction,
							as: 'reactions',
							attributes: ['id', 'userId', 'emoji', 'createdAt'],
							include: [
								{
									model: User,
									as: 'user',
									attributes: ['id', 'firstName', 'lastName', 'chat_picture']
								}
							],
							required: false
						}
					]
				});

				messages.forEach((msg: any) => {
					console.log(`📤 Broadcasting 'delivered' status to sender: ${msg.senderId}`);

					const msgData = msg.toJSON ? msg.toJSON() : msg;

					// Broadcast full message object to sender
					this.chatController!.notifyMessageStatusUpdateWithObject(
						msgData.id,
						msgData.senderId,
						'delivered',
						{
							chatId: msgData.id,
							senderId: msgData.senderId,
							receiverId: msgData.receiverId,
							message: msgData.message,
							messageStatus: msgData.messageStatus,
							deliveryChannel: msgData.deliveryChannel,
							contactPayload: msgData.contactPayload,
							messageType: msgData.messageType,
							fileUrl: msgData.fileUrl,
							mimeType: msgData.mimeType,
							receiverDeliveryChannel: msgData.receiverDeliveryChannel,
							deliveredAt: msgData.deliveredAt,
							readAt: msgData.readAt,
							createdAt: msgData.createdAt,
							reactions: msgData.reactions || []
						}
					);


				});


			}

			res.json({
				success: true,
				data: { updatedCount: updatedCount }
			});
		} catch (error) {
			console.error('Error marking messages as delivered:', error);
			res.status(500).json({ error: 'Failed to mark messages as delivered' });
		}
	}

	/**
	 * Get status of specific messages (for sender to check delivery/read status)
	 */
	async getMessageStatus(req: AuthenticatedRequest, res: Response) {
		try {
			const { chatIds } = req.body;
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: 'User not authenticated' });
			}

			// Validate chatIds parameter
			if (!chatIds || !Array.isArray(chatIds) || chatIds.length === 0) {
				return res.status(400).json({ error: 'chatIds must be a non-empty array' });
			}

			const messages = await Chat.findAll({
				where: {
					id: { [Op.in]: chatIds },
					senderId: userId // Only sender can check status
				},
				attributes: ['id', 'messageStatus', 'deliveredAt', 'readAt']
			});

			res.json({
				success: true,
				data: messages
			});
		} catch (error) {
			console.error('Error getting message status:', error);
			res.status(500).json({ error: 'Failed to get message status' });
		}
	}

	/**
	 * Delete a message (only sender can delete their own message)
	 */

	async deleteMessage(req: AuthenticatedRequest, res: Response) {
		try {
			const { chatId, deleteType } = req.params; // deleteType: 'me' or 'everyone
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: "User not authenticated" });
			}

			if (!deleteType) {
				return res.status(400).json({ error: "Delete type is required" });
			}

			if (deleteType !== 'me' && deleteType !== 'everyone') {
				return res.status(400).json({ error: "Invalid delete type" });
			}
			if (!chatId) {
				return res.status(400).json({ error: "Message ID is required" });
			}

			// Find the message
			const message = await Chat.findByPk(chatId, { raw: true });

			if (!message) {
				// Idempotent: if message doesn't exist, treat as already deleted (success)
				return res.json({
					success: true,
					message: "Message already deleted or not found",
					chatId: chatId,
				});
			}
			console.log({ message, userId });
			// Check if the user is the sender of the message
			if (message.senderId !== userId) {
				return res
					.status(403)
					.json({ error: "You can only delete your own messages" });
			}

			if (deleteType === "everyone") {
				if (
					new Date(message.createdAt) < new Date(Date.now() - 60 * 60 * 1000)
				) {
					// cant delete after one hour of sending
					return res.status(400).json({
						error: "Message cannot be deleted after one hour of sending",
					});
				}
			}

			// Delete the message
			if (deleteType === "me") {
				await Chat.update(
					{ deletedForSender: true, deletedAt: new Date() },
					{
						where: {
							id: chatId,
							senderId: userId,
						},
					}
				);
			} else {
				await Chat.update(
					{
						deletedForSender: true,
						deletedForReceiver: true,
						deletedAt: new Date(),
						message: null,
						fileUrl: null,
						mimeType: null,
					},
					{
						where: {
							id: chatId,
							senderId: userId,
						},
					}
				);
			}

			// Notify via WebSocket if available
			if (this.chatController) {
				this.chatController.notifyMessageDeletion(
					chatId,
					message.senderId,
					message.receiverId,
					deleteType
				);
			}

			res.json({
				success: true,
				message: "Message deleted successfully",
				chatId: chatId,
				deletedBy: userId,
				deletedAt: new Date(),
			});
		} catch (error) {
			console.error("Error deleting message:", error);
			res.status(500).json({ error: "Failed to delete message" });
		}
	}

	/**
	 * Bulk update message status (delivered and read)
	 * Updates both delivered and read status with the same timestamp
	 */
	async updateMessageStatus(req: AuthenticatedRequest, res: Response) {
		try {
			const { chatIds, receiverDeliveryChannel = 'fcm' } = req.body;
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: 'User not authenticated' });
			}

			if (!chatIds || !Array.isArray(chatIds) || chatIds.length === 0) {
				return res.status(400).json({ error: 'chatIds array is required' });
			}

			const now = new Date();

			// Update all messages where the user is the receiver
			// Set both delivered and read status with the same timestamp
			const [updatedCount] = await Chat.update(
				{
					isRead: true,
					messageStatus: 'read',
					deliveredAt: now,
					readAt: now,
					receiverDeliveryChannel: receiverDeliveryChannel // Track how receiver opened the message
				},
				{
					where: {
						id: {
							[Op.in]: chatIds
						},
						receiverId: userId
					}
				}
			);

			// Notify socket users about status updates
			if (this.chatController && updatedCount > 0) {
				const messages = await Chat.findAll({
					where: { id: { [Op.in]: chatIds } },
					attributes: ['id', 'senderId']
				});

				// Notify about both delivered and read status
				messages.forEach(msg => {
					this.chatController!.notifyMessageStatusUpdate(msg.id, msg.senderId, 'delivered');
					this.chatController!.notifyMessageStatusUpdate(msg.id, msg.senderId, 'read');
				});
			}

			res.json({
				success: true,
				data: {
					updatedCount,
					timestamp: now
				}
			});
		} catch (error) {
			console.error('Error bulk updating message status:', error);
			res.status(500).json({ error: 'Failed to bulk update message status' });
		}
	}

	// TODO: Implement push notification functionality
	// private async sendPushNotification(userId: string, message: string, senderId: string) {
	//   // Implementation would depend on your push notification service
	//   // (Firebase, OneSignal, etc.)
	// }


	async getStarredMessages(req: AuthenticatedRequest, res: Response) {

		try {
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: "User not authenticated" });
			}

			const starredMessages = await StarredMessage.findAll({
				where: { userId },
				include: [
					{
						model: Chat,
						as: "chat",
						required: true,
						where: {
							deletedAt: null,
							[Op.or]: [
								{
									senderId: userId,
									deletedForSender: false,
								},
								{
									receiverId: userId,
									deletedForReceiver: false,
								},
							],
						},
						attributes: [
							"id",
							"senderId",
							"receiverId",
							"message",
							"messageType",
							"fileUrl",
							"mimeType",
							'contactPayload',
							"createdAt",
						],
					},
				],
				order: [["createdAt", "DESC"]],
			});


			res.json({
				success: true,
				data: starredMessages,
			});
		} catch (err) {
			console.error("Error getting starred messages:", err);
			res.status(500).json({ error: "Failed to get starred messages" });
		}
	}
	async starMessage(req: AuthenticatedRequest, res: Response) {
		const userId = req.user?.id;

		if (!userId) {
			return res.status(401).json({ error: "User not authenticated" });
		}

		const { chatId } = req.body;

		if (!chatId) {
			return res.status(400).json({ error: "chatId is required" });
		}

		try {
			const chat = await Chat.findOne({
				where: {
					id: chatId,
					[Op.or]: [{ senderId: userId }, { receiverId: userId }],
				},
			});

			if (!chat) {
				return res.status(404).json({ error: "Chat not found" });
			}
			const [star, created] = await StarredMessage.findOrCreate({
				where: {
					userId: userId,
					chatId,
				},
			});

			res.status(201).json({
				success: true,
				data: {
					chatId,
					starred: true,
					alreadyStarred: !created,
				},
			});
		} catch (err) {
			console.error("Error starring message:", err);
			res.status(500).json({ error: "Failed to star message" });
		}
	}

	async unstarMessage(req: AuthenticatedRequest, res: Response) {
		try {
			const userId = req.user?.id;

			if (!userId) {
				return res.status(401).json({ error: "User not authenticated" });
			}

			const { chatId } = req.body;

			if (!chatId) {
				return res.status(400).json({ error: "chatId is required" });
			}
			await StarredMessage.destroy({
				where: {
					userId: userId,
					chatId,
				},
			});

			res.status(200).json({
				success: true,
				data: {
					chatId,
					starred: false,
				},
			});
		} catch (err) {
			console.error("Error unstarring message:", err);
			res.status(500).json({ error: "Failed to unstar message" });
		}
	}

}

export default MobileChatController;
