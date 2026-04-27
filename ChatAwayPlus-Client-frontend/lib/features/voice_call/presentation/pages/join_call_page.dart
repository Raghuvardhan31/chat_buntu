import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/active_call_page.dart';
import 'package:chataway_plus/features/voice_call/presentation/pages/video_call_page.dart';
import 'package:chataway_plus/features/voice_call/presentation/widgets/call_avatar.dart';

/// Join Call Screen - Required transition after accepting an incoming call (Requirement 7)
/// Shows the Meeting ID (Channel Name) and allows user to confirm/enter to join.
class JoinCallPage extends ConsumerStatefulWidget {
  final String currentUserId;
  final String callId;
  final String contactId;
  final String contactName;
  final String? contactProfilePic;
  final CallType callType;
  final String channelName;

  const JoinCallPage({
    super.key,
    required this.currentUserId,
    required this.callId,
    required this.contactId,
    required this.contactName,
    this.contactProfilePic,
    required this.callType,
    required this.channelName,
  });

  @override
  ConsumerState<JoinCallPage> createState() => _JoinCallPageState();
}

class _JoinCallPageState extends ConsumerState<JoinCallPage> {
  late TextEditingController _idController;
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.channelName);
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  void _onJoin() {
    if (_idController.text.trim().isEmpty) return;

    final Widget callPage = widget.callType == CallType.video
        ? VideoCallPage(
            currentUserId: widget.currentUserId,
            contactName: widget.contactName,
            contactProfilePic: widget.contactProfilePic,
            channelName: _idController.text.trim(),
            callId: widget.callId,
            otherUserId: widget.contactId,
          )
        : ActiveCallPage(
            currentUserId: widget.currentUserId,
            contactName: widget.contactName,
            contactProfilePic: widget.contactProfilePic,
            callType: widget.callType,
            channelName: _idController.text.trim(),
            callId: widget.callId,
            otherUserId: widget.contactId,
          );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => callPage),
    );
  }

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

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Text(
              'Join Call',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(responsive.spacing(24)),
            child: Column(
              children: [
                SizedBox(height: responsive.spacing(20)),
                CallAvatar(
                  name: widget.contactName,
                  profilePicUrl: widget.contactProfilePic,
                  size: 100,
                ),
                SizedBox(height: responsive.spacing(24)),
                Text(
                  widget.contactName,
                  style: TextStyle(
                    fontSize: responsive.size(24),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: responsive.spacing(8)),
                Text(
                  'Incoming ${widget.callType == CallType.video ? "Video" : "Audio"} Call',
                  style: TextStyle(
                    fontSize: responsive.size(16),
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                SizedBox(height: responsive.spacing(40)),
                Container(
                  padding: EdgeInsets.all(responsive.spacing(20)),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meeting ID',
                        style: TextStyle(
                          fontSize: responsive.size(14),
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: responsive.spacing(12)),
                      TextField(
                        controller: _idController,
                        style: TextStyle(
                          fontSize: responsive.size(18),
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter Meeting ID',
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      SizedBox(height: responsive.spacing(8)),
                      Text(
                        'Confirm the ID generated by the system to join.',
                        style: TextStyle(
                          fontSize: responsive.size(12),
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: responsive.spacing(40)),
                SizedBox(
                  width: double.infinity,
                  height: responsive.size(56),
                  child: ElevatedButton(
                    onPressed: _onJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Join Now',
                      style: TextStyle(
                        fontSize: responsive.size(18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: responsive.spacing(16)),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: responsive.size(16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
