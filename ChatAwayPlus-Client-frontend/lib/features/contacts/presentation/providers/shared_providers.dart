import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/contacts_repository.dart';

/// Shared provider for the contacts repository
/// Used by all contact state management modules
final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository.instance;
});
