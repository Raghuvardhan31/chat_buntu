import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdService {
  static final DeviceIdService _instance = DeviceIdService._internal();

  factory DeviceIdService() => _instance;

  DeviceIdService._internal();

  static DeviceIdService get instance => _instance;

  static const String _deviceIdKey = 'device_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'device_id_storage',
      preferencesKeyPrefix: 'device_',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: true,
    ),
    webOptions: WebOptions(publicKey: 'device_id_storage'),
  );

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final created = _generate();
    await _storage.write(key: _deviceIdKey, value: created);
    return created;
  }

  String _generate() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
