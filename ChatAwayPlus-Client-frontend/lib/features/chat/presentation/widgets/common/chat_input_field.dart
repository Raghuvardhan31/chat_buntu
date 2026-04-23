import 'package:flutter/material.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/common/chat_input/attachment_panel_widget.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/common/chat_input/emoji_picker_section.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/common/chat_input/edit_mode_banner.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/common/chat_input/input_pill_widget.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/common/chat_input/send_button_widget.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/common/chat_input/audio_record_overlay_widget.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/common/chat_input/audio_confirmation_widget.dart';
import 'package:chataway_plus/core/snackbar/app_snackbar.dart';

/// WhatsApp-style chat input field with inline attachment panel.
/// Shows follow up, camera, gallery, PDF, video, poll, contacts (and event when wired).
class ChatInputField extends StatefulWidget {
  const ChatInputField({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.onSend,
    required this.onEditSave,
    required this.onEditCancel,
    required this.onTextChanged,
    required this.isSending,
    required this.isSavingEdit,
    required this.isEditing,
    required this.editingLabel,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onDocumentTap,
    this.onVideoTap,
    this.onContactTap,
    this.onEventTap,
    this.onFollowUpTap,
    this.onPollTap,
    this.onTwitterTap,
    this.onLocationTap,
    this.onAttachmentPanelChanged,
    this.onMicTap,
    this.onMicLongPressStart,
    this.onMicLongPressEnd,
    this.onAudioSendConfirmed,
    this.onRecordingStopped,
    this.onRecordingCancelled,
    this.audioFilePath,
    this.replyName,
    this.replyText,
    this.replyIcon,
    this.replyAssetIcon,
    this.onCancelReply,
  });

  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onEditSave;
  final VoidCallback onEditCancel;
  final ValueChanged<String> onTextChanged;
  final bool isSending;
  final bool isSavingEdit;
  final bool isEditing;
  final String? editingLabel;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback? onVideoTap;
  final VoidCallback onDocumentTap;
  final VoidCallback? onContactTap;
  final VoidCallback? onEventTap;
  final VoidCallback? onFollowUpTap;
  final VoidCallback? onPollTap;
  final VoidCallback? onTwitterTap;
  final VoidCallback? onLocationTap;
  final ValueChanged<bool>? onAttachmentPanelChanged;
  final VoidCallback? onMicTap;
  final VoidCallback? onMicLongPressStart;
  final VoidCallback? onMicLongPressEnd;
  final VoidCallback? onAudioSendConfirmed;
  final ValueChanged<int>? onRecordingStopped;
  final VoidCallback? onRecordingCancelled;
  final String? audioFilePath;
  final String? replyName;
  final String? replyText;
  final IconData? replyIcon;
  final String? replyAssetIcon;
  final VoidCallback? onCancelReply;

  @override
  State<ChatInputField> createState() => ChatInputFieldState();
}

class ChatInputFieldState extends State<ChatInputField> {
  static const bool _verboseLogs = false;

  bool _showAttachmentPanel = false;
  bool _showEmojiPicker = false;
  double? _lastKeyboardHeight;
  double? _emojiPickerHeightOverride;
  bool _openEmojiAfterKeyboardClose = false;
  double? _transitionBottomPaddingOverride;
  bool _showCamera = true;
  bool _isRecording = false;
  bool _showAudioConfirmation = false;
  int _recordedDurationSeconds = 0;
  bool _slideCancelled = false;

  final GlobalKey _inputPillKey = GlobalKey();
  final GlobalKey _sendButtonKey = GlobalKey();
  final GlobalKey<AudioRecordOverlayWidgetState> _recordOverlayKey =
      GlobalKey<AudioRecordOverlayWidgetState>();

  /// Expose whether attachment panel is showing for external rendering
  bool get showAttachmentPanel => _showAttachmentPanel;

  /// Expose whether audio confirmation is showing for external rendering
  bool get showAudioConfirmation => _showAudioConfirmation;

  /// Build attachment panel for external rendering (at page level to avoid clipping)
  Widget buildExternalAttachmentPanel() {
    if (!_showAttachmentPanel) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );
        return _buildAttachmentPanel(responsive, isDark);
      },
    );
  }

  bool handleBackPress() {
    if (widget.isEditing) {
      widget.onEditCancel();
      return true;
    }
    if (_showAudioConfirmation) {
      setState(() => _showAudioConfirmation = false);
      return true;
    }
    if (_isRecording) {
      setState(() => _isRecording = false);
      return true;
    }
    if (_showEmojiPicker ||
        _showAttachmentPanel ||
        _openEmojiAfterKeyboardClose) {
      setState(() {
        _showEmojiPicker = false;
        _emojiPickerHeightOverride = null;
        _openEmojiAfterKeyboardClose = false;
        _transitionBottomPaddingOverride = null;
        _showAttachmentPanel = false;
      });
      return true;
    }
    if (widget.focusNode.hasFocus) {
      widget.focusNode.unfocus();
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _showCamera = widget.textController.text.trim().isEmpty;
    widget.textController.addListener(_onTextControllerChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.textController.removeListener(_onTextControllerChanged);
    super.dispose();
  }

  void _onTextControllerChanged() {
    final nextShowCamera = widget.textController.text.trim().isEmpty;
    if (nextShowCamera != _showCamera) {
      setState(() => _showCamera = nextShowCamera);
    }
  }

  void _onFocusChange() {
    // Don't auto-close attachment panel when keyboard opens/focus changes.
    // WhatsApp keeps the attachment panel visible above the keyboard.
    if (widget.focusNode.hasFocus && _showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
        _emojiPickerHeightOverride = null;
      });
    }
  }

  void _toggleAttachmentPanel() {
    if (_verboseLogs && kDebugMode) {
      debugPrint(
        '🔄 Toggle attachment panel - current state: $_showAttachmentPanel',
      );
    }
    if (_showAttachmentPanel) {
      setState(() => _showAttachmentPanel = false);
      widget.onAttachmentPanelChanged?.call(false);
    } else {
      // WhatsApp-style: Don't dismiss keyboard when opening attachment panel.
      // The panel floats above the keyboard / input area.
      setState(() {
        _showEmojiPicker = false;
        _showAttachmentPanel = true;
        _openEmojiAfterKeyboardClose = false;
        _transitionBottomPaddingOverride = null;
      });
      widget.onAttachmentPanelChanged?.call(true);
    }
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      final closeHeight =
          _emojiPickerHeightOverride ??
          _lastKeyboardHeight ??
          (context.screenHeight * 0.38);
      setState(() {
        _showEmojiPicker = false;
        _emojiPickerHeightOverride = null;
        _openEmojiAfterKeyboardClose = false;
        _transitionBottomPaddingOverride = closeHeight;
      });
      FocusScope.of(context).requestFocus(widget.focusNode);
    } else {
      final currentInset = MediaQuery.of(context).viewInsets.bottom;
      setState(() {
        _showAttachmentPanel = false;
        final fallback = _lastKeyboardHeight ?? 0;
        final candidate = currentInset > 0 ? currentInset : fallback;
        final defaultHeight = context.screenHeight * 0.38;
        final nextHeight = candidate > 0 ? candidate : defaultHeight;
        _emojiPickerHeightOverride = nextHeight;
        _transitionBottomPaddingOverride = null;

        if (currentInset > 0 || widget.focusNode.hasFocus) {
          _showEmojiPicker = false;
          _openEmojiAfterKeyboardClose = true;
        } else {
          _showEmojiPicker = true;
          _openEmojiAfterKeyboardClose = false;
        }
      });
      widget.focusNode.unfocus();
    }
  }

  void _insertEmoji(String emoji) {
    final text = widget.textController.text;
    final selection = widget.textController.selection;

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    final newText = text.replaceRange(start, end, emoji);
    widget.textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );

    widget.onTextChanged(newText);
    setState(() {});
  }

  void _handleAttachmentTap(VoidCallback callback) {
    if (_verboseLogs && kDebugMode) {
      debugPrint('🔘 Attachment option tapped, closing panel');
    }
    setState(() => _showAttachmentPanel = false);
    widget.onAttachmentPanelChanged?.call(false);
    callback();
  }

  Rect? _globalRectForKey(GlobalKey key) {
    final ctx = key.currentContext;
    final ro = ctx?.findRenderObject();
    if (ro is! RenderBox || !ro.attached) return null;
    final topLeft = ro.localToGlobal(Offset.zero);
    return topLeft & ro.size;
  }

  Rect? getInputPillGlobalRect() => _globalRectForKey(_inputPillKey);

  Rect? getSendButtonGlobalRect() => _globalRectForKey(_sendButtonKey);

  /// Builds the attachment options list - easy to add more options here
  List<AttachmentOptionData> _getAttachmentOptions() {
    return [
      AttachmentOptionData(
        assetPath: ImageAssets.followUpAttachmentIcon,
        iconSize: 20,
        label: 'Follow up',
        color: const Color(0xFF00BCD4),
        onTap: () => _handleAttachmentTap(widget.onFollowUpTap ?? () {}),
      ),
      AttachmentOptionData(
        icon: Icons.camera_alt,
        label: 'Camera',
        color: const Color(0xFFE91E63),
        onTap: () => _handleAttachmentTap(widget.onCameraTap),
      ),
      AttachmentOptionData(
        icon: Icons.photo,
        label: 'Gallery',
        color: const Color(0xFF9C27B0),
        onTap: () => _handleAttachmentTap(widget.onGalleryTap),
      ),
      AttachmentOptionData(
        icon: Icons.picture_as_pdf,
        label: 'PDF',
        color: const Color(0xFFFF5722),
        onTap: () => _handleAttachmentTap(widget.onDocumentTap),
      ),
      // TODO: Poll Hub feature - temporarily hidden
      // AttachmentOptionData(
      //   icon: Icons.add_chart_sharp,
      //   label: 'Poll',
      //   color: const Color(0xFF00BCD4),
      //   onTap: () => _handleAttachmentTap(widget.onPollTap ?? () {}),
      // ),
      AttachmentOptionData(
        assetPath: ImageAssets.contactsSharingIcon,
        label: 'Contacts',
        color: const Color(0xFF4CAF50),
        onTap: () => _handleAttachmentTap(widget.onContactTap ?? () {}),
      ),
      AttachmentOptionData(
        icon: Icons.location_on,
        label: 'Location',
        color: const Color(0xFF22C55E),
        onTap: () => _handleAttachmentTap(widget.onLocationTap ?? () {}),
      ),
      // TODO: Happy Update feature - temporarily hidden
      // AttachmentOptionData(
      //   assetPath: ImageAssets.goodNewsTwitterIcon,
      //   label: 'Happy Update',
      //   color: const Color(0xFF1DA1F2),
      //   onTap: () => _handleAttachmentTap(widget.onTwitterTap ?? () {}),
      // ),
      if (widget.onEventTap != null)
        AttachmentOptionData(
          icon: Icons.event,
          label: 'Event',
          color: const Color(0xFF009688),
          onTap: () => _handleAttachmentTap(widget.onEventTap!),
        ),
    ];
  }

  Widget _buildAttachmentPanel(ResponsiveSize responsive, bool isDark) {
    return AttachmentPanelWidget(
      attachmentOptions: _getAttachmentOptions(),
      responsive: responsive,
      isDark: isDark,
      verboseLogs: _verboseLogs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        widget.textController.text.trim().isNotEmpty &&
        !widget.isSending &&
        !(widget.isEditing && widget.isSavingEdit);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    if (_openEmojiAfterKeyboardClose &&
        viewInsets == 0 &&
        !widget.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_openEmojiAfterKeyboardClose) {
          setState(() {
            _showEmojiPicker = true;
            _openEmojiAfterKeyboardClose = false;
          });
        }
      });
    }

    if (_transitionBottomPaddingOverride != null && viewInsets > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_transitionBottomPaddingOverride != null) {
          setState(() => _transitionBottomPaddingOverride = null);
        }
      });
    }

    if (viewInsets > 0 && !_showEmojiPicker) {
      if (_lastKeyboardHeight == null || viewInsets > _lastKeyboardHeight!) {
        _lastKeyboardHeight = viewInsets;
      }
    }

    final isKeyboardOpen = viewInsets > 0 && !_showEmojiPicker;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        final double rawEmojiHeight =
            (_showEmojiPicker
                ? (_emojiPickerHeightOverride ?? _lastKeyboardHeight)
                : _lastKeyboardHeight) ??
            (context.screenHeight * 0.38);
        final double emojiPickerHeight =
            (_showEmojiPicker && _emojiPickerHeightOverride != null)
            ? rawEmojiHeight.toDouble()
            : rawEmojiHeight
                  .clamp(responsive.size(220), context.screenHeight * 0.55)
                  .toDouble();

        final double inputBottomPadding = _showEmojiPicker
            ? emojiPickerHeight + responsive.spacing(8)
            : (isKeyboardOpen
                  ? viewInsets + responsive.spacing(8)
                  : (_transitionBottomPaddingOverride != null
                        ? _transitionBottomPaddingOverride! +
                              responsive.spacing(8)
                        : responsive.spacing(12)));

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Edit mode banner
            if (widget.isEditing)
              EditModeBanner(
                editingLabel: widget.editingLabel,
                responsive: responsive,
                isDark: isDark,
                isSavingEdit: widget.isSavingEdit,
                onCancel: widget.onEditCancel,
              ),

            // Input field row
            AnimatedPadding(
              duration: _showEmojiPicker
                  ? Duration.zero
                  : const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                left: responsive.spacing(12),
                right: responsive.spacing(12),
                top: widget.isEditing
                    ? responsive.spacing(6)
                    : responsive.spacing(8),
                bottom: inputBottomPadding,
              ),
              child: _showAudioConfirmation
                  ? AudioConfirmationWidget(
                      responsive: responsive,
                      isDark: isDark,
                      recordedDurationSeconds: _recordedDurationSeconds,
                      audioFilePath: widget.audioFilePath,
                      onCancel: () {
                        widget.onRecordingCancelled?.call();
                        setState(() => _showAudioConfirmation = false);
                      },
                      onSend: () {
                        setState(() => _showAudioConfirmation = false);
                        widget.onAudioSendConfirmed?.call();
                      },
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Input pill / Recording overlay
                        // Use Stack to keep InputPillWidget mounted (preserves
                        // keyboard focus) while showing recording overlay on top.
                        Expanded(
                          child: Stack(
                            children: [
                              // Keep input pill in tree but invisible during recording
                              Offstage(
                                offstage: _isRecording,
                                child: InputPillWidget(
                                  pillKey: _inputPillKey,
                                  textController: widget.textController,
                                  focusNode: widget.focusNode,
                                  responsive: responsive,
                                  isDark: isDark,
                                  showEmojiPicker: _showEmojiPicker,
                                  showAttachmentPanel: _showAttachmentPanel,
                                  showCamera: _showCamera,
                                  onTextChanged: widget.onTextChanged,
                                  onSubmitted: widget.onSend,
                                  onEmojiToggle: _toggleEmojiPicker,
                                  onAttachmentToggle: _toggleAttachmentPanel,
                                  onCameraTap: widget.onCameraTap,
                                  replyName: widget.replyName,
                                  replyText: widget.replyText,
                                  replyIcon: widget.replyIcon,
                                  replyAssetIcon: widget.replyAssetIcon,
                                  onCancelReply: widget.onCancelReply,
                                ),
                              ),
                              if (_isRecording)
                                AudioRecordOverlayWidget(
                                  key: _recordOverlayKey,
                                  responsive: responsive,
                                  isDark: isDark,
                                  maxDurationSeconds: 60,
                                  onCancel: () {
                                    widget.onRecordingCancelled?.call();
                                    setState(() => _isRecording = false);
                                  },
                                  onStopRecording: (seconds) {
                                    setState(() => _isRecording = false);
                                    widget.onRecordingStopped?.call(seconds);
                                    // Delay to let async recorder.stop() finish
                                    // and parent setState with audioFilePath
                                    Future.delayed(
                                      const Duration(milliseconds: 300),
                                      () {
                                        if (!mounted) return;
                                        setState(() {
                                          _recordedDurationSeconds = seconds;
                                          _showAudioConfirmation = true;
                                        });
                                      },
                                    );
                                  },
                                  onMaxDurationReached: () {
                                    AppSnackbar.showError(
                                      context,
                                      'Maximum recording limit is 1 minute',
                                      duration: const Duration(seconds: 2),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: responsive.spacing(10)),
                        // Send / Mic button
                        SendButtonWidget(
                          buttonKey: _sendButtonKey,
                          responsive: responsive,
                          canSend: canSend,
                          isEditing: widget.isEditing,
                          isSending: widget.isSending,
                          isSavingEdit: widget.isSavingEdit,
                          onSend: widget.onSend,
                          onEditSave: widget.onEditSave,
                          isRecording: _isRecording,
                          onMicTap: widget.onMicTap,
                          onMicLongPressStart: () {
                            setState(() {
                              _isRecording = true;
                              _slideCancelled = false;
                            });
                            widget.onMicLongPressStart?.call();
                          },
                          onSlideToCancel: () {
                            if (_slideCancelled) return;
                            _slideCancelled = true;
                            widget.onRecordingCancelled?.call();
                            setState(() => _isRecording = false);
                          },
                          onMicLongPressEnd: () {
                            if (_slideCancelled) return;
                            // Tell the overlay to stop → it fires onStopRecording
                            // which transitions to the confirmation UI.
                            _recordOverlayKey.currentState?.stopRecording();
                            widget.onMicLongPressEnd?.call();
                          },
                        ),
                      ],
                    ),
            ),

            // Emoji picker
            if (_showEmojiPicker)
              EmojiPickerSection(
                height: emojiPickerHeight,
                responsive: responsive,
                isDark: isDark,
                onEmojiSelected: _insertEmoji,
              ),
          ],
        );
      },
    );
  }
}
