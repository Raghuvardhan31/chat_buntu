import { Server as SocketIOServer, Socket } from 'socket.io';
import GroupMember from '../db/models/group-member.model';
import GroupMessage from '../db/models/group-message.model';
import GroupMessageStatus from '../db/models/group-message-status.model';
import Group from '../db/models/group.model';
import User from '../db/models/user.model';
import { sendToAllUserDevices } from './fcm.service';
import { Op } from 'sequelize';

export async function setupGroupHandlers(
  io: SocketIOServer,
  socket: Socket,
  connectedUsers: Map<string, string>
) {
  const userId = (socket as any).userId;

  // ── AUTO-JOIN ON CONNECT (JWT-authenticated users) ────────────────────────
  if (userId) {
    try {
      const memberships = await GroupMember.findAll({
        where: { userId },
        attributes: ['groupId'],
      });
      const groupIds = memberships.map((m) => m.groupId);
      if (groupIds.length > 0) {
        groupIds.forEach((id) => socket.join(id));
        console.log(
          `🏠 [GroupSocket] User ${userId} auto-joined ${groupIds.length} groups on connect`
        );
      }
    } catch (err) {
      console.error('❌ [GroupSocket] Auto-join on connect error:', err);
    }
  }

  // ── AUTO-JOIN WHEN CLIENT SENDS 'join' EVENT ──────────────────────────────
  // NOTE: index.ts already handles joining the signaling room. We only join group rooms here.
  socket.on('join', async (uid: string) => {
    try {
      console.log(
        `👤 [GroupSocket] User ${uid} sent 'join', auto-joining group rooms...`
      );
      const memberships = await GroupMember.findAll({
        where: { userId: uid },
        attributes: ['groupId'],
      });
      const groupIds = memberships.map((m) => m.groupId);
      if (groupIds.length > 0) {
        groupIds.forEach((id) => socket.join(id));
        console.log(
          `🏠 [GroupSocket] User ${uid} joined ${groupIds.length} group rooms`
        );
      }
    } catch (err) {
      console.error('❌ [GroupSocket] Auto-join on join event error:', err);
    }
  });

  // ── JOIN-GROUP (single) ────────────────────────────────────────────────────
  socket.on('join_group', async (groupId: string) => {
    try {
      const uid = (socket as any).userId;
      if (!uid) {
        console.warn(
          `⚠️ [GroupSocket] join_group rejected: no userId on socket`
        );
        return;
      }

      if (socket.rooms.has(groupId)) {
        console.log(
          `✅ [GroupSocket] User ${uid} already in room ${groupId}`
        );
        return;
      }

      const membership = await GroupMember.findOne({
        where: { groupId, userId: uid },
      });
      if (!membership) {
        console.warn(
          `🚫 [GroupSocket] join_group denied: user ${uid} not a member of ${groupId}`
        );
        return;
      }

      socket.join(groupId);
      console.log(`🏠 [GroupSocket] User ${uid} joined room: ${groupId}`);
    } catch (err) {
      console.error('❌ [GroupSocket] join_group error:', err);
    }
  });

  // ── LEAVE-GROUP ────────────────────────────────────────────────────────────
  socket.on('leave_group', (groupId: string) => {
    const uid = (socket as any).userId;
    socket.leave(groupId);
    console.log(`🚪 [GroupSocket] User ${uid} left room: ${groupId}`);
  });

  // ── JOIN-GROUPS (bulk) ─────────────────────────────────────────────────────
  socket.on('join_groups', async (groupIds: string[]) => {
    try {
      const uid = (socket as any).userId;
      if (!uid || !Array.isArray(groupIds)) return;

      let joined = 0;
      for (const groupId of groupIds) {
        if (socket.rooms.has(groupId)) {
          joined++;
          continue;
        }
        const membership = await GroupMember.findOne({
          where: { groupId, userId: uid },
        });
        if (membership) {
          socket.join(groupId);
          joined++;
        }
      }
      console.log(
        `🏠 [GroupSocket] User ${uid} bulk-joined ${joined}/${groupIds.length} groups`
      );
    } catch (err) {
      console.error('❌ [GroupSocket] join_groups error:', err);
    }
  });

  // ── SYNC-GROUP-MESSAGES (offline catchup) ─────────────────────────────────
  socket.on(
    'sync-group-messages',
    async (data: { groupId: string; lastSeenTimestamp?: string }) => {
      try {
        const uid = (socket as any).userId;
        if (!uid || !data.groupId) return;

        const membership = await GroupMember.findOne({
          where: { groupId: data.groupId, userId: uid },
        });
        if (!membership) return;

        const where: any = { groupId: data.groupId, isDeleted: false };
        if (data.lastSeenTimestamp) {
          where.createdAt = { [Op.gt]: new Date(data.lastSeenTimestamp) };
        }

        const messages = await GroupMessage.findAll({
          where,
          order: [['createdAt', 'ASC']],
          limit: 100,
          include: [
            {
              model: User,
              as: 'sender',
              attributes: ['id', 'firstName', 'lastName', 'chat_picture'],
            },
          ],
        });

        socket.emit('group-messages-synced', {
          groupId: data.groupId,
          messages: await Promise.all(
            messages.map((m) => _formatMessageWithStatus(m))
          ),
        });
      } catch (err) {
        console.error('❌ [GroupSocket] sync-group-messages error:', err);
      }
    }
  );

  // ── SEND-GROUP-MESSAGE ─────────────────────────────────────────────────────
  socket.on('send_group_message', async (data: any, callback?: Function) => {
    const { clientMessageId, groupId } = data;
    try {
      const uid = (socket as any).userId;
      if (!uid) {
        console.error(
          '❌ [GroupSocket] send_group_message rejected: no userId'
        );
        if (callback) callback({ success: false, error: 'Not authenticated' });
        return;
      }

      console.log(
        `📩 [GroupSocket] send_group_message from ${uid} → group ${groupId}`
      );

      // 1. Deduplication — only check when clientMessageId is a real value
      if (clientMessageId) {
        const existing = await GroupMessage.findOne({
          where: { clientMessageId, senderId: uid },
        });
        if (existing) {
          console.log(`♻️ [GroupSocket] Deduplicated: ${clientMessageId}`);
          const formatted = await _formatMessageWithStatus(existing);
          socket.emit('group_message_sent', formatted);
          if (callback) callback({ success: true, message: formatted });
          return;
        }
      }

      // 2. Verify membership
      const member = await GroupMember.findOne({
        where: { groupId, userId: uid },
      });
      if (!member) {
        if (callback)
          callback({ success: false, error: 'Not a member of this group' });
        return;
      }

      // 3. Restriction check
      const group = await Group.findByPk(groupId);
      if (group?.isRestricted && member.role !== 'admin') {
        if (callback)
          callback({
            success: false,
            error: 'Only admins can send messages',
          });
        return;
      }

      // 4. Resolve reply metadata
      let replyMeta: any = {};
      if (data.replyToMessageId) {
        const replied = await GroupMessage.findByPk(data.replyToMessageId);
        if (replied) {
          replyMeta = {
            replyToMessageText: replied.message,
            replyToMessageSenderId: replied.senderId,
            replyToMessageType: replied.messageType,
          };
        }
      }

      // 5. Persist message
      const savedMsg = await GroupMessage.create({
        groupId,
        senderId: uid,
        message: data.message || null,
        messageType: data.messageType || 'text',
        fileUrl: data.fileUrl || null,
        mimeType: data.mimeType || null,
        contactPayload: data.contactPayload || null,
        pollPayload: data.pollPayload || null,
        fileMetadata: data.fileMetadata || null,
        audioDuration: data.audioDuration || null,
        videoThumbnailUrl: data.videoThumbnailUrl || null,
        videoDuration: data.videoDuration || null,
        imageWidth: data.imageWidth || null,
        imageHeight: data.imageHeight || null,
        replyToMessageId: data.replyToMessageId || null,
        replyToMessageText: replyMeta.replyToMessageText || null,
        replyToMessageSenderId: replyMeta.replyToMessageSenderId || null,
        replyToMessageType: replyMeta.replyToMessageType || null,
        // Only store a real clientMessageId — prevents NULL unique-index conflicts
        clientMessageId: clientMessageId || null,
      });

      // 6. Initialise per-member status rows
      const members = await GroupMember.findAll({ where: { groupId }, raw: true });
      const statuses = members.map((m) => ({
        messageId: savedMsg.id,
        userId: m.userId,
        status: m.userId === uid ? 'read' : 'sent',
        readAt: m.userId === uid ? new Date() : null,
      }));
      await GroupMessageStatus.bulkCreate(statuses, { ignoreDuplicates: true });

      // 7. Format payload
      const sender = await User.findByPk(uid);
      const messagePayload = await _formatMessageWithStatus(savedMsg, sender);

      // 8. PRIMARY delivery: broadcast to everyone in the Socket.IO room
      //    (covers all connected sockets for ALL group members in this room)
      io.in(groupId).emit('receive_group_message', messagePayload);
      console.log(
        `✅ [GroupSocket] Broadcast receive_group_message → room ${groupId}`
      );

      // 9. FALLBACK delivery: for any member whose socket is NOT in the group room
      //    (e.g. app is in background but socket is connected via signaling room only),
      //    deliver to their personal user room.
      //    We skip the sender — they receive the ACK below instead.
      const roomSockets = await io.in(groupId).allSockets();
      const socketList = Array.from(roomSockets);

      for (const m of members) {
        if (m.userId === uid) continue; // sender handled by ACK

        // Check whether this user has at least one socket in the group room.
        // If not, send to their personal signaling room.
        const userSocketsInRoom = socketList.filter(
          (sid) => connectedUsers.get(sid) === m.userId
        );
        if (userSocketsInRoom.length === 0) {
          io.to(m.userId).emit('receive_group_message', messagePayload);
          console.log(
            `📡 [GroupSocket] Fallback delivery → user room: ${m.userId}`
          );
        }
      }

      // 10. Acknowledge to sender (their own message confirmation)
      socket.emit('group_message_sent', messagePayload);
      if (callback) callback({ success: true, message: messagePayload });

      // 11. FCM push (background devices) — fire and forget
      _sendGroupNotifications(group, sender, savedMsg, members, uid).catch(
        () => null
      );
    } catch (err: any) {
      console.error('❌ [GroupSocket] send_group_message error:', err);
      socket.emit('group_message_error', {
        error: err.message || 'Failed to send',
        clientMessageId,
      });
      if (callback)
        callback({ success: false, error: err.message || 'Internal error' });
    }
  });

  // ── UPDATE-GROUP-MESSAGE-STATUS ────────────────────────────────────────────
  socket.on(
    'update-group-message-status',
    async (data: {
      chatIds: string[];
      groupId: string;
      status: 'delivered' | 'read';
    }) => {
      try {
        const uid = (socket as any).userId;
        if (!uid || !data.chatIds?.length || !data.groupId) return;

        const membership = await GroupMember.findOne({
          where: { groupId: data.groupId, userId: uid },
        });
        if (!membership) return;

        const now = new Date();
        for (const msgId of data.chatIds) {
          await GroupMessageStatus.update(
            {
              status: data.status,
              [data.status === 'read' ? 'readAt' : 'deliveredAt']: now,
            },
            {
              where: {
                messageId: msgId,
                userId: uid,
                status:
                  data.status === 'read'
                    ? { [Op.in]: ['sent', 'delivered'] }
                    : 'sent',
              },
            }
          );
        }

        if (data.status === 'read') {
          const latestId = data.chatIds[data.chatIds.length - 1];
          await GroupMember.update(
            { lastSeenMessageId: latestId },
            { where: { groupId: data.groupId, userId: uid } }
          );
        }

        io.to(data.groupId).emit('group-message-status-updated', {
          chatIds: data.chatIds,
          userId: uid,
          status: data.status,
          updatedAt: now,
        });
      } catch (err) {
        console.error('❌ [GroupSocket] update-status error:', err);
      }
    }
  );

  // ── TYPING INDICATOR ───────────────────────────────────────────────────────
  socket.on(
    'group_typing',
    async (data: { groupId: string; isTyping: boolean }) => {
      const uid = (socket as any).userId;
      if (!uid || !data.groupId) return;

      const membership = await GroupMember.findOne({
        where: { groupId: data.groupId, userId: uid },
        include: [{ model: User, as: 'user', attributes: ['firstName'] }],
      });
      if (!membership) return;

      socket.to(data.groupId).emit('group_user_typing', {
        groupId: data.groupId,
        userId: uid,
        firstName: (membership as any).user?.firstName || 'Someone',
        isTyping: data.isTyping,
      });
    }
  );

  // ── HELPERS ────────────────────────────────────────────────────────────────
  async function _formatMessageWithStatus(msg: any, sender: any = null) {
    const s = sender || msg.sender;
    const statuses = await GroupMessageStatus.findAll({
      where: { messageId: msg.id },
      raw: true,
    });
    const statusMap: any = {};
    statuses.forEach((st) => (statusMap[st.userId] = st.status));
    const readCount = statuses.filter((st) => st.status === 'read').length;

    return {
      ...(msg.toJSON ? msg.toJSON() : msg),
      senderName: s
        ? `${s.firstName || ''} ${s.lastName || ''}`.trim()
        : 'Unknown',
      senderAvatar: s?.chat_picture || null,
      statusPerUser: statusMap,
      readCount,
    };
  }

  async function _sendGroupNotifications(
    group: any,
    sender: any,
    msg: any,
    members: any[],
    currentUserId: string
  ) {
    const senderName =
      `${sender?.firstName || ''} ${sender?.lastName || ''}`.trim();
    const displayText =
      msg.messageType === 'text' ? msg.message : `Sent a ${msg.messageType}`;

    await Promise.all(
      members
        .filter((m) => m.userId !== currentUserId)
        .map((m) =>
          sendToAllUserDevices({
            userId: m.userId,
            messageUuid: msg.id,
            messageType: 'chat_message',
            conversationId: group?.id,
            data: {
              chatId: msg.id,
              senderId: currentUserId,
              senderFirstName: senderName,
              messageText: displayText || 'New message',
              chatType: 'group_message',
              groupId: group?.id,
              groupName: group?.name,
            },
          }).catch(() => null)
        )
    );
  }
}
