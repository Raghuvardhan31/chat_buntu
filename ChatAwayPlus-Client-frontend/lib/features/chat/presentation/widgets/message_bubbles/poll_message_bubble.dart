import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/data/socket/websocket_repository/websocket_chat_repository.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';

class PollMessageBubble extends StatefulWidget {
  const PollMessageBubble({
    super.key,
    required this.message,
    required this.isSender,
    required this.currentUserId,
  });

  final ChatMessageModel message;
  final bool isSender;
  final String currentUserId;

  @override
  State<PollMessageBubble> createState() => _PollMessageBubbleState();
}

class _PollMessageBubbleState extends State<PollMessageBubble> {
  Set<String> _votedOptionIds = {};
  bool _isVoting = false;
  StreamSubscription<Map<String, dynamic>>? _pollVoteSubscription;

  // Local vote counts to show optimistic updates
  Map<String, int> _localVoteCounts = {};
  int _localTotalVotes = 0;

  @override
  void initState() {
    super.initState();
    _loadVotedOptions();
    _initializeLocalVoteCounts();
    _subscribeToPollVotes();
  }

  @override
  void dispose() {
    _pollVoteSubscription?.cancel();
    super.dispose();
  }

  void _initializeLocalVoteCounts() {
    final decoded = _tryDecodeJson(widget.message.message);
    if (decoded is Map) {
      final options = decoded['options'];
      if (options is List) {
        for (final opt in options) {
          if (opt is Map) {
            final id = opt['id']?.toString() ?? '';
            final votes = (opt['votes'] as int?) ?? 0;
            _localVoteCounts[id] = votes;
            _localTotalVotes += votes;
          }
        }
      }
    }
  }

  void _subscribeToPollVotes() {
    _pollVoteSubscription = WebSocketChatRepository.instance.pollVoteStream
        .listen((data) {
          final pollMessageId = data['pollMessageId']?.toString();
          if (pollMessageId == widget.message.id) {
            debugPrint('📊 Poll vote update received for this poll: $data');
            // Update local vote state from server data
            if (mounted) {
              setState(() {
                // If server sends updated options with vote counts
                final options = data['options'];
                if (options is List) {
                  _localVoteCounts.clear();
                  _localTotalVotes = 0;
                  for (final opt in options) {
                    if (opt is Map) {
                      final id = opt['id']?.toString() ?? '';
                      final votes = (opt['votes'] as int?) ?? 0;
                      _localVoteCounts[id] = votes;
                      _localTotalVotes += votes;
                    }
                  }
                }
                // Update voted options if provided
                final votedBy = data['votedBy'];
                if (votedBy is Map) {
                  final userVotes = votedBy[widget.currentUserId];
                  if (userVotes is List) {
                    _votedOptionIds = Set<String>.from(
                      userVotes.map((e) => e.toString()),
                    );
                  }
                }
              });
            }
          }
        });
  }

  void _loadVotedOptions() {
    // Parse voted options from message if available
    final decoded = _tryDecodeJson(widget.message.message);
    if (decoded is Map) {
      final votedBy = decoded['votedBy'];
      if (votedBy is Map) {
        final userVotes = votedBy[widget.currentUserId];
        if (userVotes is List) {
          _votedOptionIds = Set<String>.from(
            userVotes.map((e) => e.toString()),
          );
        }
      }
      // Also check for myVotes field
      final myVotes = decoded['myVotes'];
      if (myVotes is List) {
        _votedOptionIds = Set<String>.from(myVotes.map((e) => e.toString()));
      }
    }
  }

  Future<void> _handleVote(String optionId) async {
    if (_isVoting) return;

    final payload = _PollPayload.fromMessage(widget.message.message);

    // Check if already voted for this option - toggle it off
    if (_votedOptionIds.contains(optionId)) {
      await _handleRemoveVote();
      return;
    }

    // Check if already voted and not multi-select - remove old vote first
    if (!payload.allowMultiple && _votedOptionIds.isNotEmpty) {
      // Get the previous option to decrement its count
      final previousOptionId = _votedOptionIds.first;
      setState(() {
        _isVoting = true;
        // Decrement previous option
        _localVoteCounts[previousOptionId] =
            (_localVoteCounts[previousOptionId] ?? 1) - 1;
        _votedOptionIds.clear();
        // Add new vote
        _votedOptionIds.add(optionId);
        _localVoteCounts[optionId] = (_localVoteCounts[optionId] ?? 0) + 1;
      });
    } else {
      setState(() {
        _isVoting = true;
        _votedOptionIds.add(optionId);
        // Optimistically increment vote count
        _localVoteCounts[optionId] = (_localVoteCounts[optionId] ?? 0) + 1;
        _localTotalVotes++;
      });
    }

    try {
      final success = await WebSocketChatRepository.instance.addPollVote(
        pollMessageId: widget.message.id,
        optionId: optionId,
      );

      if (!success) {
        // Revert on failure
        setState(() {
          _votedOptionIds.remove(optionId);
          _localVoteCounts[optionId] = (_localVoteCounts[optionId] ?? 1) - 1;
          _localTotalVotes--;
        });
      }
    } catch (e) {
      debugPrint('❌ Poll vote error: $e');
      setState(() {
        _votedOptionIds.remove(optionId);
        _localVoteCounts[optionId] = (_localVoteCounts[optionId] ?? 1) - 1;
        _localTotalVotes--;
      });
    } finally {
      setState(() {
        _isVoting = false;
      });
    }
  }

  Future<void> _handleRemoveVote() async {
    if (_isVoting) return;

    final previousVotes = Set<String>.from(_votedOptionIds);
    final previousCounts = Map<String, int>.from(_localVoteCounts);
    final previousTotal = _localTotalVotes;

    setState(() {
      _isVoting = true;
      // Decrement counts for all voted options
      for (final optionId in _votedOptionIds) {
        _localVoteCounts[optionId] = (_localVoteCounts[optionId] ?? 1) - 1;
        _localTotalVotes--;
      }
      _votedOptionIds.clear();
    });

    try {
      final success = await WebSocketChatRepository.instance.removePollVote(
        pollMessageId: widget.message.id,
      );

      if (!success) {
        // Revert on failure
        setState(() {
          _votedOptionIds = previousVotes;
          _localVoteCounts = previousCounts;
          _localTotalVotes = previousTotal;
        });
      }
    } catch (e) {
      debugPrint('❌ Poll remove vote error: $e');
      setState(() {
        _votedOptionIds = previousVotes;
        _localVoteCounts = previousCounts;
        _localTotalVotes = previousTotal;
      });
    } finally {
      setState(() {
        _isVoting = false;
      });
    }
  }

  static dynamic _tryDecodeJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  String _getVoteSummary(int totalVotes) {
    if (totalVotes == 0) return 'No votes yet';
    return '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}';
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final payload = _PollPayload.fromMessage(widget.message.message);
        // Use local vote counts for optimistic UI updates
        final totalVotes = _localTotalVotes > 0
            ? _localTotalVotes
            : payload.totalVotes;

        final headerColor = isDark
            ? Colors.white70
            : AppColors.greyTextSecondary;
        final bodyColor = isDark ? Colors.white : AppColors.greyTextPrimary;
        final accent = AppColors.primary;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(12),
            vertical: responsive.spacing(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(responsive.spacing(6)),
                    decoration: BoxDecoration(
                      color: accent.withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(responsive.size(10)),
                    ),
                    child: Icon(
                      Icons.poll_rounded,
                      color: accent,
                      size: responsive.size(18),
                    ),
                  ),
                  SizedBox(width: responsive.spacing(8)),
                  Text(
                    'Poll',
                    style: AppTextSizes.small(context).copyWith(
                      color: headerColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (payload.allowMultiple || payload.anonymous) ...[
                    SizedBox(width: responsive.spacing(8)),
                    _PollMetaChip(
                      label: payload.allowMultiple
                          ? 'Multi-select'
                          : 'Anonymous',
                      responsive: responsive,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
              SizedBox(height: responsive.spacing(12)),
              Text(
                payload.question,
                style: AppTextSizes.large(context).copyWith(
                  color: bodyColor,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              SizedBox(height: responsive.spacing(12)),
              ...payload.options.map(
                (option) => _PollOptionRow(
                  option: option,
                  totalVotes: totalVotes,
                  responsive: responsive,
                  isDark: isDark,
                  textColor: bodyColor,
                  accent: accent,
                  isVoted: _votedOptionIds.contains(option.id),
                  canVote: true, // Always allow tap - can add or remove vote
                  isVoting: _isVoting,
                  onTap: () => _handleVote(option.id),
                  voteCount: _localVoteCounts[option.id],
                ),
              ),
              SizedBox(height: responsive.spacing(6)),
              Row(
                children: [
                  Text(
                    _votedOptionIds.isNotEmpty
                        ? '${_getVoteSummary(totalVotes)} • You voted'
                        : _getVoteSummary(totalVotes),
                    style: AppTextSizes.small(
                      context,
                    ).copyWith(color: headerColor),
                  ),
                  if (payload.allowMultiple && payload.anonymous)
                    Text(
                      ' - Votes hidden',
                      style: AppTextSizes.small(
                        context,
                      ).copyWith(color: headerColor),
                    ),
                  const Spacer(),
                  Text(
                    ChatHelper.formatMessageTime(widget.message.createdAt),
                    style: AppTextSizes.small(
                      context,
                    ).copyWith(color: headerColor),
                  ),
                  if (widget.isSender) ...[
                    SizedBox(width: responsive.spacing(4)),
                    MessageDeliveryStatusIcon(
                      status: widget.message.messageStatus,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  const _PollOptionRow({
    required this.option,
    required this.totalVotes,
    required this.responsive,
    required this.isDark,
    required this.textColor,
    required this.accent,
    required this.isVoted,
    required this.canVote,
    required this.isVoting,
    required this.onTap,
    this.voteCount,
  });

  final _PollOption option;
  final int totalVotes;
  final ResponsiveSize responsive;
  final bool isDark;
  final Color textColor;
  final Color accent;
  final bool isVoted;
  final bool canVote;
  final bool isVoting;
  final VoidCallback onTap;
  final int? voteCount; // Override for local vote count

  @override
  Widget build(BuildContext context) {
    final votes = voteCount ?? option.votes;
    final percentage = totalVotes == 0
        ? 0.0
        : (votes / totalVotes).clamp(0.0, 1.0);
    final percentLabel = '${(percentage * 100).round()}%';
    final backgroundColor = isDark
        ? Colors.white.withAlpha(18)
        : Colors.white.withAlpha(220);
    final borderColor = isVoted
        ? accent
        : (isDark ? Colors.white24 : AppColors.greyLight.withAlpha(140));
    final fillColor = isVoted
        ? accent.withAlpha((0.35 * 255).round())
        : accent.withAlpha((0.22 * 255).round());

    return Padding(
      padding: EdgeInsets.only(bottom: responsive.spacing(8)),
      child: GestureDetector(
        onTap: canVote && !isVoting ? onTap : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: responsive.size(44),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(responsive.size(12)),
                    border: Border.all(
                      color: borderColor,
                      width: isVoted ? 2 : 1,
                    ),
                  ),
                ),
                if (percentage > 0)
                  Container(
                    height: responsive.size(44),
                    width: constraints.maxWidth * percentage,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(responsive.size(12)),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.spacing(12),
                  ),
                  child: Row(
                    children: [
                      if (isVoted) ...[
                        Icon(
                          Icons.check_circle,
                          color: accent,
                          size: responsive.size(18),
                        ),
                        SizedBox(width: responsive.spacing(8)),
                      ],
                      Expanded(
                        child: Text(
                          option.text,
                          style: AppTextSizes.regular(context).copyWith(
                            color: textColor,
                            fontWeight: isVoted
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        percentLabel,
                        style: AppTextSizes.small(context).copyWith(
                          color: textColor.withAlpha((0.75 * 255).round()),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PollMetaChip extends StatelessWidget {
  const _PollMetaChip({
    required this.label,
    required this.responsive,
    required this.isDark,
  });

  final String label;
  final ResponsiveSize responsive;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(8),
        vertical: responsive.spacing(3),
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.white.withAlpha(200),
        borderRadius: BorderRadius.circular(responsive.size(12)),
        border: Border.all(
          color: isDark ? Colors.white24 : AppColors.greyLight.withAlpha(140),
        ),
      ),
      child: Text(
        label,
        style: AppTextSizes.small(context).copyWith(
          color: isDark ? Colors.white70 : AppColors.greyTextSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PollPayload {
  _PollPayload({
    required this.question,
    required this.options,
    required this.allowMultiple,
    required this.anonymous,
  });

  final String question;
  final List<_PollOption> options;
  final bool allowMultiple;
  final bool anonymous;

  int get totalVotes => options.fold(0, (sum, option) => sum + option.votes);

  String get summary {
    final votes = totalVotes;
    if (votes == 0) {
      return 'No votes yet';
    }
    return '$votes ${votes == 1 ? 'vote' : 'votes'}';
  }

  static _PollPayload fromMessage(String raw) {
    final fallbackQuestion = raw.trim().isEmpty ? 'Untitled poll' : raw.trim();
    Map<String, dynamic>? map;

    final decoded = _tryDecodeJson(raw);
    if (decoded is Map) {
      map = Map<String, dynamic>.from(decoded);
    }

    final question =
        (map?['question'] ?? map?['title'] ?? map?['message'] ?? map?['text'])
            ?.toString()
            .trim();

    final optionsRaw =
        map?['options'] ?? map?['choices'] ?? map?['answers'] ?? map?['items'];
    final parsedOptions = _parseOptions(optionsRaw);

    return _PollPayload(
      question: (question?.isNotEmpty ?? false) ? question! : fallbackQuestion,
      options: parsedOptions.isNotEmpty
          ? parsedOptions
          : [
              const _PollOption(id: 'option-1', text: 'Option 1'),
              const _PollOption(id: 'option-2', text: 'Option 2'),
            ],
      allowMultiple: _tryParseBool(
        map?['allowMultiple'] ?? map?['multiSelect'] ?? map?['multi_select'],
      ),
      anonymous: _tryParseBool(map?['anonymous'] ?? map?['isAnonymous']),
    );
  }

  static List<_PollOption> _parseOptions(dynamic raw) {
    if (raw is List) {
      return raw.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          return _PollOption(
            id: (map['id'] ?? 'option-${index + 1}').toString(),
            text: (map['text'] ?? map['title'] ?? map['label'] ?? 'Option')
                .toString(),
            votes: _tryParseInt(map['votes'] ?? map['count'] ?? map['total']),
          );
        }
        if (item is String) {
          return _PollOption(id: 'option-${index + 1}', text: item);
        }
        return _PollOption(id: 'option-${index + 1}', text: item.toString());
      }).toList();
    }
    return <_PollOption>[];
  }

  static dynamic _tryDecodeJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      return jsonDecode(trimmed);
    } catch (_) {}

    try {
      final decoded = Uri.decodeComponent(trimmed);
      return jsonDecode(decoded);
    } catch (_) {}

    return null;
  }

  static bool _tryParseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final str = value.toString().toLowerCase();
    return str == 'true' || str == '1' || str == 'yes';
  }

  static int _tryParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}

class _PollOption {
  const _PollOption({required this.id, required this.text, this.votes = 0});

  final String id;
  final String text;
  final int votes;
}
