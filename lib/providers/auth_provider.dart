import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/app_mode_service.dart';
import '../services/auth_service.dart';

/// `local` = running without an account; all data stays on this device.
enum AuthStatus { authenticated, unauthenticated, initial, local }

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final Map<String, dynamic>? user;

  AuthState({
    this.status = AuthStatus.initial,
    this.isLoading = false,
    this.user,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    Map<String, dynamic>? user,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends ChangeNotifier {
  final AuthService _authService;
  AuthState _state = AuthState();

  AuthState get state => _state;

  StreamSubscription<void>? _expirySub;

  AuthNotifier(this._authService) {
    // Any request can discover the refresh token was rejected; that (and
    // only that) ends the session. Expired access tokens renew silently.
    _expirySub = ApiService.onSessionExpired.listen((_) => _endSession());
    checkAuthStatus();
  }

  @override
  void dispose() {
    _expirySub?.cancel();
    super.dispose();
  }

  Future<void> _endSession() async {
    if (_state.status != AuthStatus.authenticated) return;
    await _authService.logout();
    _state = AuthState(status: AuthStatus.unauthenticated);
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final modeService = AppModeService();
    var mode = await modeService.load();
    final token = await _authService.getAccessToken();

    // Installs from before modes existed: a saved token means server mode.
    if (mode == null && token != null) {
      await modeService.setMode(AppMode.server);
      mode = AppMode.server;
    }

    if (mode == AppMode.local) {
      _state = AuthState(status: AuthStatus.local);
    } else if (mode == AppMode.server && token != null) {
      // Start from the cached profile so the app opens offline, then check
      // the token in the background.
      final cached = await _authService.getCachedProfile();
      _state = AuthState(status: AuthStatus.authenticated, user: cached);
      notifyListeners();
      await _validateSession();
      return;
    } else {
      _state = AuthState(status: AuthStatus.unauthenticated);
    }
    notifyListeners();
  }

  /// Only a server that explicitly rejects the token ends the session;
  /// being offline or the server being down never logs the user out.
  Future<void> _validateSession() async {
    final result = await _authService.fetchProfile();
    if (result.unauthorized) {
      await _authService.logout();
      _state = AuthState(status: AuthStatus.unauthenticated);
    } else if (result.profile != null) {
      _state = _state.copyWith(user: result.profile);
    }
    notifyListeners();
  }

  /// Use the app without an account; nothing is sent to any server.
  Future<void> useLocalMode() async {
    await AppModeService().setMode(AppMode.local);
    await _authService.logout();
    _state = AuthState(status: AuthStatus.local);
    notifyListeners();
  }

  /// Returns null on success, otherwise a message for the user.
  Future<String?> login(String username, String password) =>
      _signIn(() => _authService.login(username, password));

  /// Returns null on success, otherwise a message for the user.
  Future<String?> register(String username, String password, String email) =>
      _signIn(() => _authService.register(username, password, email));

  Future<String?> _signIn(Future<String?> Function() attempt) async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    final error = await attempt();
    if (error == null) {
      final user = await _authService.getUserProfile();
      _state = _state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
      );
    } else {
      // Keep the previous status: a failed attempt from local mode must
      // not kick the user out of the data they were already using.
      _state = _state.copyWith(isLoading: false);
    }
    notifyListeners();
    return error;
  }

  Future<void> logout() async {
    await _authService.logout();
    _state = _state.copyWith(status: AuthStatus.unauthenticated, user: null);
    notifyListeners();
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
