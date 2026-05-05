import { Request, Response } from 'express';
import { Op } from 'sequelize';
import { v4 as uuidv4 } from 'uuid';
import Group from '../db/models/group.model';
import GroupMember from '../db/models/group-member.model';
import GroupMessage from '../db/models/group-message.model';
import User from '../db/models/user.model';
import GroupMessageStatus from '../db/models/group-message-status.model';
import { sendToAllUserDevices } from '../services/fcm.service';

interface AuthenticatedRequest extends Request {
  user?: { id: string; email: string; firstName?: string; lastName?: string; mobileNo?: string };
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE GROUP
// ─────────────────────────────────────────────────────────────────────────────
export async function createGroup(req: AuthenticatedRequest, res: Response) {
  try {
    const { name, description, memberIds, isRestricted, icon } = req.body;
    const creatorId = req.user!.id;

    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Group name is required' });
    }
    if (!memberIds || !Array.isArray(memberIds) || memberIds.length === 0) {
      return res.status(400).json({ error: 'At least one member is required' });
    }

    const group = await Group.create({
      name: name.trim(),
      description: description?.trim() || null,
      icon: icon || null,
      createdBy: creatorId,
      isRestricted: isRestricted || false,
    });

    // Add creator as admin
    const uniqueMembers = [...new Set([...memberIds, creatorId])];
    await Promise.all(
      uniqueMembers.map((userId: string) =>
        GroupMember.create({
          groupId: group.dataValues.id,
          userId,
          role: userId === creatorId ? 'admin' : 'member',
        })
      )
    );

    // Send system message
    const creator = await User.findByPk(creatorId, { attributes: ['firstName', 'lastName'] });
    const creatorName = creator ? `${(creator as any).firstName || ''} ${(creator as any).lastName || ''}`.trim() : 'Someone';
    await _sendSystemMessage(group.dataValues.id, creatorId, `${creatorName} created this group`);

    // Fetch full group with members
    const fullGroup = await _getGroupWithMembers(group.dataValues.id);
    return res.status(201).json({ success: true, data: fullGroup });
  } catch (error) {
    console.error('❌ createGroup error:', error);
    return res.status(500).json({ error: 'Failed to create group' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GET MY GROUPS
// ─────────────────────────────────────────────────────────────────────────────
export async function getMyGroups(req: AuthenticatedRequest, res: Response) {
  try {
    const userId = req.user!.id;

    const memberships = await GroupMember.findAll({
      where: { userId },
      attributes: ['groupId', 'role'],
      raw: true,
    });

    const groupIds = memberships.map((m: any) => m.groupId);
    if (groupIds.length === 0) {
      return res.json({ success: true, data: [] });
    }

    const groups = await Group.findAll({
      where: { id: { [Op.in]: groupIds }, isDeleted: false },
      raw: true,
    });

    // Attach last message + member count + unread count per group
    const enriched = await Promise.all(
      groups.map(async (g: any) => {
        const [lastMsg, memberCount, unreadCount] = await Promise.all([
          GroupMessage.findOne({
            where: { groupId: g.id, isDeleted: false },
            order: [['createdAt', 'DESC']],
            include: [{ model: User, as: 'sender', attributes: ['id', 'firstName', 'lastName'] }],
          }),
          GroupMember.count({ where: { groupId: g.id } }),
          (async () => {
            const membership = memberships.find((m: any) => m.groupId === g.id);
            if (!membership?.lastSeenMessageId) {
              return GroupMessage.count({ where: { groupId: g.id, senderId: { [Op.ne]: userId } } });
            }
            const lastSeen = await GroupMessage.findByPk(membership.lastSeenMessageId, { attributes: ['createdAt'] });
            if (!lastSeen) return 0;
            return GroupMessage.count({
              where: {
                groupId: g.id,
                senderId: { [Op.ne]: userId },
                createdAt: { [Op.gt]: lastSeen.createdAt },
              },
            });
          })(),
        ]);

        const membership = memberships.find((m: any) => m.groupId === g.id);

        return {
          ...g,
          role: membership?.role || 'member',
          memberCount,
          lastMessage: lastMsg
            ? {
                id: (lastMsg as any).id,
                message: (lastMsg as any).message,
                messageType: (lastMsg as any).messageType,
                senderId: (lastMsg as any).senderId,
                senderName: `${(lastMsg as any).sender?.firstName || ''} ${(lastMsg as any).sender?.lastName || ''}`.trim(),
                createdAt: (lastMsg as any).createdAt,
              }
            : null,
        };
      })
    );

    return res.json({ success: true, data: enriched });
  } catch (error) {
    console.error('❌ getMyGroups error:', error);
    return res.status(500).json({ error: 'Failed to fetch groups' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GET GROUP DETAILS
// ─────────────────────────────────────────────────────────────────────────────
export async function getGroupDetails(req: AuthenticatedRequest, res: Response) {
  try {
    const { groupId } = req.params;
    const userId = req.user!.id;

    const membership = await GroupMember.findOne({ where: { groupId, userId }, raw: true });
    if (!membership) {
      return res.status(403).json({ error: 'Not a member of this group' });
    }

    const group = await _getGroupWithMembers(groupId);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    return res.json({ success: true, data: group });
  } catch (error) {
    console.error('❌ getGroupDetails error:', error);
    return res.status(500).json({ error: 'Failed to fetch group details' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UPDATE GROUP INFO
// ─────────────────────────────────────────────────────────────────────────────
export async function updateGroup(req: AuthenticatedRequest, res: Response) {
  try {
    const { groupId } = req.params;
    const userId = req.user!.id;
    const { name, description, icon, isRestricted } = req.body;

    const membership = await GroupMember.findOne({ where: { groupId, userId }, raw: true });
    if (!membership || (membership as any).role !== 'admin') {
      return res.status(403).json({ error: 'Only admins can update group info' });
    }

    const updates: any = {};
    if (name !== undefined) updates.name = name.trim();
    if (description !== undefined) updates.description = description?.trim() || null;
    if (icon !== undefined) updates.icon = icon;
    if (isRestricted !== undefined) updates.isRestricted = isRestricted;

    await Group.update(updates, { where: { id: groupId } });
    const group = await _getGroupWithMembers(groupId);

    return res.json({ success: true, data: group });
  } catch (error) {
    console.error('❌ updateGroup error:', error);
    return res.status(500).json({ error: 'Failed to update group' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD MEMBERS
// ─────────────────────────────────────────────────────────────────────────────
export async function addMembers(req: AuthenticatedRequest, res: Response) {
  try {
    const { groupId } = req.params;
    const userId = req.user!.id;
    const { memberIds } = req.body;

    const membership = await GroupMember.findOne({ where: { groupId, userId }, raw: true });
    if (!membership || (membership as any).role !== 'admin') {
      return res.status(403).json({ error: 'Only admins can add members' });
    }

    const group = await Group.findOne({ where: { id: groupId, isDeleted: false }, raw: true });
    if (!group) return res.status(404).json({ error: 'Group not found' });

    await Promise.all(
      (memberIds as string[]).map((uid) =>
        GroupMember.findOrCreate({
          where: { groupId, userId: uid },
          defaults: { groupId, userId: uid, role: 'member' } as any,
        })
      )
    );

    // Send system message
    const admin = await User.findByPk(userId, { attributes: ['firstName', 'lastName'] });
    const adminName = admin ? `${(admin as any).firstName || ''} ${(admin as any).lastName || ''}`.trim() : 'Admin';
    
    const addedUsers = await User.findAll({ 
      where: { id: { [Op.in]: memberIds } },
      attributes: ['firstName', 'lastName']
    });
    const addedNames = addedUsers.map(u => `${(u as any).firstName || ''} ${(u as any).lastName || ''}`.trim()).join(', ');
    
    await _sendSystemMessage(groupId, userId, `${adminName} added ${addedNames}`);

    const updated = await _getGroupWithMembers(groupId);
    return res.json({ success: true, data: updated });
  } catch (error) {
    console.error('❌ addMembers error:', error);
    return res.status(500).json({ error: 'Failed to add members' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REMOVE MEMBER / LEAVE GROUP
// ─────────────────────────────────────────────────────────────────────────────
export async function removeMember(req: AuthenticatedRequest, res: Response) {
  try {
    const { groupId, targetUserId } = req.params;
    const userId = req.user!.id;

    const isLeavingSelf = userId === targetUserId;

    if (!isLeavingSelf) {
      const membership = await GroupMember.findOne({ where: { groupId, userId }, raw: true });
      if (!membership || (membership as any).role !== 'admin') {
        return res.status(403).json({ error: 'Only admins can remove members' });
      }
    }

    await GroupMember.destroy({ where: { groupId, userId: targetUserId } });

    // Send system message
    const actor = await User.findByPk(userId, { attributes: ['firstName', 'lastName'] });
    const actorName = actor ? `${(actor as any).firstName || ''} ${(actor as any).lastName || ''}`.trim() : 'Someone';

    if (isLeavingSelf) {
      await _sendSystemMessage(groupId, targetUserId, `${actorName} left the group`);
    } else {
      const target = await User.findByPk(targetUserId, { attributes: ['firstName', 'lastName'] });
      const targetName = target ? `${(target as any).firstName || ''} ${(target as any).lastName || ''}`.trim() : 'Member';
      await _sendSystemMessage(groupId, userId, `${actorName} removed ${targetName}`);
    }
    return res.json({ success: true, message: isLeavingSelf ? 'Left group' : 'Member removed' });
  } catch (error) {
    console.error('❌ removeMember error:', error);
    return res.status(500).json({ error: 'Failed to remove member' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE GROUP
// ─────────────────────────────────────────────────────────────────────────────
export async function deleteGroup(req: AuthenticatedRequest, res: Response) {
  try {
    const { groupId } = req.params;
    const userId = req.user!.id;

    const group = await Group.findOne({ where: { id: groupId }, raw: true });
    if (!group) return res.status(404).json({ error: 'Group not found' });
    if ((group as any).createdBy !== userId) {
      return res.status(403).json({ error: 'Only the group creator can delete the group' });
    }

    await Group.update({ isDeleted: true }, { where: { id: groupId } });
    return res.json({ success: true, message: 'Group deleted' });
  } catch (error) {
    console.error('❌ deleteGroup error:', error);
    return res.status(500).json({ error: 'Failed to delete group' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GET GROUP MESSAGES (history / pagination)
// ─────────────────────────────────────────────────────────────────────────────
export async function getGroupMessages(req: AuthenticatedRequest, res: Response) {
  try {
    const { groupId } = req.params;
    const userId = req.user!.id;
    const { page = 1, limit = 50, sinceMessageId, beforeMessageId } = req.query;

    const membership = await GroupMember.findOne({ where: { groupId, userId }, raw: true });
    if (!membership) {
      return res.status(403).json({ error: 'Not a member of this group' });
    }

    const pageNum = Number(page);
    const limitNum = Number(limit);
    const offset = (pageNum - 1) * limitNum;

    const whereCondition: any = { groupId, isDeleted: false };

    if (sinceMessageId && typeof sinceMessageId === 'string') {
      const ref = await GroupMessage.findByPk(sinceMessageId, { attributes: ['createdAt'] });
      if (ref) {
        whereCondition.createdAt = { [Op.gt]: (ref as any).createdAt };
      }
    }
    
    if (beforeMessageId && typeof beforeMessageId === 'string') {
      const ref = await GroupMessage.findByPk(beforeMessageId, { attributes: ['createdAt'] });
      if (ref) {
        whereCondition.createdAt = { [Op.lt]: (ref as any).createdAt };
      }
    }

    const result = await GroupMessage.findAndCountAll({
      where: whereCondition,
      order: [['createdAt', 'DESC']],
      limit: limitNum,
      offset,
      include: [
        {
          model: User,
          as: 'sender',
          attributes: ['id', 'firstName', 'lastName', 'chat_picture'],
        },
        {
          model: GroupMessage,
          as: 'replyToMessage',
          attributes: ['id', 'senderId', 'message', 'messageType'],
          include: [{ model: User, as: 'sender', attributes: ['id', 'firstName', 'lastName'] }],
          required: false,
        },
      ],
    });

    return res.json({
      success: true,
      data: {
        messages: await Promise.all(result.rows.reverse().map(async (msg: any) => {
          const statuses = await GroupMessageStatus.findAll({ where: { messageId: msg.id }, raw: true });
          const statusMap: any = {};
          statuses.forEach(s => statusMap[s.userId] = s.status);
          return {
            ...msg.toJSON(),
            senderName: `${msg.sender?.firstName || ''} ${msg.sender?.lastName || ''}`.trim(),
            senderAvatar: msg.sender?.chat_picture || null,
            statusPerUser: statusMap
          };
        })),
        hasMore: result.rows.length === limitNum,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total: result.count,
          totalPages: Math.ceil(result.count / limitNum),
        },
      },
    });
  } catch (error) {
    console.error('❌ getGroupMessages error:', error);
    return res.status(500).json({ error: 'Failed to fetch group messages' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEND GROUP MESSAGE VIA REST (fallback when socket unavailable)
// ─────────────────────────────────────────────────────────────────────────────
export async function sendGroupMessage(req: AuthenticatedRequest, res: Response) {
  try {
    const { groupId } = req.params;
    const senderId = req.user!.id;
    const { message, messageType, fileUrl, mimeType, contactPayload, pollPayload, imageWidth, imageHeight,
      audioDuration, videoThumbnailUrl, videoDuration, replyToMessageId } = req.body;

    const membership = await GroupMember.findOne({ where: { groupId, userId: senderId }, raw: true });
    if (!membership) return res.status(403).json({ error: 'Not a member of this group' });

    const group = await Group.findOne({ where: { id: groupId, isDeleted: false }, raw: true });
    if (!group) return res.status(404).json({ error: 'Group not found or deleted' });

    if ((group as any).isRestricted && (membership as any).role !== 'admin') {
      return res.status(403).json({ error: 'Only admins can send messages in this group' });
    }

    let replyToMessageText: string | null = null;
    let replyToMessageSenderId: string | null = null;
    let replyToMessageType: string | null = null;
    if (replyToMessageId) {
      const replied = await GroupMessage.findByPk(replyToMessageId, { attributes: ['message', 'senderId', 'messageType'] });
      if (replied) {
        replyToMessageText = (replied as any).message;
        replyToMessageSenderId = (replied as any).senderId;
        replyToMessageType = (replied as any).messageType;
      }
    }

    const msg = await GroupMessage.create({
      groupId,
      senderId,
      message: message || null,
      messageType: messageType || 'text',
      fileUrl: fileUrl || null,
      mimeType: mimeType || null,
      contactPayload: contactPayload || null,
      pollPayload: pollPayload || null,
      imageWidth: imageWidth ? parseInt(imageWidth) : null,
      imageHeight: imageHeight ? parseInt(imageHeight) : null,
      audioDuration: audioDuration ? parseFloat(audioDuration) : null,
      videoThumbnailUrl: videoThumbnailUrl || null,
      videoDuration: videoDuration ? parseFloat(videoDuration) : null,
      replyToMessageId: replyToMessageId || null,
      replyToMessageText,
      replyToMessageSenderId,
      replyToMessageType,
    });

    // Send FCM to all group members except sender (offline notification)
    const members = await GroupMember.findAll({ where: { groupId }, attributes: ['userId'], raw: true });
    const sender = await User.findByPk(senderId, { attributes: ['firstName', 'lastName', 'chat_picture'], raw: true });
    const senderName = sender ? `${(sender as any).firstName || ''} ${(sender as any).lastName || ''}`.trim() : 'Someone';

    let displayText = message;
    if (!displayText || displayText.trim() === '') {
      const typeMap: Record<string, string> = { image: '📷 Photo', video: '🎥 Video', pdf: '📄 Document', contact: '👤 Contact', audio: '🎤 Voice message' };
      displayText = typeMap[messageType] || 'New message';
    }

    await Promise.all(
      members
        .filter((m: any) => m.userId !== senderId)
        .map((m: any) =>
          sendToAllUserDevices({
            userId: m.userId,
            messageUuid: (msg as any).id,
            messageType: 'chat_message',
            conversationId: groupId,
            data: {
              chatId: (msg as any).id,
              senderId,
              senderFirstName: senderName,
              sender_chat_picture: (sender as any)?.chat_picture || '',
              sender_mobile_number: '',
              messageText: displayText,
              chatType: 'group_message',
              groupId,
              groupName: (group as any).name,
            },
          }).catch(() => null)
        )
    );

    return res.status(201).json({ success: true, data: msg });
  } catch (error) {
    console.error('❌ sendGroupMessage error:', error);
    return res.status(500).json({ error: 'Failed to send group message' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROMOTE / DEMOTE MEMBER
// ─────────────────────────────────────────────────────────────────────────────
export async function updateMemberRole(req: AuthenticatedRequest, res: Response) {
  try {
    const { groupId, targetUserId } = req.params;
    const { role } = req.body;
    const userId = req.user!.id;

    if (!['admin', 'member'].includes(role)) {
      return res.status(400).json({ error: 'Role must be admin or member' });
    }

    const membership = await GroupMember.findOne({ where: { groupId, userId }, raw: true });
    if (!membership || (membership as any).role !== 'admin') {
      return res.status(403).json({ error: 'Only admins can change roles' });
    }

    await GroupMember.update({ role }, { where: { groupId, userId: targetUserId } });
    return res.json({ success: true, message: `Role updated to ${role}` });
  } catch (error) {
    console.error('❌ updateMemberRole error:', error);
    return res.status(500).json({ error: 'Failed to update member role' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL HELPER
// ─────────────────────────────────────────────────────────────────────────────
async function _getGroupWithMembers(groupId: string) {
  const group = await Group.findOne({
    where: { id: groupId },
    include: [
      {
        model: GroupMember,
        as: 'members',
        include: [{ model: User, as: 'user', attributes: ['id', 'firstName', 'lastName', 'mobileNo', 'chat_picture'] }],
      },
      { model: User, as: 'creator', attributes: ['id', 'firstName', 'lastName'] },
    ],
  });
  return group;
}

async function _sendSystemMessage(groupId: string, senderId: string, message: string) {
  try {
    const msg = await GroupMessage.create({
      groupId,
      senderId,
      message,
      messageType: 'system',
    });

    // Notify members via FCM (optional for system messages, but good for real-time)
    const members = await GroupMember.findAll({ where: { groupId }, attributes: ['userId'], raw: true });
    const group = await Group.findByPk(groupId, { attributes: ['name'], raw: true });

    await Promise.all(
      members.map((m: any) =>
        sendToAllUserDevices({
          userId: m.userId,
          messageUuid: (msg as any).id,
          messageType: 'chat_message',
          conversationId: groupId,
          data: {
            chatId: (msg as any).id,
            senderId,
            senderFirstName: 'System',
            sender_chat_picture: '',
            messageText: message,
            chatType: 'group_message',
            groupId,
            groupName: (group as any)?.name || 'Group',
            messageType: 'system',
          },
        }).catch(() => null)
      )
    );
  } catch (err) {
    console.error('❌ _sendSystemMessage error:', err);
  }
}
