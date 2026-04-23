import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import 'package:chataway_plus/features/contacts/data/repositories/contacts_repository.dart';
import 'package:chataway_plus/core/storage/token_storage.dart';
import '../../../data/repositories/blocked_contacts/blocked_contacts_repository.dart'
    as iface;
import '../../../data/models/blocked_contacts_models.dart';
import 'blocked_contacts_state.dart';

class BlockedContactsNotifier extends StateNotifier<BlockedContactsState> {
  final iface.BlockedContactsRepository _repository;
  final ContactsRepository _contactsRepository;

  void _safeSetState(BlockedContactsState s) {
    if (mounted) state = s;
  }

  BlockedContactsNotifier(this._repository, this._contactsRepository)
    : super(const BlockedContactsState());

  /// Build UI state from local DB only
  Future<void> loadLocal() async {
    _safeSetState(
      state.copyWith(loadingState: BlockedContactsLoadingState.loading),
    );
    try {
      final currentUserId = await TokenSecureStorage.instance
          .getCurrentUserIdUUID();
      final currentPhone = await TokenSecureStorage.instance.getPhoneNumber();
      if (currentUserId == null || currentUserId.isEmpty) {
        _safeSetState(
          state.copyWith(
            loadingState: BlockedContactsLoadingState.loaded,
            blockedContacts: const [],
            availableContacts: const [],
            errorMessage: null,
          ),
        );
        return;
      }

      final blockedIds = await _repository.getBlockedUserIdsLocal(
        currentUserId,
      );
      final blockedRows = await _repository.getBlockedRowsLocal(currentUserId);
      final Map<String, Map<String, dynamic>> blockedRowById = {};
      for (final r in blockedRows) {
        final id = (r['blocked_user_id'] ?? r['blockedUserId'] ?? r['userId'])
            ?.toString()
            .trim();
        if (id == null || id.isEmpty) continue;
        blockedRowById[id] = r;
      }
      final appUsers = await _contactsRepository.loadRegisteredContacts();

      // Build a fast lookup map of appUserId -> ContactLocal to avoid O(n*m) scans
      final Map<String, ContactLocal> contactByAppUserId = {};
      for (final c in appUsers) {
        final id = c.appUserId;
        if (id != null && id.isNotEmpty) {
          contactByAppUserId[id] = c;
        }
      }

      String normalize(String phone) {
        final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
        return digits.length > 10
            ? digits.substring(digits.length - 10)
            : digits;
      }

      final normalizedCurrentPhone =
          (currentPhone != null && currentPhone.isNotEmpty)
          ? normalize(currentPhone)
          : '';

      final availableContacts = appUsers.where((c) {
        if (c.appUserId != null && c.appUserId == currentUserId) {
          return false;
        }
        if (normalizedCurrentPhone.isNotEmpty) {
          final normalizedContactPhone = normalize(c.mobileNo);
          if (normalizedContactPhone.isNotEmpty &&
              normalizedContactPhone == normalizedCurrentPhone) {
            return false;
          }
        }
        return !blockedIds.contains(c.appUserId);
      }).toList();

      String nameFromRow(Map<String, dynamic>? row) {
        if (row == null) return 'Unknown';
        final fn = (row['first_name'] ?? row['firstName'] ?? '')
            .toString()
            .trim();
        final ln = (row['last_name'] ?? row['lastName'] ?? '')
            .toString()
            .trim();
        if (fn.isEmpty && ln.isEmpty) return 'Unknown';
        if (ln.isEmpty) return fn;
        if (fn.isEmpty) return ln;
        return '$fn $ln';
      }

      final blockedContacts = blockedIds.map((id) {
        final matching = contactByAppUserId[id];
        final row = blockedRowById[id];

        final displayName = (matching?.preferredDisplayName ?? '').trim();
        final fallbackName = nameFromRow(row);
        final phone = matching?.mobileNo ?? '';
        final profilePic =
            (matching?.userDetails?.chatPictureUrl ?? '').trim().isNotEmpty
            ? (matching!.userDetails!.chatPictureUrl ?? '')
            : (row?['chat_picture'] ?? row?['chatPicture'] ?? '').toString();

        return BlockedContactUiModel(
          userId: id,
          name: displayName.isNotEmpty ? displayName : fallbackName,
          mobile: phone,
          chatPictureUrl: profilePic.trim().isEmpty ? null : profilePic,
        );
      }).toList();

      _safeSetState(
        state.copyWith(
          loadingState: BlockedContactsLoadingState.loaded,
          blockedContacts: blockedContacts,
          availableContacts: availableContacts,
          errorMessage: null,
        ),
      );
    } catch (e) {
      _safeSetState(
        state.copyWith(
          loadingState: BlockedContactsLoadingState.error,
          errorMessage: 'Failed to load blocked contacts (local)',
        ),
      );
    }
  }

  /// Fetch snapshot from server and sync to local, then rebuild local state
  Future<void> refreshFromServer() async {
    try {
      await _repository.fetchBlockedUsersAndSync();
      await loadLocal();
    } catch (_) {
      // Keep existing UI; errors handled in loadLocal if needed
    }
  }

  /// Initialize: load local; if empty, take snapshot from server and sync once
  Future<void> initialize() async {
    await loadLocal();
  }

  Future<BlockActionResult> blockUser(String appUserId) async {
    final result = await _repository.blockUser(appUserId);
    if (result.isSuccess) {
      await refreshFromServer();
    }
    return result;
  }

  Future<BlockActionResult> unblockUser(String userId) async {
    final result = await _repository.unblockUser(userId);
    if (result.isSuccess) {
      await refreshFromServer();
    }
    return result;
  }
}
