import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/core/database/tables/cache/app_startup_snapshot_table.dart';
import 'package:chataway_plus/core/database/tables/user/current_user_table.dart';
import 'package:chataway_plus/core/routes/route_names.dart';

class ConnectivitySnapshotRefresher extends ConsumerStatefulWidget {
  final Widget child;
  const ConnectivitySnapshotRefresher({super.key, required this.child});

  @override
  ConsumerState<ConnectivitySnapshotRefresher> createState() =>
      _ConnectivitySnapshotRefresherState();
}

class _ConnectivitySnapshotRefresherState
    extends ConsumerState<ConnectivitySnapshotRefresher> {
  bool _wasOnline = false;
  DateTime? _lastRefresh;

  // Note: Riverpod requires ref.listen to be called during build.
  // We therefore attach the listener inside build(), not initState().

  void _triggerRefresh() {
    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!) < const Duration(minutes: 5)) {
      if (kDebugMode) debugPrint('[Refresher] skip: throttled');
      return;
    }
    _lastRefresh = now;
    Future.microtask(_refreshSnapshotIfStale);
  }

  Future<void> _refreshSnapshotIfStale() async {
    try {
      final userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
      final token = await TokenSecureStorage.instance.getToken();
      if (userId == null || userId.isEmpty || token == null || token.isEmpty) {
        return;
      }

      final snap = await AppStartupSnapshotTable.instance.getByUserId(userId);
      final fresh =
          snap != null &&
          AppStartupSnapshotTable.instance.isSnapshotFresh(
            snap,
            ttl: const Duration(hours: 24),
          );
      if (fresh) {
        if (kDebugMode) debugPrint('[Refresher] skip: snapshot fresh');
        return;
      }

      final row = await CurrentUserProfileTable.instance.getByUserId(userId);
      if (row == null) return;
      final firstName = row[CurrentUserProfileTable.columnFirstName]
          ?.toString()
          .trim();
      final status = row[CurrentUserProfileTable.columnStatusContent]
          ?.toString()
          .trim();
      final statusMeaningful =
          status != null &&
          status.isNotEmpty &&
          status != 'Write custom or tap to choose preset';
      final profileComplete =
          (firstName != null && firstName.isNotEmpty) && statusMeaningful;
      final route = profileComplete
          ? RouteNames.mainNavigation
          : RouteNames.currentUserProfile;
      int ageMs = 0;
      if (snap != null) {
        final last =
            (snap[AppStartupSnapshotTable.columnLastVerifiedAt] as int?) ?? 0;
        ageMs = DateTime.now().millisecondsSinceEpoch - last;
      }
      await AppStartupSnapshotTable.instance.upsertSnapshot(
        userId: userId,
        profileComplete: profileComplete,
        lastKnownRoute: route,
      );
      if (kDebugMode) {
        debugPrint(
          '[Refresher] upsert -> complete=$profileComplete, route=$route, ageMs=$ageMs',
        );
      }
    } catch (_) {
      if (kDebugMode) {
        debugPrint('⚠️ [Refresher] error: snapshot refresh failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(internetStatusStreamProvider, (prev, next) {
      final prevOnline =
          prev?.maybeWhen(data: (v) => v, orElse: () => false) ?? _wasOnline;
      final nowOnline = next.maybeWhen(data: (v) => v, orElse: () => false);
      if (!prevOnline && nowOnline) {
        if (kDebugMode) debugPrint('[Refresher] online detected');
        _triggerRefresh();
      }
      _wasOnline = nowOnline;
    });
    return widget.child;
  }
}
