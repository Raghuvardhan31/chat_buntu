import 'package:flutter/foundation.dart';

class FollowUpStore extends ChangeNotifier {
  FollowUpStore._();

  static final FollowUpStore instance = FollowUpStore._();

  final Map<String, List<String>> _followUpsByContact = {};

  List<String> getFollowUps(String contactId) {
    final key = contactId.trim();
    if (key.isEmpty) return const [];
    return List.unmodifiable(_followUpsByContact[key] ?? const []);
  }

  void addFollowUp({required String contactId, required String text}) {
    final key = contactId.trim();
    final trimmed = text.trim();
    if (key.isEmpty || trimmed.isEmpty) return;

    final entries = _followUpsByContact.putIfAbsent(key, () => <String>[]);
    entries.insert(0, trimmed);
    notifyListeners();
  }
}
