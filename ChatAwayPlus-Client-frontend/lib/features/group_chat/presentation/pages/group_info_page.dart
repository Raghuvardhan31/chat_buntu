import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/group_chat/models/group_models.dart';
import 'package:chataway_plus/features/group_chat/presentation/providers/group_providers.dart';
import 'package:chataway_plus/features/group_chat/data/group_chat_repository.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/shared/widgets/avatars/cached_circle_avatar.dart';

/// Group Info / Settings page
class GroupInfoPage extends ConsumerStatefulWidget {
  final GroupModel group;

  const GroupInfoPage({super.key, required this.group});

  @override
  ConsumerState<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends ConsumerState<GroupInfoPage> {
  String? _currentUserId;
  bool _isAdmin = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final token = await TokenSecureStorage().getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final decoded = utf8.decode(base64Url.decode(normalized));
          final json = jsonDecode(decoded) as Map<String, dynamic>;
          final uid = json['id']?.toString() ?? json['userId']?.toString() ?? '';
          if (mounted) {
            setState(() {
              _currentUserId = uid;
              _isAdmin = widget.group.members
                  .any((m) => m.userId == uid && m.role == 'admin');
            });
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await _confirm('Leave Group?', 'You will leave "${widget.group.name}".');
    if (!confirmed || _currentUserId == null) return;
    try {
      await GroupChatRepository.instance.removeMember(widget.group.id, _currentUserId!);
      ref.invalidate(myGroupsProvider);
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.settings.name == '/main-navigation');
      }
    } catch (e) {
      if (mounted) _showError('Failed to leave group: $e');
    }
  }

  Future<void> _removeMember(GroupMemberModel member) async {
    final confirmed = await _confirm(
        'Remove Member?', 'Remove ${member.user?.displayName ?? 'this member'} from the group?');
    if (!confirmed) return;
    try {
      await GroupChatRepository.instance.removeMember(widget.group.id, member.userId);
      ref.invalidate(groupDetailsProvider(widget.group.id));
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _showError('Failed to remove member: $e');
    }
  }

  Future<void> _promoteToAdmin(GroupMemberModel member) async {
    try {
      await GroupChatRepository.instance.updateMemberRole(widget.group.id, member.userId, 'admin');
      ref.invalidate(groupDetailsProvider(widget.group.id));
    } catch (e) {
      if (mounted) _showError('Failed to promote: $e');
    }
  }

  Future<bool> _confirm(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm', style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupAsync = ref.watch(groupDetailsProvider(widget.group.id));
    final group = groupAsync.valueOrNull ?? widget.group;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111B21) : Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1F2C34) : AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(group.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.white24,
                    backgroundImage: group.icon != null && group.icon!.isNotEmpty
                        ? NetworkImage(group.icon!)
                        : null,
                    child: group.icon == null || group.icon!.isEmpty
                        ? Text(
                            group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                            style: const TextStyle(
                                fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                if (group.description != null && group.description!.isNotEmpty)
                  _InfoCard(
                    isDark: isDark,
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Description'),
                      subtitle: Text(group.description!),
                    ),
                  ),

                // Group details
                _InfoCard(
                  isDark: isDark,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.lock_outline,
                            color: group.isRestricted ? Colors.orange : Colors.green),
                        title: Text(
                            group.isRestricted ? 'Restricted group' : 'Open messaging',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(group.isRestricted
                            ? 'Only admins can send messages'
                            : 'All members can send messages'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Created'),
                        subtitle: Text(group.createdAt.toLocal().toString().split('.').first),
                      ),
                    ],
                  ),
                ),

                // Members section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '${group.members.length} Members',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey[700]),
                  ),
                ),

                _InfoCard(
                  isDark: isDark,
                  child: Column(
                    children: group.members.map((member) {
                      final isMe = member.userId == _currentUserId;
                      final displayName = member.user?.displayName ?? 'Unknown';
                      return ListTile(
                        leading: CachedCircleAvatar(
                          chatPictureUrl: member.user?.chatPicture,
                          radius: 22,
                          backgroundColor: AppColors.lighterGrey,
                          iconColor: AppColors.colorGrey,
                          contactName: displayName,
                        ),
                        title: Row(
                          children: [
                            Text(isMe ? 'You' : displayName,
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            if (member.isAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Admin',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(member.user?.mobileNo ?? '',
                            style: const TextStyle(fontSize: 12)),
                        trailing: _isAdmin && !isMe
                            ? PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'remove') _removeMember(member);
                                  if (val == 'admin') _promoteToAdmin(member);
                                },
                                itemBuilder: (_) => [
                                  if (!member.isAdmin)
                                    const PopupMenuItem(
                                        value: 'admin', child: Text('Make admin')),
                                  const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove', style: TextStyle(color: Colors.red))),
                                ],
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: _leaveGroup,
                    icon: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
                    label: const Text('Leave Group',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _InfoCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
