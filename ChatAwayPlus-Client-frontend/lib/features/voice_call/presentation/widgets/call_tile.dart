import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';

/// A single call history tile — WhatsApp-style
/// Shows contact avatar, name, call direction/status, timestamp, and call type icon
class CallTile extends StatelessWidget {
  final CallModel call;
  final VoidCallback? onTap;
  final VoidCallback? onCallTap;

  const CallTile({super.key, required this.call, this.onTap, this.onCallTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(16),
              vertical: responsive.spacing(10),
            ),
            child: Row(
              children: [
                // Avatar
                _buildAvatar(responsive, isDark),
                SizedBox(width: responsive.spacing(14)),
                // Name + call info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.contactName,
                        style: TextStyle(
                          fontSize: responsive.size(16),
                          fontWeight: FontWeight.w600,
                          color: call.isMissed
                              ? const Color(0xFFEF4444)
                              : (isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: responsive.spacing(3)),
                      Row(
                        children: [
                          _buildDirectionIcon(responsive),
                          SizedBox(width: responsive.spacing(4)),
                          Text(
                            _getCallSubtitle(),
                            style: TextStyle(
                              fontSize: responsive.size(13),
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Timestamp
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTimestamp(call.timestamp),
                      style: TextStyle(
                        fontSize: responsive.size(12),
                        color: call.isMissed
                            ? const Color(0xFFEF4444)
                            : (isDark
                                  ? Colors.white38
                                  : const Color(0xFF9CA3AF)),
                      ),
                    ),
                    SizedBox(height: responsive.spacing(4)),
                    // Call type icon button
                    GestureDetector(
                      onTap: onCallTap,
                      child: Icon(
                        call.callType == CallType.video
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: AppColors.primary,
                        size: responsive.size(22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(ResponsiveSize responsive, bool isDark) {
    final avatarSize = responsive.size(50);
    final initials = _getInitials(call.contactName);

    if (call.contactProfilePic != null && call.contactProfilePic!.isNotEmpty) {
      final fullUrl = call.contactProfilePic!.startsWith('http')
          ? call.contactProfilePic!
          : '${ApiUrls.mediaBaseUrl}${call.contactProfilePic!}';
      return CircleAvatar(
        radius: avatarSize / 2,
        backgroundImage: NetworkImage(fullUrl),
      );
    }

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getAvatarColors(call.contactName),
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: responsive.size(18),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionIcon(ResponsiveSize responsive) {
    IconData icon;
    Color color;

    if (call.isMissed) {
      icon = Icons.call_missed_rounded;
      color = const Color(0xFFEF4444); // Red for missed
    } else if (call.isOutgoing) {
      icon = Icons.call_made_rounded;
      color = const Color(0xFF22C55E); // Green for outgoing (you called)
    } else {
      icon = Icons.call_received_rounded;
      color = const Color(0xFF3B82F6); // Blue for received (they called you)
    }

    return Icon(icon, size: responsive.size(16), color: color);
  }

  String _getCallSubtitle() {
    final typeLabel = call.callType == CallType.video ? 'Video' : 'Voice';
    // Direction label: clearly tell the user what happened
    final directionLabel = call.isOutgoing ? 'Outgoing' : 'Incoming';

    if (call.isMissed) return 'Missed $typeLabel Call';
    if (call.status == CallStatus.rejected) {
      return call.isOutgoing
          ? 'Outgoing $typeLabel · No Answer'
          : 'Declined $typeLabel Call';
    }
    if (call.status == CallStatus.failed) {
      return '$directionLabel $typeLabel · Failed';
    }
    if (call.formattedDuration.isNotEmpty) {
      return '$directionLabel $typeLabel · ${call.formattedDuration}';
    }
    return '$directionLabel $typeLabel Call';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    final isYesterday = diff.inDays == 1;
    if (isYesterday) return 'Yesterday';

    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[timestamp.weekday - 1];
    }

    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  /// Generate consistent avatar colors based on name
  List<Color> _getAvatarColors(String name) {
    final hash = name.codeUnits.fold(0, (prev, code) => prev + code);
    final palettes = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)], // Indigo → Violet
      [const Color(0xFFEC4899), const Color(0xFFF43F5E)], // Pink → Rose
      [const Color(0xFF14B8A6), const Color(0xFF06B6D4)], // Teal → Cyan
      [const Color(0xFFF59E0B), const Color(0xFFEF4444)], // Amber → Red
      [const Color(0xFF8B5CF6), const Color(0xFFA855F7)], // Violet → Purple
      [const Color(0xFF0EA5E9), const Color(0xFF3B82F6)], // Sky → Blue
      [const Color(0xFF22C55E), const Color(0xFF10B981)], // Green → Emerald
    ];
    return palettes[hash % palettes.length];
  }
}
