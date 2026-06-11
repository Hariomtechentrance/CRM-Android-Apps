import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // TOKENS ONLY — secure storage is kept only for access/refresh tokens.
  // Using it for userData/orgId caused ANR on startup because EncryptedSharedPreferences
  // initializes its Keystore key on the Android main thread, blocking the UI for
  // several seconds before the login screen could even render.
  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Non-sensitive data — fast, never touches the Keystore on startup.
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ── Tokens (secure) ───────────────────────────────────────────
  Future<void> saveTokens({required String accessToken, required String refreshToken}) =>
      Future.wait([
        _secure.write(key: AppConstants.kAccessToken,  value: accessToken),
        _secure.write(key: AppConstants.kRefreshToken, value: refreshToken),
      ]);

  Future<String?> getAccessToken()  => _secure.read(key: AppConstants.kAccessToken);
  Future<String?> getRefreshToken() => _secure.read(key: AppConstants.kRefreshToken);

  // ── Org ID (non-sensitive) ────────────────────────────────────
  Future<void> saveActiveOrgId(String orgId) async =>
      (await _prefs).setString(AppConstants.kActiveOrgId, orgId);

  Future<String?> getActiveOrgId() async =>
      (await _prefs).getString(AppConstants.kActiveOrgId);

  // ── User data (non-sensitive JSON) ────────────────────────────
  Future<void> saveUserData(String json) async =>
      (await _prefs).setString(AppConstants.kUserData, json);

  Future<String?> getUserData() async =>
      (await _prefs).getString(AppConstants.kUserData);

  // ── Selective clear ───────────────────────────────────────────
  // Use on session expiry: clears tokens only, preserves cached org/user data so
  // re-login can restore hasOrg even when the login response omits organizations.
  Future<void> clearTokens() => _secure.deleteAll();

  // Use when stored user JSON is corrupt: clears user cache only, keeps org ID
  // and tokens so a re-parse after login still gets hasOrg right.
  Future<void> clearUserData() async =>
      (await _prefs).remove(AppConstants.kUserData);

  // ── Clear all (logout) ────────────────────────────────────────
  Future<void> clearAll() => Future.wait([
    _secure.deleteAll(),
    _prefs.then((p) => p.clear()),
  ]);
}
