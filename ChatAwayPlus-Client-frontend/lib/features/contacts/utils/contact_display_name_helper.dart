import 'package:chataway_plus/features/contacts/data/models/contact_local.dart';

/// Helper for resolving display names consistently across the app.
///
/// Rules:
/// - Always prefer the device's saved contact name (`ContactLocal.name`).
/// - If no contact is found, fall back to a backend/app display name when available.
/// - Only as a last resort, use a generic label (e.g. "ChatAway user").
class ContactDisplayNameHelper {
  const ContactDisplayNameHelper._();

  /// Normalize a phone number to its last 10 digits, stripping non-digits.
  static String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Find a matching contact by app user ID or, if that fails, by phone number.
  static ContactLocal? findByUserIdOrPhone({
    required List<ContactLocal> contacts,
    required String userId,
    required String mobileNo,
  }) {
    // 1) Try match by backend app user id
    for (final c in contacts) {
      if (c.userDetails?.userId == userId || c.appUserId == userId) {
        return c;
      }
    }

    // 2) If still not found, try by phone number (normalize to last 10 digits)
    if (mobileNo.isEmpty) return null;
    final target = _normalizePhone(mobileNo);
    if (target.isEmpty) return null;

    for (final c in contacts) {
      final candidate = _normalizePhone(c.mobileNo);
      if (candidate.isNotEmpty && candidate == target) {
        return c;
      }
    }

    return null;
  }

  /// Resolve a user-facing display name.
  ///
  /// - Uses the device contact name if we can find a match.
  /// - Otherwise, uses [backendDisplayName] when it's non-empty.
  /// - Otherwise, falls back to [fallbackLabel].
  static String resolveDisplayName({
    required List<ContactLocal> contacts,
    required String userId,
    required String mobileNo,
    String? backendDisplayName,
    String fallbackLabel = 'ChatAway user',
  }) {
    final match = findByUserIdOrPhone(
      contacts: contacts,
      userId: userId,
      mobileNo: mobileNo,
    );

    if (match != null) {
      final phoneName = match.name.trim();
      if (phoneName.isNotEmpty) {
        return phoneName;
      }

      final appName = match.userDetails?.appdisplayName.trim() ?? '';
      if (appName.isNotEmpty &&
          appName.toLowerCase() != fallbackLabel.toLowerCase()) {
        return appName;
      }
    }

    final backend = backendDisplayName?.trim() ?? '';
    if (backend.isNotEmpty &&
        backend.toLowerCase() != fallbackLabel.toLowerCase()) {
      return backend;
    }

    return fallbackLabel;
  }
}
