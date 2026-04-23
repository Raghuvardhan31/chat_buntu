part of '../chat_engine_service.dart';

mixin ChatEngineUnreadOverrideMixin {
  Future<void> _addClearedUnreadOverride(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing =
          prefs.getStringList(
            ChatEngineService._clearedUnreadOverridesPrefsKey,
          ) ??
          <String>[];
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = <String>[];
      var replaced = false;
      for (final e in existing) {
        if (e == userId || e.startsWith('$userId:')) {
          updated.add('$userId:$now');
          replaced = true;
        } else {
          updated.add(e);
        }
      }
      if (!replaced) {
        updated.add('$userId:$now');
      }
      await prefs.setStringList(
        ChatEngineService._clearedUnreadOverridesPrefsKey,
        updated,
      );
    } catch (_) {
      // ignore
    }
  }

  // ignore: unused_element
  Future<void> _removeClearedUnreadOverride(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing =
          prefs.getStringList(
            ChatEngineService._clearedUnreadOverridesPrefsKey,
          ) ??
          <String>[];
      if (existing.isEmpty) return;
      await prefs.setStringList(
        ChatEngineService._clearedUnreadOverridesPrefsKey,
        existing
            .where((e) => !(e == userId || e.startsWith('$userId:')))
            .toList(),
      );
    } catch (_) {
      // ignore
    }
  }
}
