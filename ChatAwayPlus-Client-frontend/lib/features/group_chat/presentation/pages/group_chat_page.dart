import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/group_chat/models/group_models.dart';
import 'package:chataway_plus/features/group_chat/presentation/providers/group_providers.dart';
import 'package:chataway_plus/features/group_chat/data/group_chat_repository.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/common/chat_input_field.dart';
import 'package:chataway_plus/features/group_chat/presentation/widgets/group_chat_app_bar_widget.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/chat_background_widget.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// Full group chat screen — mirrors the look of OneToOneChatPage
class GroupChatPage extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupIcon;

  const GroupChatPage({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupIcon,
  });

  @override
  ConsumerState<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends ConsumerState<GroupChatPage> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final _uuid = const Uuid();
  String? _currentUserId;
  bool _isTyping = false;
  Timer? _typingThrottleTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _msgController.addListener(_onTextChanged);

    // Register listeners and join group room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GroupChatRepository.instance.registerSocketListeners();
      GroupChatRepository.instance.joinGroupRoom(widget.groupId);
    });
  }

  Future<void> _loadCurrentUser() async {
    final userId = await ChatHelper.getCurrentUserId();
    if (mounted) {
      setState(() => _currentUserId = userId);
      debugPrint('👤 [GroupChat] Identified Current User ID: $_currentUserId');
    }
  }

  void _onTextChanged() {
    if (_msgController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      GroupChatRepository.instance.startTyping(widget.groupId);
    } else if (_msgController.text.isEmpty && _isTyping) {
      _isTyping = false;
      _typingThrottleTimer?.cancel();
      GroupChatRepository.instance.stopTyping(widget.groupId);
    }

    // Throttle the typing event
    _typingThrottleTimer?.cancel();
    _typingThrottleTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        GroupChatRepository.instance.stopTyping(widget.groupId);
      }
    });
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    final clientMessageId = _uuid.v4();

    // Optimistic UI
    final pendingMsg = GroupMessageModel(
      id: clientMessageId,
      groupId: widget.groupId,
      senderId: _currentUserId!,
      senderName: 'You',
      message: text,
      messageType: 'text',
      createdAt: DateTime.now(),
      clientMessageId: clientMessageId,
    );

    ref.read(groupMessagesProvider(widget.groupId).notifier).addPendingMessage(pendingMsg);
    _msgController.clear();

    GroupChatRepository.instance.sendGroupMessage(
      groupId: widget.groupId,
      message: text,
      messageType: 'text',
      clientMessageId: clientMessageId,
    ).catchError((e) {
      ref.read(groupMessagesProvider(widget.groupId).notifier).markMessageFailed(clientMessageId);
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _msgController.removeListener(_onTextChanged);
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingThrottleTimer?.cancel();
    GroupChatRepository.instance.stopTyping(widget.groupId);
    GroupChatRepository.instance.leaveGroupRoom(widget.groupId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messagesAsync = ref.watch(groupMessagesProvider(widget.groupId));
    final groupAsync = ref.watch(groupDetailsProvider(widget.groupId));
    final typingUsers = ref.watch(groupTypingProvider(widget.groupId));

    final memberCount = groupAsync.valueOrNull?.members.length ?? 0;
    final groupName = groupAsync.valueOrNull?.name ?? widget.groupName;
    final groupIcon = groupAsync.valueOrNull?.icon ?? widget.groupIcon;

    return Scaffold(
      appBar: GroupChatAppBarWidget(
        group: groupAsync.valueOrNull,
        groupId: widget.groupId,
        groupName: groupName,
        groupIcon: groupIcon,
        onBackPressed: () => Navigator.of(context).maybePop(),
        onLeaveChat: () async {
          GroupChatRepository.instance.sendTyping(widget.groupId, isTyping: false);
          GroupChatRepository.instance.leaveGroupRoom(widget.groupId);
        },
      ),
      body: Stack(
        children: [
          ChatBackgroundWidget(),
          Column(
            children: [
              // Messages
              Expanded(
                child: messagesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load messages: $e',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.refresh(groupMessagesProvider(widget.groupId)),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (data) {
                    final messages = data as List<GroupMessageModel>;
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                    // Mark messages as read when they appear
                    final unreadIds = messages
                        .where((m) => m.senderId != _currentUserId && m.messageStatus != 'read')
                        .map((m) => m.id)
                        .toList();
                    if (unreadIds.isNotEmpty) {
                      Future.microtask(() {
                        ref.read(groupMessagesProvider(widget.groupId).notifier).markMessagesAsRead(unreadIds);
                      });
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        if (msg.messageType == 'system') {
                          return _SystemMessageBubble(message: msg.message ?? '');
                        }
                        final isMine = msg.senderId == _currentUserId;
                        
                        if (index == messages.length - 1) {
                          debugPrint('💬 [GroupChat] Last Message Comparison:');
                          debugPrint('   - msg.senderId: ${msg.senderId}');
                          debugPrint('   - _currentUserId: $_currentUserId');
                          debugPrint('   - isMine: $isMine');
                        }

                        // Check if we should show tail (last message in a sequence or single message)
                        bool showTail = true;
                        if (index < messages.length - 1) {
                          final nextMsg = messages[index + 1];
                          if (nextMsg.senderId == msg.senderId && nextMsg.messageType != 'system') {
                            showTail = false;
                          }
                        }

                        return _MessageBubble(
                          message: msg,
                          isMine: isMine,
                          isDark: isDark,
                          showSenderName: !isMine,
                          showTail: showTail,
                          memberCount: memberCount,
                          onRetry: () => ref.read(groupMessagesProvider(widget.groupId).notifier).retryMessage(msg),
                        );
                      },
                    );
                  },
                ),
              ),

              // Input bar
              ChatInputField(
                textController: _msgController,
                focusNode: _focusNode,
                onSend: _sendMessage,
                onEditSave: () {},
                onEditCancel: () {},
                onTextChanged: (val) => _onTextChanged(),
                isSending: false,
                isSavingEdit: false,
                isEditing: false,
                editingLabel: null,
                onCameraTap: () {},
                onGalleryTap: () {},
                onDocumentTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

// Methods removed as they are replaced by standalone widgets
}

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGE BUBBLE
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final GroupMessageModel message;
  final bool isMine;
  final bool isDark;
  final bool showSenderName;
  final bool showTail;
  final int memberCount;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isDark,
    required this.showSenderName,
    required this.memberCount,
    this.showTail = true,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final senderBubbleColor = isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6);
    final receiverBubbleColor = isDark ? const Color(0xFF1F2C34) : Colors.white;

    final bubbleColor = isMine ? senderBubbleColor : receiverBubbleColor;

    final textColor = isDark ? Colors.white : Colors.black;
    final timeColor = isDark ? Colors.white54 : Colors.black45;

    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: isMine ? 64 : 0,
          right: isMine ? 0 : 64,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMine ? 12 : (showTail ? 0 : 12)),
            bottomRight: Radius.circular(isMine ? (showTail ? 0 : 12) : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sender name (for others' messages)
              if (showSenderName && !isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    message.senderName.isNotEmpty ? message.senderName : 'Unknown',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _senderColor(message.senderId),
                    ),
                  ),
                ),

              // Message content with inline-style layout
              _buildMessageBody(context, textColor, time, timeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBody(BuildContext context, Color textColor, String time, Color timeColor) {
    final text = message.message ?? '';

    // Simple layout to keep time on the same line if possible
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 4,
      spacing: 8,
      children: [
        if (message.messageType != 'text')
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_typeIcon(message.messageType), size: 16, color: textColor),
              const SizedBox(width: 4),
              Text(message.previewText,
                  style: TextStyle(color: textColor, fontSize: 14, fontStyle: FontStyle.italic)),
            ],
          ),
        if (text.isNotEmpty)
          Text(
            text,
            style: TextStyle(color: textColor, fontSize: 15.5, height: 1.2),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: TextStyle(fontSize: 11, color: timeColor),
              ),
              if (isMine) ...[
                const SizedBox(width: 4),
                MessageDeliveryStatusIcon(
                  status: message.getGlobalStatus(memberCount - 1),
                  size: 14,
                  color: timeColor,
                ),
                if (message.messageStatus == 'failed')
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to send message'),
                            backgroundColor: Colors.red,
                            action: SnackBarAction(
                              label: 'Retry',
                              textColor: Colors.white,
                              onPressed: () => onRetry?.call(),
                            ),
                          ),
                        );
                      },
                      child: const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    ),
                  ),
                if (message.readCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    'Seen by ${message.readCount}',
                    style: TextStyle(fontSize: 10, color: timeColor.withOpacity(0.7)),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _senderColor(String userId) {
    // WhatsApp-style deterministic colour per user
    final colors = [
      Colors.teal,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
      Colors.green,
      Colors.red,
    ];
    final idx = userId.hashCode.abs() % colors.length;
    return colors[idx];
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.mic_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'contact':
        return Icons.person_rounded;
      case 'poll':
        return Icons.poll_rounded;
      default:
        return Icons.message_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPING INDICATOR
// ─────────────────────────────────────────────────────────────────────────────
class _TypingIndicator extends StatelessWidget {
  final Set<String> typingUsers;
  final bool isDark;

  const _TypingIndicator({required this.typingUsers, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final usersList = typingUsers.toList();
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        typingUsers.isEmpty
            ? ''
            : typingUsers.length == 1
                ? '${usersList[0]} is typing...'
                : typingUsers.length == 2
                    ? '${usersList[0]} and ${usersList[1]} are typing...'
                    : '${typingUsers.length} people are typing...',
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: isDark ? Colors.white54 : Colors.grey[600],
        ),
      ),
    );
  }
}

class _SystemMessageBubble extends StatelessWidget {
  final String message;

  const _SystemMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
