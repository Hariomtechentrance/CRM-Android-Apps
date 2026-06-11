import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user.dart';
import '../../data/services/api_client.dart';
import '../../data/services/storage_service.dart';

// ── Auth state ────────────────────────────────────────────────
class AuthState {
  final AppUser? user;
  final bool isAuthenticated;
  final bool hasOrg;
  final String? error;

  const AuthState({this.user, this.isAuthenticated = false, this.hasOrg = false, this.error});
}

// ── Notifier ─────────────────────────────────────────────────
class AuthNotifier extends AsyncNotifier<AuthState> {
  final _api     = ApiClient();
  final _storage = StorageService();

  @override
  Future<AuthState> build() async {
    _api.init();
    _api.onSessionExpired = () {
      state = const AsyncData(AuthState(isAuthenticated: false));
    };
    try {
      // getUserData/getActiveOrgId now use SharedPreferences — fast, no Keystore,
      // no ANR risk. Tokens stay in FlutterSecureStorage but are only read later
      // by the Dio interceptor when actual API calls are made.
      final userData = await _storage.getUserData();
      if (userData == null) return const AuthState(isAuthenticated: false);

      final user  = AppUser.fromJsonString(userData);
      final orgId = await _storage.getActiveOrgId();
      // Trust cached credentials — the 401 interceptor handles session expiry.
      return AuthState(user: user, isAuthenticated: true, hasOrg: orgId != null);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401')) {
        // Expired/invalid session — full logout.
        await _storage.clearAll().catchError((_) {});
        return const AuthState(isAuthenticated: false);
      }
      if (msg.contains('FormatException') || msg.contains("type '")) {
        // Corrupt user cache — clear only user data, keep org ID and tokens so
        // re-login can still restore hasOrg without asking to re-create the org.
        await _storage.clearUserData().catchError((_) {});
        return const AuthState(isAuthenticated: false);
      }
    }
    return const AuthState(isAuthenticated: false);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final res  = await _api.login(email, password);
      final data = res.data['data'] as Map<String, dynamic>;

      if (data['requiresPhone2FA'] == true) {
        state = AsyncData(AuthState(
          isAuthenticated: false,
          error: 'Phone 2FA is required but not yet supported in this app. Please use the web app.',
        ));
        return;
      }

      await _storage.saveTokens(
        accessToken:  data['accessToken']  as String,
        refreshToken: data['refreshToken'] as String,
      );

      final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);

      if (user.organizations.isNotEmpty) {
        await _storage.saveActiveOrgId(user.organizations.first.id);
      }
      await _storage.saveUserData(user.toJsonString());

      // If the login response didn't include organizations, fall back to the org ID
      // that was saved when the user previously created their org. This handles the
      // common case where the session expired (clearTokens was called) but the org
      // ID was preserved in SharedPreferences.
      final savedOrgId = await _storage.getActiveOrgId();
      final hasOrg = user.organizations.isNotEmpty || savedOrgId != null;
      state = AsyncData(AuthState(user: user, isAuthenticated: true, hasOrg: hasOrg));
    } catch (e) {
      String msg = 'Login failed. Please try again.';
      final s = e.toString();
      if (s.contains('401')) msg = 'Invalid email or password.';
      if (s.contains('Connection') || s.contains('network')) msg = 'Cannot reach server. Check your connection.';
      state = AsyncData(AuthState(isAuthenticated: false, error: msg));
    }
  }

  Future<void> logout() async {
    try { await _api.logout(); } catch (_) {}
    await _storage.clearAll();
    state = const AsyncData(AuthState(isAuthenticated: false));
  }

  Future<void> refreshSession() async {
    // Do NOT set AsyncLoading here — it triggers the router's /splash redirect
    // while inner screens are still mounted, causing _dependents.isEmpty crashes.
    state = AsyncData(await build());
  }

  Future<void> updateLocalProfile({String? name, String? phone, String? avatar}) async {
    final current = state.valueOrNull;
    if (current?.user == null) return;
    final u = current!.user!;
    final updated = AppUser(
      id: u.id, name: name ?? u.name, email: u.email,
      phone: phone, avatar: avatar ?? u.avatar,
      isSuperAdmin: u.isSuperAdmin,
      organizations: u.organizations, activeOrgId: u.activeOrgId,
    );
    await _storage.saveUserData(updated.toJsonString());
    state = AsyncData(AuthState(user: updated, isAuthenticated: true, hasOrg: current.hasOrg));
  }

  Future<void> markOrgCreated(Organization newOrg) async {
    final current = state.valueOrNull;
    if (current?.user == null) return;
    final updatedUser = AppUser(
      id:            current!.user!.id,
      name:          current.user!.name,
      email:         current.user!.email,
      phone:         current.user!.phone,
      avatar:        current.user!.avatar,
      isSuperAdmin:  current.user!.isSuperAdmin,
      organizations: [newOrg, ...current.user!.organizations],
      activeOrgId:   newOrg.id,
    );
    // Persist both the updated user (with org in list) and the active org ID so
    // the next cold start reads hasOrg = true without hitting the API.
    await Future.wait([
      _storage.saveUserData(updatedUser.toJsonString()),
      _storage.saveActiveOrgId(newOrg.id),
    ]);
    state = AsyncData(AuthState(
      user: updatedUser,
      isAuthenticated: true,
      hasOrg: true,
    ));
  }

  Future<void> switchOrg(String orgId) async {
    await _storage.saveActiveOrgId(orgId);
    final current = state.valueOrNull;
    if (current?.user != null) {
      final updated = AppUser(
        id:            current!.user!.id,
        name:          current.user!.name,
        email:         current.user!.email,
        avatar:        current.user!.avatar,
        isSuperAdmin:  current.user!.isSuperAdmin,
        organizations: current.user!.organizations,
        activeOrgId:   orgId,
      );
      await _storage.saveUserData(updated.toJsonString());
      state = AsyncData(AuthState(user: updated, isAuthenticated: true, hasOrg: true));
    }
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
