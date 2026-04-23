import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/routes/navigation_service.dart';
import 'package:chataway_plus/features/voice_call/data/models/call_model.dart';
import 'package:chataway_plus/features/voice_call/presentation/providers/call_provider.dart';
import 'package:chataway_plus/features/voice_call/presentation/widgets/call_tile.dart';

/// Global key for accessing CallHistoryPage state from MainNavigationPage
final callHistoryPageKey = GlobalKey<CallHistoryPageState>();

/// Call History page — shown as a tab in the main navigation
/// WhatsApp-style: vertical list with All / Missed filter chips
class CallHistoryPage extends ConsumerStatefulWidget {
  const CallHistoryPage({super.key});

  @override
  ConsumerState<CallHistoryPage> createState() => CallHistoryPageState();
}

class CallHistoryPageState extends ConsumerState<CallHistoryPage> {
  int _selectedFilter = 0; // 0=All, 1=Missed, 2=Outgoing, 3=Incoming

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callProvider.notifier).loadCallHistoryFromServer();
    });
  }

  List<CallModel> _applyFilter(List<CallModel> calls) {
    switch (_selectedFilter) {
      case 1:
        return calls.where((c) => c.isMissed).toList();
      case 2:
        return calls.where((c) => c.isOutgoing).toList();
      case 3:
        return calls.where((c) => c.isIncoming).toList();
      default:
        return calls;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final callHistory = ref.watch(callHistoryProvider);
    final isLoading = ref.watch(callLoadingProvider);
    final filteredCalls = _applyFilter(callHistory);

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        // If no calls at all, show empty state
        if (!isLoading && callHistory.isEmpty) {
          return _buildEmptyState(responsive, isDark);
        }

        return Stack(
          children: [
            Column(
              children: [
                // Filter chips
                _buildFilterChips(responsive, isDark),
                // Call list or loading
                Expanded(
                  child: isLoading && callHistory.isEmpty
                      ? Center(
                          child: SizedBox(
                            width: responsive.size(28),
                            height: responsive.size(28),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : filteredCalls.isEmpty
                      ? _buildFilterEmptyState(responsive, isDark)
                      : ListView.builder(
                          padding: EdgeInsets.only(
                            bottom: responsive.spacing(80),
                          ),
                          itemCount: filteredCalls.length,
                          itemBuilder: (context, index) {
                            return CallTile(
                              call: filteredCalls[index],
                              onCallTap: () {
                                // Re-call this contact
                                NavigationService.goToCallingHub();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            // FAB to open Calling Hub
            Positioned(
              bottom: responsive.spacing(16),
              right: responsive.spacing(16),
              child: FloatingActionButton(
                onPressed: () => NavigationService.goToCallingHub(),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add_call, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // FILTER CHIPS — All / Missed / Outgoing / Incoming
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildFilterChips(ResponsiveSize responsive, bool isDark) {
    const labels = ['All', 'Missed', 'Outgoing', 'Incoming'];
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacing(12),
        vertical: responsive.spacing(8),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = _selectedFilter == index;
          return Padding(
            padding: EdgeInsets.only(right: responsive.spacing(8)),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = index),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.spacing(14),
                  vertical: responsive.spacing(6),
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(responsive.size(16)),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: responsive.size(13),
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // EMPTY STATES
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildEmptyState(ResponsiveSize responsive, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: responsive.size(100),
            height: responsive.size(100),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.call_rounded,
              size: responsive.size(48),
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: responsive.spacing(20)),
          Text(
            'Start calling',
            style: TextStyle(
              fontSize: responsive.size(18),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
          ),
          SizedBox(height: responsive.spacing(8)),
          Text(
            'Select contacts from Calling Hub\nto start a call',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.size(14),
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              height: 1.4,
            ),
          ),
          SizedBox(height: responsive.spacing(24)),
          GestureDetector(
            onTap: () => NavigationService.goToCallingHub(),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(24),
                vertical: responsive.spacing(12),
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(responsive.size(24)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    color: Colors.white,
                    size: responsive.size(18),
                  ),
                  SizedBox(width: responsive.spacing(8)),
                  Text(
                    'Open Calling Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsive.size(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterEmptyState(ResponsiveSize responsive, bool isDark) {
    const filterLabels = ['', 'missed', 'outgoing', 'incoming'];
    final label = filterLabels[_selectedFilter];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: responsive.size(40),
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.grey.shade300,
          ),
          SizedBox(height: responsive.spacing(12)),
          Text(
            'No $label calls',
            style: TextStyle(
              fontSize: responsive.size(15),
              color: isDark ? Colors.white38 : const Color(0xFFBDBDBD),
            ),
          ),
        ],
      ),
    );
  }
}
