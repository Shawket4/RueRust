import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/branch_api.dart';
import '../api/client.dart';
import '../api/shift_api.dart';
import '../models/branch.dart';
import '../models/shift.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../storage/storage_service.dart';

enum SessionExpiry { none, expired, blockedByOtherShift }

class AuthState {
  final bool isLoading;
  final User? user;
  final Branch? branch;
  final String? error;
  final SessionExpiry sessionExpiry;
  final String? blockedByName;

  const AuthState({
    this.isLoading = true,
    this.user,
    this.branch,
    this.error,
    this.sessionExpiry = SessionExpiry.none,
    this.blockedByName,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    User? user,
    Branch? branch,
    String? error,
    SessionExpiry? sessionExpiry,
    String? blockedByName,
    bool clearUser = false,
    bool clearBranch = false,
    bool clearError = false,
    bool clearBlocked = false,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        user: clearUser ? null : (user ?? this.user),
        branch: clearBranch ? null : (branch ?? this.branch),
        error: clearError ? null : (error ?? this.error),
        sessionExpiry: sessionExpiry ?? this.sessionExpiry,
        blockedByName:
            clearBlocked ? null : (blockedByName ?? this.blockedByName),
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    onUnauthorizedCallback = () {
      if (state.user != null) {
        _forceLogout(expiry: SessionExpiry.expired);
      }
    };
    Future.microtask(init);
    return const AuthState();
  }

  // ── Startup restore ────────────────────────────────────────────────────────
  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    final session = await ref.read(authRepositoryProvider).restoreSession();
    if (session == null) {
      state = const AuthState(isLoading: false);
      return;
    }
    await _hydrateAfterAuth(session.user, emitLoading: false);
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<String?> login({required String name, required String pin}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearBlocked: true,
      sessionExpiry: SessionExpiry.none,
    );
    try {
      final session =
          await ref.read(authRepositoryProvider).login(name: name, pin: pin);
      final blockError =
          await _hydrateAfterAuth(session.user, emitLoading: true);
      return blockError;
    } catch (e) {
      final msg = _friendly(e);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }

  // ── Post-auth hydration + shift guard ─────────────────────────────────────
  Future<String?> _hydrateAfterAuth(User user,
      {required bool emitLoading}) async {
    if (emitLoading) state = state.copyWith(isLoading: true);

    // 1. Load branch
    Branch? branch;
    if (user.branchId != null) {
      try {
        branch = await ref.read(branchApiProvider).get(user.branchId!);
        await ref
            .read(storageServiceProvider)
            .saveBranch(user.branchId!, branch.toJson());
      } catch (_) {
        final cached =
            ref.read(storageServiceProvider).loadBranch(user.branchId!);
        if (cached != null) branch = Branch.fromJson(cached);
      }
    }

    // 2. Shift ownership guard
    if (user.branchId != null) {
      try {
        final preFill =
            await ref.read(shiftApiProvider).current(user.branchId!);
        final openShift = preFill.openShift;

        if (openShift != null &&
            openShift.isOpen &&
            openShift.tellerId != user.id) {
          // Another teller's shift is open — block login
          await ref.read(authRepositoryProvider).logout();
          final msg = 'Branch has an open shift belonging to '
              '"${openShift.tellerName}". '
              'That shift must be closed before anyone else can sign in.';
          state = AuthState(
            isLoading: false,
            sessionExpiry: SessionExpiry.blockedByOtherShift,
            blockedByName: openShift.tellerName,
            error: msg,
          );
          return msg;
        }

        // Cache the open shift if it belongs to this user
        if (openShift != null) {
          await ref
              .read(storageServiceProvider)
              .saveShift(user.branchId!, openShift.toJson());
        }
      } catch (_) {
        // Network error during shift check — allow login
      }
    }

    // 3. All good — set authenticated state
    state = state.copyWith(
      isLoading: false,
      user: user,
      branch: branch,
      clearError: true,
      clearBlocked: true,
      sessionExpiry: SessionExpiry.none,
    );
    return null;
  }

  // ── Logout guard ───────────────────────────────────────────────────────────
  Future<bool> canLogout() async {
    final branchId = state.user?.branchId;
    if (branchId == null) return true;
    try {
      final preFill = await ref.read(shiftApiProvider).current(branchId);
      return !(preFill.openShift?.isOpen ?? false);
    } catch (_) {
      final cached = ref.read(storageServiceProvider).loadShift(branchId);
      if (cached != null) {
        final shift = Shift.fromJson(cached);
        return !shift.isOpen;
      }
      return true;
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState(isLoading: false);
  }

  void _forceLogout({required SessionExpiry expiry}) {
    ref.read(authRepositoryProvider).logout();
    state = AuthState(isLoading: false, sessionExpiry: expiry);
  }

  String _friendly(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('401') || s.contains('invalid')) {
      return 'Invalid name or PIN — please try again';
    }
    if (s.contains('network') || s.contains('connection')) {
      return 'No internet connection';
    }
    return 'Something went wrong — please try again';
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
