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

  void clearError() => state = state.copyWith(clearError: true); // Task 1.8

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    final session = await ref.read(authRepositoryProvider).restoreSession();
    if (session == null) {
      state = const AuthState(isLoading: false);
      return;
    }
    await _hydrateAfterAuth(session.user, emitLoading: false);
  }

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
      final msg = friendlyError(e); // Task 4.2
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }

  Future<String?> _hydrateAfterAuth(User user,
      {required bool emitLoading}) async {
    if (emitLoading) state = state.copyWith(isLoading: true);

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

    if (user.branchId != null) {
      try {
        final preFill =
            await ref.read(shiftApiProvider).current(user.branchId!);
        final openShift = preFill.openShift;

        if (openShift != null &&
            openShift.isOpen &&
            openShift.tellerId != user.id) {
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

        if (openShift != null) {
          await ref
              .read(storageServiceProvider)
              .saveShift(user.branchId!, openShift.toJson());
        }
      } catch (_) {
        // Network error during shift check — allow login
      }
    }

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

  // Task 1.7: Await logout
  Future<void> _forceLogout({required SessionExpiry expiry}) async {
    await ref.read(authRepositoryProvider).logout();
    state = AuthState(isLoading: false, sessionExpiry: expiry);
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
