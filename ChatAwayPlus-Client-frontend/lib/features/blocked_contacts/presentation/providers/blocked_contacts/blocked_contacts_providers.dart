import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:chataway_plus/core/storage/token_storage.dart';
import 'package:chataway_plus/features/contacts/presentation/providers/shared_providers.dart';
import '../../../data/datasources/blocked_contacts_local_datasource.dart';
import '../../../data/datasources/blocked_contacts_remote_datasource.dart';
import '../../../data/repositories/blocked_contacts/blocked_contacts_repository.dart'
    as iface;
import '../../../data/repositories/blocked_contacts/blocked_contacts_repository_impl.dart';
import '../../../data/repositories/blocked_contacts/helper_repos/get_blocked_contacts_repository.dart';
import '../../../data/repositories/blocked_contacts/helper_repos/block_contact_repository.dart';
import '../../../data/repositories/blocked_contacts/helper_repos/unblock_contact_repository.dart';
import 'blocked_contacts_notifier.dart';
import 'blocked_contacts_state.dart';

final bcHttpClientProvider = Provider<http.Client>((ref) => http.Client());
final bcTokenStorageProvider = Provider<TokenSecureStorage>(
  (ref) => TokenSecureStorage.instance,
);

final blockedContactsLocalDataSourceProvider =
    Provider<BlockedContactsLocalDataSource>((ref) {
      return BlockedContactsLocalDataSourceImpl();
    });

final blockedContactsRemoteDataSourceProvider =
    Provider<BlockedContactsRemoteDataSource>((ref) {
      return BlockedContactsRemoteDataSourceImpl(
        httpClient: ref.watch(bcHttpClientProvider),
        tokenStorage: ref.watch(bcTokenStorageProvider),
      );
    });

final getBlockedContactsRepositoryProvider =
    Provider<GetBlockedContactsRepository>((ref) {
      return GetBlockedContactsRepository(
        remoteDataSource: ref.watch(blockedContactsRemoteDataSourceProvider),
        localDataSource: ref.watch(blockedContactsLocalDataSourceProvider),
      );
    });

final blockContactRepositoryProvider = Provider<BlockContactRepository>((ref) {
  return BlockContactRepository(
    remoteDataSource: ref.watch(blockedContactsRemoteDataSourceProvider),
    localDataSource: ref.watch(blockedContactsLocalDataSourceProvider),
  );
});

final unblockContactRepositoryProvider = Provider<UnblockContactRepository>((
  ref,
) {
  return UnblockContactRepository(
    remoteDataSource: ref.watch(blockedContactsRemoteDataSourceProvider),
    localDataSource: ref.watch(blockedContactsLocalDataSourceProvider),
  );
});

final blockedContactsRepositoryProvider =
    Provider<iface.BlockedContactsRepository>((ref) {
      return BlockedContactsRepositoryImpl(
        getRepo: ref.watch(getBlockedContactsRepositoryProvider),
        blockRepo: ref.watch(blockContactRepositoryProvider),
        unblockRepo: ref.watch(unblockContactRepositoryProvider),
        localDataSource: ref.watch(blockedContactsLocalDataSourceProvider),
      );
    });

final blockedContactsNotifierProvider =
    StateNotifierProvider<BlockedContactsNotifier, BlockedContactsState>((ref) {
      return BlockedContactsNotifier(
        ref.watch(blockedContactsRepositoryProvider),
        ref.watch(contactsRepositoryProvider),
      );
    });

final blockedUserIdsLocalProvider = FutureProvider<Set<String>>((ref) async {
  final userId = await TokenSecureStorage.instance.getCurrentUserIdUUID();
  if (userId == null || userId.trim().isEmpty) return <String>{};
  return ref
      .read(blockedContactsRepositoryProvider)
      .getBlockedUserIdsLocal(userId);
});

final isUserBlockedProvider = FutureProvider.family<bool, String>((
  ref,
  otherUserId,
) async {
  final ids = await ref.watch(blockedUserIdsLocalProvider.future);
  return ids.contains(otherUserId);
});
