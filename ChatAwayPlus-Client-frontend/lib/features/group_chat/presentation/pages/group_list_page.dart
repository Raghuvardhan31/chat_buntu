import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/themes/app_text_styles.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/features/chat/presentation/pages/chat_list/widgets/group_chat_list_tile_widget.dart';
import 'package:chataway_plus/features/group_chat/presentation/providers/group_providers.dart';
import 'package:chataway_plus/features/chat/presentation/pages/chat_list/widgets/chat_list_empty_states.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';

class GroupListPage extends ConsumerStatefulWidget {
  const GroupListPage({super.key});

  @override
  ConsumerState<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends ConsumerState<GroupListPage> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final id = await ChatHelper.getCurrentUserId();
    if (mounted) {
      setState(() {
        _currentUserId = id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(myGroupsProvider);

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          body: groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return Center(
                  child: ChatListEmptyState(
                    responsive: responsive,
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(vertical: responsive.spacing(8)),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return GroupChatListTileWidget(
                    group: group,
                    currentUserId: _currentUserId,
                    responsive: responsive,
                    onNavigateBack: () async {
                      ref.invalidate(myGroupsProvider);
                    },
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (err, stack) {
              final isConnectionError = err.toString().contains('SocketException') || 
                                       err.toString().contains('ClientException');
              
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey[400]),
                      SizedBox(height: responsive.spacing(16)),
                      Text(
                        isConnectionError 
                          ? 'Unable to connect to server. Please check your internet connection and ensure the server is running.'
                          : 'Error loading groups: $err',
                        textAlign: TextAlign.center,
                        style: AppTextSizes.regular(context).copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      SizedBox(height: responsive.spacing(24)),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(myGroupsProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
