import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Session token (secure) + light prefs (onboarding / test login).
class SessionStorage {
  SessionStorage({
    FlutterSecureStorage? storage,
    SharedPreferences? prefs,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _prefs = prefs;

  final FlutterSecureStorage _storage;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String?> readToken() => _storage.read(key: kSessionTokenKey);

  Future<void> saveToken(String token) =>
      _storage.write(key: kSessionTokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: kSessionTokenKey);

  Future<bool> hasToken() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }

  /// Guest store cart. Kept until the server has merged it into the
  /// signed-in patient's cart.
  Future<String?> readCartToken() => _storage.read(key: kCartTokenKey);

  Future<void> saveCartToken(String token) =>
      _storage.write(key: kCartTokenKey, value: token);

  Future<void> clearCartToken() => _storage.delete(key: kCartTokenKey);

  Future<bool> isOnboardingDone() async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(kOnboardingDoneKey) ?? false;
  }

  Future<void> setOnboardingDone() async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(kOnboardingDoneKey, true);
  }

  /// Local-only test login (no WhatsApp / no server token).
  Future<void> saveTestSession(String phone) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(kTestSessionKey, true);
    await prefs.setString(kTestPhoneKey, phone);
  }

  Future<bool> hasTestSession() async {
    if (!kSkipWhatsAppOtp) return false;
    final prefs = await _ensurePrefs();
    return prefs.getBool(kTestSessionKey) ?? false;
  }

  Future<String?> readTestPhone() async {
    final prefs = await _ensurePrefs();
    return prefs.getString(kTestPhoneKey);
  }

  Future<void> clearTestSession() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(kTestSessionKey);
    await prefs.remove(kTestPhoneKey);
  }

  Future<void> clearAllSession() async {
    await clearToken();
    await clearCartToken();
    await clearTestSession();
  }
}
