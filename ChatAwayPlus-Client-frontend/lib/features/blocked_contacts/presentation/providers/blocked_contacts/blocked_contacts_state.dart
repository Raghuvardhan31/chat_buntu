import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';
import '../../../data/models/blocked_contacts_models.dart';

enum BlockedContactsLoadingState { initial, loading, loaded, error }

class BlockedContactsState {
  final BlockedContactsLoadingState loadingState;
  final List<BlockedContactUiModel> blockedContacts;
  final List<ContactLocal> availableContacts;
  final String? errorMessage;

  const BlockedContactsState({
    this.loadingState = BlockedContactsLoadingState.initial,
    this.blockedContacts = const [],
    this.availableContacts = const [],
    this.errorMessage,
  });

  BlockedContactsState copyWith({
    BlockedContactsLoadingState? loadingState,
    List<BlockedContactUiModel>? blockedContacts,
    List<ContactLocal>? availableContacts,
    String? errorMessage,
  }) {
    return BlockedContactsState(
      loadingState: loadingState ?? this.loadingState,
      blockedContacts: blockedContacts ?? this.blockedContacts,
      availableContacts: availableContacts ?? this.availableContacts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isLoading => loadingState == BlockedContactsLoadingState.loading;
  bool get isLoaded => loadingState == BlockedContactsLoadingState.loaded;
  bool get hasError => loadingState == BlockedContactsLoadingState.error;
}
