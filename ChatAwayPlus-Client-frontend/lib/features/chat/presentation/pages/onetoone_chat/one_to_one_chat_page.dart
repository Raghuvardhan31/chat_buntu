// Updated: fixes for keyboard jump, safe scrolling, and snackbars
// File: individual_and_chatlist_fixed.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_interactions/message_reaction_display.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_interactions/delete_selection_dialog.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_interactions/star_message_action.dart';
import 'package:chataway_plus/features/chat/presentation/providers/message_reactions/message_reaction_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/chat_page_provider.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/chat_page_notifier.dart';
import 'package:chataway_plus/core/notifications/local/notification_services.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/message_status_stream_provider.dart';
import 'package:chataway_plus/features/chat/presentation/providers/chat_page_providers/user_status_provider.dart';
import 'package:chataway_plus/features/chat/data/services/chat_engine/index.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/contacts_management.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';
import 'package:chataway_plus/features/blocked_contacts/presentation/providers/blocked_contacts/blocked_contacts_providers.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/app_lifecycle/app_state_service.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/common/chat_input_field.dart';
import 'package:chataway_plus/core/database/tables/chat/follow_ups_table.dart';
import 'package:chataway_plus/features/chat/presentation/pages/forward_message/forward_message_page.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/outgoing_call_page.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';
import 'package:chataway_plus/features/voice_call/data/config/agora_config.dart';
import 'package:chataway_plus/features/chat/presentation/pages/onetoone_chat/mixins/media_attachment_mixin.dart';
import 'package:chataway_plus/features/location_sharing/presentation/pages/location_picker_page.dart';
import 'package:chataway_plus/features/location_sharing/data/models/location_model.dart';
import 'package:chataway_plus/core/services/permissions/permission_manager.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/contact_not_found_banner.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_interactions/whatsapp_reaction_overlay.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_interactions/message_action_bar.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/message_interactions/message_selection_overlay.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/blocked_contact_panel.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_info_sheet_widget.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/chat_background_widget.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/chat_app_bar_widget.dart';
import 'package:chataway_plus/features/chat/presentation/pages/onetoone_chat/mixins/chat_event_handlers_mixin.dart';
import 'package:chataway_plus/features/chat/presentation/pages/onetoone_chat/widgets/chat_message_list.dart';
import 'package:chataway_plus/core/routes/route_names.dart';
import 'package:uuid/uuid.dart';

// -----------------------------------------------------------------------------
// IndividualChatPage (fixed)
// -----------------------------------------------------------------------------
class OneToOneChatPage extends ConsumerStatefulWidget {
  final String contactName;
  final String receiverId;
  final String currentUserId;
  final bool? storyReply;
  final String? storyReplyText;
  final bool? autoFocusInput;
  final String? expressHubReplyText;
  final String? expressHubReplyType;

  const OneToOneChatPage({
    super.key,
    required this.contactName,
    required this.receiverId,
    required this.currentUserId,
    this.storyReply,
    this.storyReplyText,
    this.autoFocusInput,
    this.expressHubReplyText,
    this.expressHubReplyType,
  });

  @override
  ConsumerState<OneToOneChatPage> createState() => _OneToOneChatPageState();
}

class _OneToOneChatPageState extends ConsumerState<OneToOneChatPage>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        MediaAttachmentMixin,
        ChatEventHandlersMixin {
  static const String _followUpPrefix = 'Follow up Text:';

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final GlobalKey _chatBodyKey = GlobalKey();
  final Map<String, LayerLink> _messageLayerLinks = <String, LayerLink>{};
  final Map<String, GlobalKey> _messageBubbleKeys = <String, GlobalKey>{};
  final Map<String, String> _uiMessageReactions = <String, String>{};
  String? _overlayMessageId;
  bool _overlayShowBelow = false;
  double _overlayDx = 0;
  List<FollowUpEntry> _followUpEntries = [];
  bool _isLoadingFollowUps = false;
  String? _replyToFollowUpText;
  String? _replyToFollowUpDateTime;
  ChatMessageModel? _replyToMessage;
  bool _isReplyingToStory = false;
  String? _storyReplyText;
  bool _isReplyingToExpressHub = false;
  String? _expressHubReplyText;
  String? _expressHubReplyType;
  final GlobalKey<ChatInputFieldState> _chatInputKey =
      GlobalKey<ChatInputFieldState>();

  bool _showJumpToLatest = false;
  String? _highlightedMessageId;

  ChatMessageModel? _editingMessage;
  bool _isSavingEdit = false;

  final ChatEngineService _unifiedChatService = ChatEngineService.instance;

  // Required overrides for ChatEventHandlersMixin
  @override
  ChatEngineService get unifiedChatService => _unifiedChatService;

  @override
  double snackbarBottomPosition() => _snackbarBottomPosition();

  String? _lastShownError;

  // NEW: Prevent double taps / concurrent sends
  bool _isSending = false;
  bool _isInitiatingCall = false;

  double _snackbarBottomPosition() {
    final width = context.screenWidth;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );
    return responsive.size(120);
  }

  void _handleFollowUpAttachment() {
    // Magic follow-up: Insert "Follow up Text: " in the input field
    _textController.text = '$_followUpPrefix ';
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
    // Focus the input field so user can continue typing
    _messageFocusNode.requestFocus();
  }

  void _handlePollAttachment() async {
    final result = await Navigator.of(context).pushNamed(RouteNames.createPoll);
    if (result != null && result is Map<String, dynamic>) {
      await handlePollShare(result);
    }
  }

  void _handleVideoAttachmentReal() => handleVideoAttachment();

  void _handleContactShare() => handleContactShare();

  Future<void> _handleLocationShare() async {
    final granted = await PermissionManager.instance.ensurePermissionGranted(
      AppPermissionType.location,
      context: context,
      customRationale:
          'ChatAway+ needs access to your location to share it in this chat.',
    );
    if (!granted) {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Location permission is required to share your location',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 2),
      );
      return;
    }
    if (!mounted) return;
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const LocationPickerPage()));
    if (result == null || !mounted) return;
    if (result is LocationModel) {
      await handleSendLocationMessage(result);
    }
  }

  // ── Audio Recording ──

  Future<void> _startAudioRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        AppSnackbar.showError(
          context,
          'Microphone permission required',
          bottomPosition: _snackbarBottomPosition(),
          duration: const Duration(seconds: 2),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      debugPrint('🎤 Audio recording started: $filePath');
    } catch (e) {
      debugPrint('❌ Failed to start recording: $e');
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Failed to start recording',
        bottomPosition: _snackbarBottomPosition(),
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _stopAudioRecording(int durationSeconds) async {
    try {
      final path = await _audioRecorder.stop();
      debugPrint('🎤 Audio recording stopped: $path (${durationSeconds}s)');
      if (mounted) {
        setState(() {
          _recordedAudioPath = path;
          _recordedDurationSeconds = durationSeconds;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to stop recording: $e');
    }
  }

  Future<void> _cancelAudioRecording() async {
    try {
      final path = await _audioRecorder.stop();
      debugPrint('🎤 Audio recording cancelled, discarding: $path');
      // Delete the temp file
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cancelling recording: $e');
    }
    if (mounted) {
      setState(() {
        _recordedAudioPath = null;
        _recordedDurationSeconds = 0;
      });
    }
  }

  Future<void> _handleAudioSendConfirmed() async {
    final path = _recordedAudioPath;
    final duration = _recordedDurationSeconds;

    if (path == null || path.isEmpty) {
      debugPrint('❌ No recorded audio path');
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      debugPrint('❌ Recorded audio file not found: $path');
      return;
    }

    if (!mounted) return;

    // Reset state
    setState(() {
      _recordedAudioPath = null;
      _recordedDurationSeconds = 0;
    });

    await handleSendAudioMessage(file, duration.toDouble());
  }

  Future<void> _handleCall(CallType type) async {
    if (_isInitiatingCall) {
      debugPrint('📞 [_handleCall] Already initiating a call, ignoring.');
      return;
    }

    setState(() => _isInitiatingCall = true);

    try {
      debugPrint(
        '📞 [_handleCall] Initiating ${type.name} call to ${widget.receiverId}',
      );
      // 1. Permission checks
      final List<AppPermissionType> permissions = [
        AppPermissionType.microphone,
      ];
      if (type == CallType.video) {
        permissions.add(AppPermissionType.camera);
      }

      bool allGranted = true;
      for (final p in permissions) {
        debugPrint('📞 [_handleCall] Checking permission: ${p.name}');
        final granted = await PermissionManager.instance
            .ensurePermissionGranted(p, context: context);
        if (!granted) {
          debugPrint('📞 [_handleCall] Permission ${p.name} denied');
          allGranted = false;
          break;
        }
      }

      if (!allGranted) {
        if (mounted) {
          AppSnackbar.showError(
            context,
            'Permissions required to start a call',
            bottomPosition: _snackbarBottomPosition(),
          );
        }
        return;
      }

      if (!mounted) return;

      // 2. Connectivity check
      debugPrint('📞 [_handleCall] Checking connectivity...');
      if (!_unifiedChatService.isConnectedToServer) {
        debugPrint('📞 [_handleCall] Socket not connected');
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Check your connection",
        );
        return;
      }

      // 3. Check if blocked
      debugPrint('📞 [_handleCall] Checking if blocked...');
      if (_isBlocked) {
        debugPrint('📞 [_handleCall] Contact is blocked');
        AppSnackbar.showError(
          context,
          'Cannot call a blocked contact',
          bottomPosition: _snackbarBottomPosition(),
        );
        return;
      }

      // 4. Generate IDs
      final String callId = const Uuid().v4();
      final String channelName = AgoraConfig.generateOneToOneChannelName(
        widget.currentUserId,
        widget.receiverId,
      );
      debugPrint(
        '📞 [_handleCall] IDs generated: callId=$callId, channel=$channelName',
      );

      // 5. Navigate to OutgoingCallPage
      if (mounted) {
        debugPrint('📞 [_handleCall] Navigating to OutgoingCallPage...');
        final completer = Completer<void>();
        // Use post frame callback to ensure we are not in the middle of a build
        // which can happen if the keyboard dismissal triggered a layout change.
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted) {
            try {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => OutgoingCallPage(
                    currentUserId: widget.currentUserId,
                    contactId: widget.receiverId,
                    contactName: widget.contactName,
                    callType: type,
                    channelName: channelName,
                    callId: callId,
                  ),
                ),
              );
            } catch (e) {
              debugPrint('❌ [_handleCall] Navigator push error: $e');
            }
          }
          completer.complete();
        });
        await completer.future;
      }
    } catch (e) {
      debugPrint('❌ [_handleCall] Error initiating call: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitiatingCall = false);
      }
    }
  }

  // TODO: Happy Update feature - temporarily hidden
  // void _handleTwitterShare() => _showAttachmentStub('Happy Update');

  // Track attachment panel visibility for external rendering
  bool _showAttachmentPanel = false;

  // Audio recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordedAudioPath;
  int _recordedDurationSeconds = 0;

  bool _isBlocked = false;
  bool _isUnblocking = false;

  // WHATSAPP-STYLE: Profile update subscription
  StreamSubscription? _profileUpdateSub;

  String get _contactName => widget.contactName;
  String get _currentUserId => widget.currentUserId;

  // Required getters for MediaAttachmentMixin
  @override
  String get receiverId => widget.receiverId;
  @override
  String get currentUserId => widget.currentUserId;
  @override
  String get contactName => widget.contactName;
  @override
  Map<String, String> get providerParams => _providerParams;

  late final Map<String, String> _providerParams = {
    'otherUserId': widget.receiverId,
    'currentUserId': widget.currentUserId,
  };

  Future<void> _loadFollowUps() async {
    final currentUserId = widget.currentUserId.trim();
    final contactId = widget.receiverId.trim();
    if (currentUserId.isEmpty || contactId.isEmpty) {
      if (mounted) {
        setState(() => _followUpEntries = []);
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingFollowUps = true);
    }

    try {
      final entries = await FollowUpsTable.instance.getFollowUpEntries(
        currentUserId: currentUserId,
        contactId: contactId,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _followUpEntries = entries;
        _isLoadingFollowUps = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingFollowUps = false);
    }
  }

  void _handleFollowUpSelected(dynamic result) {
    if (result is FollowUpEntry) {
      _populateFollowUpReply(result);
    }
  }

  void _populateFollowUpReply(FollowUpEntry entry) {
    final raw = entry.text.trim();
    final followUpText =
        raw.toLowerCase().startsWith(_followUpPrefix.toLowerCase())
        ? raw.substring(_followUpPrefix.length).trim()
        : raw;
    final dateTime = _formatDateTime(entry.createdAt);

    setState(() {
      _replyToFollowUpText = followUpText;
      _replyToFollowUpDateTime = dateTime;
    });

    // Clear the text controller and focus for new input
    _textController.clear();
    _messageFocusNode.requestFocus();
  }

  void _clearFollowUpReply() {
    setState(() {
      _replyToFollowUpText = null;
      _replyToFollowUpDateTime = null;
    });
  }

  void _clearStoryReply() {
    setState(() {
      _isReplyingToStory = false;
      _storyReplyText = null;
    });
  }

  void _clearExpressHubReply() {
    setState(() {
      _isReplyingToExpressHub = false;
      _expressHubReplyText = null;
      _expressHubReplyType = null;
    });
  }

  void _autoFocusTextFieldForStoryReply() {
    // Add a small delay to ensure the UI is fully built
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Focus the message input field to show keyboard for story reply
        _messageFocusNode.requestFocus();
      }
    });
  }

  String _formatDateTime(DateTime dateTime) {
    // Use 12-hour format with AM/PM like Connection Insight Hub
    final localTime = dateTime.toLocal();
    final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final ampm = localTime.hour >= 12 ? 'PM' : 'AM';
    final timePart = '$hour:$minute $ampm';

    // Always show actual date for follow-ups to avoid confusion with chat messages
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} $timePart';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // CRITICAL: Set active conversation IMMEDIATELY to suppress notifications
    // Don't wait for addPostFrameCallback - notifications could arrive in that window
    _unifiedChatService.setActiveConversationImmediate(widget.receiverId);
    AppStateService.instance.setCurrentChat(widget.receiverId);

    _scrollControllerAddListener();

    // Initialize story reply context if provided
    if (widget.storyReply == true && widget.storyReplyText != null) {
      _isReplyingToStory = true;
      _storyReplyText = widget.storyReplyText;
    }

    // Initialize Express Hub reply context if provided
    if (widget.expressHubReplyText != null &&
        widget.expressHubReplyText!.trim().isNotEmpty) {
      _isReplyingToExpressHub = true;
      _expressHubReplyText = widget.expressHubReplyText;
      _expressHubReplyType = widget.expressHubReplyType;
    }

    Future.microtask(() {
      if (!mounted) return;
      // CRITICAL: Invalidate stale provider to prevent showing old messages
      // from a previous visit. Moved here from initState() body because
      // ref.invalidate() accesses inherited widgets which is not allowed
      // before initState() completes. Future.microtask runs right after
      // initState but before the first build, so stale data is still cleared.
      ref.invalidate(chatPageNotifierProvider(_providerParams));
      _initializeChat();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_clearNotifications());
      _loadBlockedStatus();
      unawaited(_loadFollowUps());

      // Auto-focus text field for story reply
      if (widget.autoFocusInput == true) {
        _autoFocusTextFieldForStoryReply();
      }

      // Auto-focus text field for Express Hub reply
      if (_isReplyingToExpressHub) {
        _autoFocusTextFieldForStoryReply();
      }

      ref.listenManual(messageStatusStreamProvider, (previous, next) {
        next.whenData((event) {
          ref
              .read(chatPageNotifierProvider(_providerParams).notifier)
              .updateMessageStatus(event.messageId, event.status);
        });
      });

      ref.listenManual(specificUserStatusProvider(widget.receiverId), (
        previous,
        next,
      ) {
        next.whenData((status) {
          if (status != null) {
            ref.read(userStatusProvider.notifier).updateStatus(status);
          }
        });
      });

      // WHATSAPP-STYLE: Listen for profile updates (photo/name changes)
      _profileUpdateSub = ChatEngineService.instance.profileUpdateStream.listen((
        update,
      ) async {
        // Only refresh if the update is for this chat's contact
        if (update.userId == widget.receiverId && mounted) {
          debugPrint('👤 [IndividualChat] Profile update for ${update.userId}');
          if (!mounted) return;
          // Wait for notifier to reload from database
          await ref
              .read(contactsManagementNotifierProvider.notifier)
              .loadFromCache();
          // Invalidate contacts provider to refresh profile pic/name in AppBar
          if (mounted) {
            ref.invalidate(contactsListProvider);
          }
        }
      });
    });
  }

  void _scrollControllerAddListener() {
    _scrollController.addListener(_onScroll);
  }

  void _showDeleteSelectionDialog(
    ResponsiveSize responsive,
    ChatPageNotifier chatNotifier,
    int selectionCount,
    Set<String> selectedMessageIds,
    List<ChatMessageModel> selectedMessages,
  ) {
    final isOnline = _unifiedChatService.isOnline;
    final isSocketConnected = _unifiedChatService.isConnectedToServer;
    if (!isOnline || !isSocketConnected) {
      if (mounted) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Check your connection",
        );
      }
      return;
    }

    final nonDeletedMessages = selectedMessages
        .where((m) => m.messageType != MessageType.deleted)
        .toList();
    final nonDeletedIds = nonDeletedMessages.map((m) => m.id).toSet();
    if (nonDeletedIds.isEmpty) {
      chatNotifier.clearSelection();
      unawaited(AppSnackbar.show(context, 'Message already deleted'));
      return;
    }

    unawaited(
      showDeleteSelectionDialog(
        context: context,
        responsive: responsive,
        chatNotifier: chatNotifier,
        selectionCount: nonDeletedIds.length,
        selectedMessageIds: nonDeletedIds,
        selectedMessages: nonDeletedMessages,
      ),
    );
  }

  void _enterEditMode(ChatMessageModel message) {
    setState(() {
      _editingMessage = message;
      _isSavingEdit = false;
    });
    _textController.text = message.message;
    _messageFocusNode.requestFocus();
  }

  void _cancelEditMode() {
    if (_isSavingEdit) return;
    setState(() {
      _editingMessage = null;
      _isSavingEdit = false;
    });
    _textController.clear();
    _messageFocusNode.unfocus();
  }

  Future<void> _saveEditedMessage() async {
    final target = _editingMessage;
    if (target == null) return;

    final newText = _textController.text.trim();
    if (newText.isEmpty) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Message cannot be empty',
          bottomPosition: _snackbarBottomPosition(),
        );
      }
      return;
    }

    if (newText == target.message.trim()) {
      _cancelEditMode();
      return;
    }

    final isOnline = _unifiedChatService.isOnline;
    final isSocketConnected = _unifiedChatService.isConnectedToServer;
    if (!isOnline || !isSocketConnected) {
      if (mounted) {
        AppSnackbar.showOfflineWarning(
          context,
          "You're offline. Check your connection",
        );
      }
      return;
    }

    setState(() => _isSavingEdit = true);

    final ok = await _unifiedChatService.editMessage(
      chatId: target.id,
      newMessage: newText,
    );

    if (ok) {
      try {
        final notifier = ref.read(
          chatPageNotifierProvider(_providerParams).notifier,
        );
        final now = DateTime.now();
        final updated = target.copyWith(
          message: newText,
          isEdited: true,
          editedAt: now,
          updatedAt: now,
        );
        notifier.replaceLocalMessageWithServer(updated);
      } catch (e) {
        debugPrint('Edit local replace failed: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _isSavingEdit = false;
      _editingMessage = null;
    });
    _textController.clear();
    _messageFocusNode.unfocus();
  }

  void _onScroll() {
    // Only show JumpToLatestButton when scrolled past ~100 messages worth of content
    // Average message height ~60px, so 100 messages ≈ 6000px offset
    final shouldShow =
        _scrollController.hasClients && _scrollController.offset > 6000;
    if (_showJumpToLatest != shouldShow) {
      setState(() => _showJumpToLatest = shouldShow);
    }

    final overlayId = _overlayMessageId;
    if (overlayId != null) {
      _updateOverlayPlacement(overlayId);
    }

    // Pagination handled by ChatEngineService automatically
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clearNotifications();
      // ChatEngineService handles refresh automatically
      // safe scroll after resume
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _safeScrollToBottom(),
      );
    }
  }

  Future<void> _clearNotifications() async {
    try {
      await NotificationLocalService.clearChatNotifications(widget.receiverId);
    } catch (e) {
      debugPrint('Clear notifications failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    try {
      // Don't clear callbacks - socket is global and shared across all chats
      // Only leave the conversation to update active conversation state
      _unifiedChatService.leaveConversation(widget.receiverId);
    } catch (e) {
      debugPrint('Socket cleanup error: $e');
    }

    _scrollController.dispose();
    _textController.dispose();
    _messageFocusNode.dispose();
    _profileUpdateSub?.cancel();
    _audioRecorder.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch only messages & loading to reduce rebuilds
    final messages = ref.watch(
      chatPageNotifierProvider(_providerParams).select((s) => s.messages),
    );
    final isLoading = ref.watch(
      chatPageNotifierProvider(_providerParams).select((s) => s.loading),
    );
    final chatNotifier = ref.read(
      chatPageNotifierProvider(_providerParams).notifier,
    );
    final selectedMessageIds = ref.watch(
      chatPageNotifierProvider(
        _providerParams,
      ).select((s) => s.selectedMessageIds),
    );

    final overlayMessageId = selectedMessageIds.length == 1
        ? selectedMessageIds.first
        : null;
    if (overlayMessageId != null && overlayMessageId != _overlayMessageId) {
      _overlayMessageId = overlayMessageId;
      _updateOverlayPlacement(overlayMessageId);
    }
    if (overlayMessageId == null && _overlayMessageId != null) {
      _overlayMessageId = null;
    }

    // show snackbar for errors (watching messages/loading avoids excessive rebuild)
    final error = ref.watch(
      chatPageNotifierProvider(_providerParams).select((s) => s.error),
    );
    if (error != null && error != _lastShownError) {
      _lastShownError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Error handling - silently clear error (clock icon shows offline state)
          chatNotifier.clearError();
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _lastShownError = null;
          });
        }
      });
    }

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (chatNotifier.hasSelection) {
              chatNotifier.clearSelection();
              return;
            }

            final handledByInput =
                _chatInputKey.currentState?.handleBackPress() ?? false;
            if (handledByInput) return;

            await _handleLeaveChat();
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: _buildChatUI(
            responsive,
            messages,
            isLoading,
            selectedMessageIds,
          ),
        );
      },
    );
  }

  ScrollController _scrollControllerSafe() => _scrollController;

  void _updateOverlayPlacement(String messageId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _messageBubbleKeys[messageId];
      final ctx = key?.currentContext;
      if (ctx == null) return;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.attached) return;

      final topLeft = ro.localToGlobal(Offset.zero);
      final bubbleSize = ro.size;
      final width = context.screenWidth;
      final responsive = ResponsiveSize(
        context: context,
        constraints: BoxConstraints(maxWidth: width),
        breakpoint: DeviceBreakpoint.fromWidth(width),
      );
      final topLimit = MediaQuery.of(context).padding.top + kToolbarHeight;
      final screenWidth = MediaQuery.of(context).size.width;
      final bubbleCenterGlobal = topLeft.dx + (bubbleSize.width / 2);
      
      // Estimate overlay width (roughly 6 emojis + plus button + padding)
      final overlayWidth = responsive.size(320); 
      final halfOverlayWidth = overlayWidth / 2;
      final horizontalMargin = responsive.spacing(16);
      
      double dx = 0.0;
      
      // If the overlay would overflow the left edge
      if (bubbleCenterGlobal - halfOverlayWidth < horizontalMargin) {
        dx = horizontalMargin - (bubbleCenterGlobal - halfOverlayWidth);
      } 
      // If the overlay would overflow the right edge
      else if (bubbleCenterGlobal + halfOverlayWidth > screenWidth - horizontalMargin) {
        dx = (screenWidth - horizontalMargin) - (bubbleCenterGlobal + halfOverlayWidth);
      }

      // Vertical placement
      final overlayHeight = responsive.size(160); // Account for pill + action list
      final showBelow = (topLeft.dy - overlayHeight) < topLimit;

      if (!mounted) return;
      if (_overlayShowBelow != showBelow || (_overlayDx - dx).abs() > 0.1) {
        setState(() {
          _overlayShowBelow = showBelow;
          _overlayDx = dx;
        });
      }
    });
  }


  Widget _buildAnchoredWhatsAppReactionOverlay({
    required String messageId,
    required ChatMessageModel message,
    required Set<String> selectedMessageIds,
    required ChatPageNotifier chatNotifier,
    required ResponsiveSize responsive,
  }) {
    final userReactions =
        message.reactions.where((r) => r.userId == _currentUserId).toList();
    final currentReaction =
        userReactions.isNotEmpty ? userReactions.first.emoji : null;

    return CompositedTransformFollower(
      link: _messageLayerLinks[messageId]!,
      showWhenUnlinked: false,
      offset: Offset(
        _overlayDx,
        _overlayShowBelow ? responsive.spacing(8) : -responsive.spacing(24),
      ),
      targetAnchor: _overlayShowBelow ? Alignment.bottomCenter : Alignment.topCenter,
      followerAnchor: _overlayShowBelow ? Alignment.topCenter : Alignment.bottomCenter,
      child: WhatsAppReactionOverlay(
        message: message,
        selectedEmoji: currentReaction,
        onReactionSelected: (emoji) {
          if (currentReaction == emoji) {
            // Toggle removal if same emoji tapped
            chatNotifier.removeReactionFromMessage(messageId);
          } else {
            chatNotifier.addReactionToMessage(messageId, emoji);
          }
          chatNotifier.clearSelection();
        },
        onPlusTap: () async {
          chatNotifier.clearSelection();
          _showFullEmojiPicker(messageId);
        },
        onActionSelected: (action) {
          switch (action) {
            case MessageActionType.reply:
              _handleSwipeToReply(message);
              chatNotifier.clearSelection();
              break;
            case MessageActionType.copy:
              Clipboard.setData(ClipboardData(text: message.message));
              AppSnackbar.show(context, 'Message copied to clipboard');
              chatNotifier.clearSelection();
              break;
            case MessageActionType.select:
              // Already selected, just clear overlay to stay in selection mode
              setState(() {
                // This triggers a rebuild which will hide the overlay 
                // because we'll ensure the overlay logic handles "manual select"
              });
              break;
            case MessageActionType.forward:
              _handleForwardSelection([message]);
              break;
            case MessageActionType.delete:
              _handleDeleteMessages();
              break;
            case MessageActionType.edit:
              _handleEditMessage(message);
              break;
          }
        },
      ),
    );
  }

  Future<void> _handleReactionSelected(String messageId, String emoji) async {
    final userIdAsync = ref.read(currentUserIdFutureProvider);
    final userId = await userIdAsync.maybeWhen(
      data: (id) async => id,
      orElse: () async => await ref.read(currentUserIdFutureProvider.future),
    );

    if (userId.isEmpty) return;

    final reactionNotifier = ref.read(messageReactionProvider);
    await reactionNotifier.addReaction(
      messageId: messageId,
      emoji: emoji,
    );

    if (!mounted) return;
    
    // Update local UI state for immediate feedback
    setState(() {
      final current = _uiMessageReactions[messageId];
      if (current == emoji) {
        _uiMessageReactions.remove(messageId);
      } else {
        _uiMessageReactions[messageId] = emoji;
      }
    });
    
    ref.read(chatPageNotifierProvider(_providerParams).notifier).clearSelection();
  }

  void _showFullEmojiPicker(String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            Navigator.pop(context);
            _handleReactionSelected(messageId, emoji.emoji);
          },
          config: Config(
            height: 256,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              columns: 7,
              emojiSizeMax: 32 * (Platform.isIOS ? 1.30 : 1.0),
            ),
            categoryViewConfig: const CategoryViewConfig(
              backgroundColor: Colors.transparent,
              indicatorColor: AppColors.primary,
              iconColorSelected: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  void _handleForwardSelection(List<ChatMessageModel> messages) {
    if (messages.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ForwardMessagePage(
          messages: messages,
        ),
      ),
    );
    ref.read(chatPageNotifierProvider(_providerParams).notifier).clearSelection();
  }

  Widget _buildChatUI(
    ResponsiveSize responsive,
    List<ChatMessageModel> messages,
    bool loading,
    Set<String> selectedMessageIds,
  ) {
    final notifier = ref.read(
      chatPageNotifierProvider(_providerParams).notifier,
    );
    final hasSelection = selectedMessageIds.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset:
          false, // important: we handle keyboard inset manually
      appBar: ChatAppBarWidget(
        receiverId: widget.receiverId,
        contactName: _contactName,
        isEditing: _editingMessage != null,
        selectionCount: selectedMessageIds.length,
        onClearSelection: () => notifier.clearSelection(),
        onDeleteSelected: () {
          final selectedSet =
              ref.read(chatPageNotifierProvider(_providerParams)).selectedMessageIds;
          final messages =
              ref.read(chatPageNotifierProvider(_providerParams)).messages;
          final selectedMessages =
              messages.where((m) => selectedSet.contains(m.id)).toList();
          _showDeleteSelectionDialog(
            responsive,
            notifier,
            selectedSet.length,
            selectedSet,
            selectedMessages,
          );
        },
        onForwardSelected: () {
          final selectedSet =
              ref.read(chatPageNotifierProvider(_providerParams)).selectedMessageIds;
          final messages =
              ref.read(chatPageNotifierProvider(_providerParams)).messages;
          final selectedMessages =
              messages.where((m) => selectedSet.contains(m.id)).toList();
          _handleForwardSelection(selectedMessages);
        },
        onEditSelected: () {
          final selectedSet =
              ref.read(chatPageNotifierProvider(_providerParams)).selectedMessageIds;
          if (selectedSet.length == 1) {
            final messages =
                ref.read(chatPageNotifierProvider(_providerParams)).messages;
            final msg = messages.firstWhere((m) => m.id == selectedSet.first);
            _enterEditMode(msg);
            notifier.clearSelection();
          }
        },
        onBackPressed: () {
          if (mounted) Navigator.of(context).pop();
        },
        onLeaveChat: _handleLeaveChat,
        onNavigateBack: _loadBlockedStatus,
        onFollowUpSelected: _handleFollowUpSelected,
        onVoiceCall: () async {
          if (_isInitiatingCall) return;
          debugPrint('📞 [onVoiceCall] callback triggered in OneToOneChatPage');
          _messageFocusNode.unfocus();
          await Future.delayed(const Duration(milliseconds: 150));
          _handleCall(CallType.voice);
        },
        onVideoCall: () async {
          if (_isInitiatingCall) return;
          debugPrint('📹 [onVideoCall] callback triggered in OneToOneChatPage');
          _messageFocusNode.unfocus();
          await Future.delayed(const Duration(milliseconds: 150));
          _handleCall(CallType.video);
        },
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Stack(
          key: _chatBodyKey,
          clipBehavior: Clip.none,
          children: [
            // Chat background (extracted widget)
            const Positioned.fill(child: ChatBackgroundWidget()),
            // Chat content
            Column(
              children: [
                // Banner for unknown contacts
                ContactNotFoundBanner(receiverId: widget.receiverId),
                Expanded(
                  child: ChatMessageList(
                    messages: messages,
                    responsive: responsive,
                    scrollController: _scrollControllerSafe(),
                    selectedMessageIds: selectedMessageIds,
                    providerParams: _providerParams,
                    currentUserId: _currentUserId,
                    contactName: _contactName,
                    followUpEntries: _followUpEntries,
                    isLoadingFollowUps: _isLoadingFollowUps,
                    isBlocked: _isBlocked,
                    showJumpToLatest: _showJumpToLatest,
                    messageLayerLinks: _messageLayerLinks,
                    messageBubbleKeys: _messageBubbleKeys,
                    chatNotifier: notifier,
                    onJumpToLatest: () {
                      if (_scrollController.hasClients) {
                        _safeScrollToBottom(animated: false);
                      }
                      setState(() => _showJumpToLatest = false);
                    },
                    onMessageLongPress: (messageId) {
                      notifier.toggleMessageSelection(messageId);
                      _updateOverlayPlacement(messageId);
                    },
                    onRetryUpload: retryFailedUpload,
                    onReactionTap: _showReactionDetailsSheet,
                    onSwipeToReply: (message) {
                      debugPrint('↩️ Swipe to reply: ${message.id}');
                      setState(() => _replyToMessage = message);
                      _messageFocusNode.requestFocus();
                      // Scroll to bottom immediately for better UX
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _safeScrollToBottom(animated: true);
                      });
                    },
                    onTapReplyMessage: _scrollToMessage,
                    highlightedMessageId: _highlightedMessageId,
                  ),
                ),
                _isBlocked
                    ? BlockedContactPanel(
                        onExit: () async {
                          await _handleLeaveChat();
                          if (mounted) Navigator.of(context).pop();
                        },
                        onUnblock: _handleUnblockFromChat,
                        isUnblocking: _isUnblocking,
                      )
                    : _buildInputField(),
              ],
            ),
            // Attachment panel - rendered at page level to avoid Column clipping
            // WhatsApp-style: floats above keyboard + input field when keyboard is open
            if (_showAttachmentPanel)
              Positioned(
                left: 0,
                right: 0,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    responsive.size(80),
                child:
                    _chatInputKey.currentState
                        ?.buildExternalAttachmentPanel() ??
                    const SizedBox.shrink(),
              ),
            // Edit mode: no overlay, just input field shows edit state
            if (hasSelection && selectedMessageIds.length == 1)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: notifier.clearSelection,
                  child: const SizedBox.expand(),
                ),
              ),
            if (hasSelection && selectedMessageIds.length == 1)
              _buildAnchoredWhatsAppReactionOverlay(
                messageId: selectedMessageIds.first,
                message: messages.firstWhere((m) => m.id == selectedMessageIds.first),
                selectedMessageIds: selectedMessageIds,
                chatNotifier: notifier,
                responsive: responsive,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _safeScrollToBottom({bool animated = true}) async {
    try {
      if (!_scrollController.hasClients) return;
      final viewInsets = MediaQuery.of(context).viewInsets.bottom;
      if (viewInsets > 0) {
        // let keyboard animation settle
        await Future.delayed(const Duration(milliseconds: 260));
      } else {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(0.0);
        }
      }
    } catch (e) {
      debugPrint('safeScroll error: $e');
    }
  }

  /// Scroll to a specific message by its ID (for tap-on-reply-preview)
  void _scrollToMessage(String messageId) {
    final chatState = ref.read(chatPageNotifierProvider(_providerParams));
    final messages = chatState.messages;
    final msgIndex = messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) {
      debugPrint('⚠️ Reply target message $messageId not found in list');
      return;
    }

    debugPrint(
      '🔎 _scrollToMessage: $messageId at index $msgIndex/${messages.length}',
    );

    // Try to scroll using the bubble's GlobalKey context
    final bubbleKey = _messageBubbleKeys[messageId];
    if (bubbleKey != null && bubbleKey.currentContext != null) {
      _ensureVisibleAndHighlight(bubbleKey.currentContext!, messageId);
      return;
    }

    // Message not currently rendered — jump to estimated offset, then
    // retry ensureVisible up to 5 times as the ListView lays out new items.
    if (!_scrollController.hasClients) return;

    final reversedIndex = messages.length - 1 - msgIndex;
    final estimatedOffset = reversedIndex * 72.0;
    _scrollController.jumpTo(
      estimatedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
    );

    _retryEnsureVisible(messageId, attemptsLeft: 5);
  }

  /// Repeatedly check (post-frame) until the message key is rendered,
  /// then call [Scrollable.ensureVisible] and trigger highlight.
  void _retryEnsureVisible(String messageId, {required int attemptsLeft}) {
    if (attemptsLeft <= 0 || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _messageBubbleKeys[messageId];
      if (key != null && key.currentContext != null) {
        _ensureVisibleAndHighlight(key.currentContext!, messageId);
      } else {
        // Wait a short while for layout to settle and retry
        Future.delayed(const Duration(milliseconds: 80), () {
          _retryEnsureVisible(messageId, attemptsLeft: attemptsLeft - 1);
        });
      }
    });
  }

  /// Scroll so the widget is centered and apply a 2-second highlight.
  void _ensureVisibleAndHighlight(BuildContext ctx, String messageId) {
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _highlightedMessageId = messageId);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightedMessageId == messageId) {
        setState(() => _highlightedMessageId = null);
      }
    });
  }

  IconData _replyMediaIcon(MessageType type) {
    switch (type) {
      case MessageType.image:
        return Icons.photo;
      case MessageType.video:
        return Icons.videocam;
      case MessageType.audio:
        return Icons.graphic_eq_rounded;
      case MessageType.document:
        return Icons.picture_as_pdf;
      case MessageType.contact:
        return Icons.person;
      case MessageType.poll:
        return Icons.poll;
      case MessageType.location:
        return Icons.location_on;
      case MessageType.text:
      case MessageType.deleted:
        return Icons.chat_bubble_outline;
    }
  }

  String _replyPreviewText(ChatMessageModel msg) {
    switch (msg.messageType) {
      case MessageType.image:
        return 'Photo';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        final dur = msg.audioDuration;
        if (dur != null && dur > 0) {
          final mins = (dur ~/ 60).toString().padLeft(2, '0');
          final secs = (dur.toInt() % 60).toString().padLeft(2, '0');
          return 'Voice message  $mins:$secs';
        }
        return 'Voice message';
      case MessageType.document:
        final fileName = (msg.fileName ?? '').trim();
        return fileName.isNotEmpty ? fileName : 'PDF';
      case MessageType.contact:
        return 'Contact';
      case MessageType.poll:
        return 'Poll';
      case MessageType.location:
        return 'Location';
      case MessageType.deleted:
        return 'Deleted message';
      case MessageType.text:
        final text = _stripReplyTags(msg.message).trim();
        return text.isNotEmpty ? text : 'Message';
    }
  }

  /// Strip Express Hub and Follow-Up reply tags from raw message text
  /// so the swipe-to-reply preview shows clean user text only.
  String _stripReplyTags(String raw) {
    var text = raw;
    // Strip <<EH_REPLY>>..<<EH_REPLY_END>> block
    final ehStart = text.indexOf('<<EH_REPLY>>');
    final ehEnd = text.indexOf('<<EH_REPLY_END>>');
    if (ehStart != -1 && ehEnd != -1 && ehEnd > ehStart) {
      text =
          text.substring(0, ehStart) +
          text.substring(ehEnd + '<<EH_REPLY_END>>'.length);
    }
    // Strip <<FU_REPLY>>..<<FU_REPLY_END>> block
    final fuStart = text.indexOf('<<FU_REPLY>>');
    final fuEnd = text.indexOf('<<FU_REPLY_END>>');
    if (fuStart != -1 && fuEnd != -1 && fuEnd > fuStart) {
      text =
          text.substring(0, fuStart) +
          text.substring(fuEnd + '<<FU_REPLY_END>>'.length);
    }
    return text.trim();
  }

  Widget _buildInputField() {
    final chatNotifier = ref.read(
      chatPageNotifierProvider(_providerParams).notifier,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );

    return Column(
      children: [
        // Story reply section with light grey background
        if (_isReplyingToStory && _storyReplyText != null)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(16),
              vertical: responsive.spacing(4),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width * 0.86),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.spacing(12),
                    vertical: responsive.spacing(10),
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.shade800.withValues(alpha: 0.3)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(responsive.size(10)),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade600.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Chat stories icon
                      Image.asset(
                        ImageAssets.chatStoriesIcon,
                        width: responsive.size(16),
                        height: responsive.size(16),
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      SizedBox(width: responsive.spacing(8)),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: width * 0.64),
                        child: Text(
                          _storyReplyText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: responsive.size(14),
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      SizedBox(width: responsive.spacing(10)),
                      GestureDetector(
                        onTap: _clearStoryReply,
                        child: Icon(
                          Icons.close,
                          size: responsive.size(18),
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Follow-up reply section with light grey background
        if (_replyToFollowUpText != null && _replyToFollowUpDateTime != null)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(16),
              vertical: responsive.spacing(4),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width * 0.86),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.spacing(12),
                    vertical: responsive.spacing(10),
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.shade800.withValues(alpha: 0.3)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(responsive.size(10)),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade600.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Follow-up icon and text in column layout
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Follow-up icon
                          Padding(
                            padding: EdgeInsets.only(
                              top: responsive.spacing(2),
                            ),
                            child: Image.asset(
                              ImageAssets.followUpAttachmentIcon,
                              width: responsive.size(16),
                              height: responsive.size(16),
                              color: AppColors.iconPrimary,
                            ),
                          ),
                          SizedBox(width: responsive.spacing(8)),
                          // Follow-up text in flexible column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _replyToFollowUpText!,
                                  style: TextStyle(
                                    fontSize: responsive.size(14),
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: responsive.spacing(4)),
                                Text(
                                  _replyToFollowUpDateTime!,
                                  style: TextStyle(
                                    fontSize: responsive.size(12),
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Close button
                          GestureDetector(
                            onTap: _clearFollowUpReply,
                            child: Icon(
                              Icons.close,
                              size: responsive.size(18),
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Regular chat input field
        ChatInputField(
          key: _chatInputKey,
          textController: _textController,
          focusNode: _messageFocusNode,
          onSend: _handleSendMessage,
          onEditSave: _saveEditedMessage,
          onEditCancel: _cancelEditMode,
          onTextChanged: (value) {
            chatNotifier.sendTypingIndicator(value.trim().isNotEmpty);
            setState(() {});
          },
          isSending: _isSending,
          isSavingEdit: _isSavingEdit,
          isEditing: _editingMessage != null,
          editingLabel: 'Edit message',
          onCameraTap: handleCameraAttachment,
          onGalleryTap: handleGalleryAttachment,
          onDocumentTap: handleDocumentAttachment,
          onVideoTap: _handleVideoAttachmentReal,
          onContactTap: _handleContactShare,
          onLocationTap: _handleLocationShare,
          onFollowUpTap: _handleFollowUpAttachment,
          onPollTap: _handlePollAttachment,
          // TODO: Happy Update feature - temporarily hidden
          // onTwitterTap: _handleTwitterShare,
          onAttachmentPanelChanged: (isOpen) {
            setState(() => _showAttachmentPanel = isOpen);
          },
          onMicLongPressStart: _startAudioRecording,
          onRecordingStopped: _stopAudioRecording,
          onRecordingCancelled: _cancelAudioRecording,
          onAudioSendConfirmed: _handleAudioSendConfirmed,
          audioFilePath: _recordedAudioPath,
          replyName: _replyToMessage != null
              ? (_replyToMessage!.senderId == _currentUserId
                    ? 'You'
                    : _contactName)
              : (_isReplyingToExpressHub && _expressHubReplyText != null
                    ? 'Express Hub'
                    : null),
          replyText: _replyToMessage != null
              ? _replyPreviewText(_replyToMessage!)
              : (_isReplyingToExpressHub && _expressHubReplyText != null
                    ? _expressHubReplyText
                    : null),
          replyIcon:
              _replyToMessage != null &&
                  _replyToMessage!.messageType != MessageType.text
              ? _replyMediaIcon(_replyToMessage!.messageType)
              : null,
          replyAssetIcon:
              _isReplyingToExpressHub &&
                  _expressHubReplyText != null &&
                  _replyToMessage == null
              ? ImageAssets.replyMessageIcon
              : null,
          onCancelReply: _replyToMessage != null
              ? () => setState(() => _replyToMessage = null)
              : (_isReplyingToExpressHub ? _clearExpressHubReply : null),
        ),
      ],
    );
  }

  Future<void> _initializeChat() async {
    try {
      debugPrint('Initializing hybrid chat service for ${widget.receiverId}');
      debugPrint('🔌 [OneToOneChatPage] Socket state on chat init:');
      debugPrint('   • isInitialized: ${_unifiedChatService.isInitialized}');
      debugPrint(
        '   • isConnectedToServer: ${_unifiedChatService.isConnectedToServer}',
      );
      debugPrint('   • isOnline: ${_unifiedChatService.isOnline}');

      // Register callbacks FIRST so any immediate cache-hit refreshes can update UI.
      setupEventListeners();

      // CRITICAL: Activate conversation FIRST to suppress notifications immediately
      // This prevents notifications while user is actively viewing this chat
      // NOTE: activateConversation already loads messages from DB - no need for separate reload
      final loadedLocal = await _unifiedChatService.activateConversation(
        widget.receiverId,
      );

      if (!_unifiedChatService.isInitialized) {
        final initialized = await _unifiedChatServiceInitialize(_currentUserId);
        debugPrint(initialized ? 'Hybrid initialized' : 'Hybrid init failed');
      }

      if (loadedLocal.isNotEmpty && mounted) {
        ref
            .read(chatPageNotifierProvider(_providerParams).notifier)
            .refreshFromLocalMessages(loadedLocal);

        // Load reactions for all messages (batched — appears with messages)
        await loadReactionsForMessages(loadedLocal);
      }

      // Now mark messages as read (active chat is set)
      if (mounted) _markMessagesAsRead();

      // ChatEngineService handles server chat history sync automatically
    } catch (e) {
      debugPrint('Initialize chat error: $e');
    }
  }

  // Small wrapper in case hybrid initialize signature differs
  Future<bool> _unifiedChatServiceInitialize(String userId) async {
    try {
      return await _unifiedChatService.initialize(userId);
    } catch (e) {
      debugPrint('Hybrid initialize error: $e');
      return false;
    }
  }

  // Safe wrapper to handle possible null provider signatures
  dynamic chatPageNotifierProviderSafe(Map<String, String> params) =>
      chatPageNotifierProvider(params);

  Future<void> _handleLeaveChat() async {
    try {
      // Don't clear callbacks - socket is global and shared across all chats
      // Clearing callbacks would break real-time message delivery for other active chats
      _unifiedChatService.leaveConversation(widget.receiverId);
      AppStateService.instance.clearCurrentChat();
    } catch (e) {
      debugPrint('Leave chat error: $e');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  /// KEY FIX: single send path + send button disable to prevent duplicate sends.
  Future<void> _handleSendMessage() async {
    debugPrint('🔘 [OneToOneChatPage] Send button pressed');
    debugPrint('   • _isSending: $_isSending');
    debugPrint(
      '   • isConnectedToServer: ${_unifiedChatService.isConnectedToServer}',
    );
    debugPrint('   • isOnline: ${_unifiedChatService.isOnline}');

    if (_isSending) return;

    final messageText = _textController.text.trim();
    debugPrint(
      '   • messageText: "$messageText" (length=${messageText.length})',
    );
    if (messageText.isEmpty) return;

    final hasReplyContext =
        _replyToFollowUpText != null && _replyToFollowUpDateTime != null;
    final hasExpressHubReply =
        _isReplyingToExpressHub && _expressHubReplyText != null;

    // Check if this is a follow-up message (sender typed with prefix)
    final isFollowUp = messageText.startsWith(_followUpPrefix);

    // Strip the prefix for the text that goes to the receiver
    // Receiver sees clean text, sender sees follow-up styling via isFollowUp flag
    final cleanMessageText = isFollowUp
        ? messageText.substring(_followUpPrefix.length).trim()
        : messageText;

    // Build outgoing text for server (clean text, no prefix)
    String outgoingText;
    if (hasExpressHubReply) {
      final replyType = _expressHubReplyType ?? 'voice';
      outgoingText =
          '<<EH_REPLY>>\n$replyType\n$_expressHubReplyText\n<<EH_REPLY_END>>\n$cleanMessageText';
    } else if (hasReplyContext) {
      outgoingText =
          '<<FU_REPLY>>\n$_replyToFollowUpText\n$_replyToFollowUpDateTime\n<<FU_REPLY_END>>\n$cleanMessageText';
    } else {
      outgoingText = cleanMessageText;
    }

    // For sender's local display, keep the original text with prefix so UI can show it
    String senderDisplayText;
    if (hasExpressHubReply) {
      final replyType = _expressHubReplyType ?? 'voice';
      senderDisplayText =
          '<<EH_REPLY>>\n$replyType\n$_expressHubReplyText\n<<EH_REPLY_END>>\n$messageText';
    } else if (hasReplyContext) {
      senderDisplayText =
          '<<FU_REPLY>>\n$_replyToFollowUpText\n$_replyToFollowUpDateTime\n<<FU_REPLY_END>>\n$messageText';
    } else {
      senderDisplayText = messageText;
    }

    setState(() => _isSending = true);

    try {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      // Capture reply-to message ID before clearing
      final replyToId = _replyToMessage?.id;
      final replyToMsg = _replyToMessage;

      // Sender's local message keeps the prefix for display, plus isFollowUp flag
      final tempMessage = ChatMessageModel(
        id: tempId,
        senderId: _currentUserId,
        receiverId: widget.receiverId,
        message: senderDisplayText,
        messageType: MessageType.text,
        createdAt: now,
        updatedAt: now,
        messageStatus: 'sending',
        isRead: false,
        isFollowUp: isFollowUp,
        replyToMessageId: replyToId,
        replyToMessage: replyToMsg,
      );

      ref
          .read(chatPageNotifierProvider(_providerParams).notifier)
          .addIncomingMessage(tempMessage);

      // Scroll to latest after adding the new message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _safeScrollToBottom(animated: false);
      });

      if (isFollowUp) {
        final createdAt = DateTime.now();
        try {
          final storedFollowUpText = messageText
              .substring(_followUpPrefix.length)
              .trim();
          await FollowUpsTable.instance.insertFollowUp(
            currentUserId: widget.currentUserId,
            contactId: widget.receiverId,
            text: storedFollowUpText,
            createdAt: createdAt,
          );
          if (mounted) {
            setState(() {
              _followUpEntries.insert(
                0,
                FollowUpEntry(text: storedFollowUpText, createdAt: createdAt),
              );
            });
          }
        } catch (_) {}
      }

      // Send to server with isFollowUp flag and replyToMessageId
      final serverMessage = await _unifiedChatService.sendMessage(
        receiverId: widget.receiverId,
        messageText: outgoingText,
        messageType: 'text',
        isFollowUp: isFollowUp,
        replyToMessageId: replyToId,
        replyToMessage: replyToMsg,
      );

      if (serverMessage != null) {
        // Replace optimistic message with server response
        ref
            .read(chatPageNotifierProvider(_providerParams).notifier)
            .replaceLocalMessageWithServer(
              serverMessage,
              localMessageId: tempId,
            );
      } else {
        // Mark as failed
        ref
            .read(chatPageNotifierProvider(_providerParams).notifier)
            .updateMessageStatus(tempId, 'failed');
      }

      // Clear input and reply context
      _textController.clear();
      _clearFollowUpReply();
      _clearExpressHubReply();
      if (_replyToMessage != null) {
        setState(() => _replyToMessage = null);
      }
      // Keep keyboard open for better UX - user can continue typing
    } catch (e) {
      debugPrint('Send message error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _markMessagesAsRead() async {
    try {
      await _unifiedChatService.markChatMessagesAsRead();
    } catch (e) {
      debugPrint('Mark read error: $e');
    }
  }

  Future<void> _loadBlockedStatus() async {
    try {
      final repo = ref.read(blockedContactsRepositoryProvider);
      final blockedIds = await repo.getBlockedUserIdsLocal(_currentUserId);
      if (!mounted) return;
      setState(() {
        _isBlocked = blockedIds.contains(widget.receiverId);
      });
    } catch (e) {
      debugPrint('Blocked status check failed: $e');
    }
  }

  Future<void> _handleUnblockFromChat() async {
    if (_isUnblocking) return;

    setState(() {
      _isUnblocking = true;
    });

    try {
      if (mounted) {
        AppSnackbar.showCustom(
          context,
          'Unblocking...',
          bottomPosition: _snackbarBottomPosition(),
          duration: const Duration(seconds: 1),
        );
      }

      bool ok = false;
      late final String serverMessage;
      try {
        final result = await ref
            .read(blockedContactsNotifierProvider.notifier)
            .unblockUser(widget.receiverId);
        ok = result.isSuccess;
        serverMessage = result.message;
      } on SocketException {
        if (mounted) {
          AppSnackbar.showOfflineWarning(
            context,
            "You're offline. Check your connection",
          );
        }
        return;
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(
            context,
            'Failed to unblock user. Please try again.',
            bottomPosition: _snackbarBottomPosition(),
          );
        }
        return;
      }

      if (!mounted) return;

      if (ok) {
        setState(() {
          _isBlocked = false;
        });
        AppSnackbar.showSuccess(
          context,
          serverMessage.isNotEmpty ? serverMessage : 'Contact unblocked',
          bottomPosition: _snackbarBottomPosition(),
          duration: const Duration(seconds: 2),
        );
      } else {
        AppSnackbar.showError(
          context,
          serverMessage.isNotEmpty
              ? serverMessage
              : 'Failed to unblock user. Please try again.',
          bottomPosition: _snackbarBottomPosition(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUnblocking = false;
        });
      }
    }
  }

  void _handleSwipeToReply(ChatMessageModel message) {
    if (message.messageType == MessageType.deleted) return;
    setState(() {
      _replyToMessage = message;
      _isReplyingToStory = false;
    });
  }

  void _handleEditMessage(ChatMessageModel message) {
    if (message.senderId != _currentUserId) {
      AppSnackbar.show(context, 'You can only edit your own messages');
      return;
    }
    if (message.messageType != MessageType.text) {
      AppSnackbar.show(context, 'Only text messages can be edited');
      return;
    }
    
    // Clear selection before entering edit mode
    ref.read(chatPageNotifierProvider(_providerParams).notifier).clearSelection();
    
    setState(() {
      _editingMessage = message;
      _textController.text = message.message;
      _messageFocusNode.requestFocus();
    });
  }

  Future<void> _handleDeleteMessages() async {
    final state = ref.read(chatPageNotifierProvider(_providerParams));
    final selectedIds = state.selectedMessageIds;
    if (selectedIds.isEmpty) return;

    final allMessages = state.messages;
    final selectedMessages = allMessages.where((m) => selectedIds.contains(m.id)).toList();

    final width = MediaQuery.of(context).size.width;
    final responsive = ResponsiveSize(
      context: context,
      constraints: BoxConstraints(maxWidth: width),
      breakpoint: DeviceBreakpoint.fromWidth(width),
    );

    await showDeleteSelectionDialog(
      context: context,
      responsive: responsive,
      chatNotifier: ref.read(chatPageNotifierProvider(_providerParams).notifier),
      selectionCount: selectedIds.length,
      selectedMessageIds: selectedIds,
      selectedMessages: selectedMessages,
    );
  }

  void _showReactionDetailsSheet(String messageId) {
    // Show reaction details in a modal bottom sheet
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageReactionDetailsSheet(
        messageId: messageId,
        currentUserId: _currentUserId,
      ),
    );
  }
}
