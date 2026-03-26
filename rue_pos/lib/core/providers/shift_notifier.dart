import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory.dart';
import '../models/shift.dart';
import '../repositories/shift_repository.dart';

class ShiftState {
  final bool             isLoading;
  final Shift?           shift;
  final int              suggestedOpeningCash;
  final List<InventoryItem> inventory;
  final int              systemCash;
  final bool             systemCashLoading;
  final String?          error;
  final bool             fromCache;

  const ShiftState({
    this.isLoading            = false,
    this.shift,
    this.suggestedOpeningCash = 0,
    this.inventory            = const [],
    this.systemCash           = 0,
    this.systemCashLoading    = false,
    this.error,
    this.fromCache            = false,
  });

  bool get hasOpenShift => shift?.isOpen ?? false;

  ShiftState copyWith({
    bool?              isLoading,
    Shift?             shift,
    int?               suggestedOpeningCash,
    List<InventoryItem>? inventory,
    int?               systemCash,
    bool?              systemCashLoading,
    String?            error,
    bool?              fromCache,
    bool               clearShift = false,
    bool               clearError = false,
  }) => ShiftState(
    isLoading:            isLoading            ?? this.isLoading,
    shift:                clearShift ? null     : (shift ?? this.shift),
    suggestedOpeningCash: suggestedOpeningCash ?? this.suggestedOpeningCash,
    inventory:            inventory            ?? this.inventory,
    systemCash:           systemCash           ?? this.systemCash,
    systemCashLoading:    systemCashLoading    ?? this.systemCashLoading,
    error:                clearError ? null     : (error ?? this.error),
    fromCache:            fromCache            ?? this.fromCache,
  );
}

class ShiftNotifier extends Notifier<ShiftState> {
  @override
  ShiftState build() => const ShiftState();

  Future<void> load(String branchId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final preFill = await ref.read(shiftRepositoryProvider).currentShift(branchId);
      state = state.copyWith(
        isLoading:            false,
        shift:                preFill.openShift,
        suggestedOpeningCash: preFill.suggestedOpeningCash,
        fromCache:            false,
        clearShift:           preFill.openShift == null,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, fromCache: true,
          error: 'Could not load shift — check connection');
    }
  }

  Future<bool> openShift(String branchId, int openingCash) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final shift = await ref.read(shiftRepositoryProvider)
          .openShift(branchId, openingCash);
      state = state.copyWith(isLoading: false, shift: shift);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
      return false;
    }
  }

  /// Close shift. On success clears the shift and returns true.
  /// Returns false + sets error on failure.
  Future<bool> closeShift({
    required String branchId,
    required int    closingCash,
    String?         note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    if (state.shift == null) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(shiftRepositoryProvider).closeShift(
        state.shift!.id,
        branchId:        branchId,
        closingCash:     closingCash,
        note:            note,
        inventoryCounts: inventoryCounts,
      );
      state = state.copyWith(
          isLoading: false, clearShift: true, systemCash: 0);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
      return false;
    }
  }

  Future<void> loadSystemCash() async {
    final shift = state.shift;
    if (shift == null) return;
    state = state.copyWith(systemCashLoading: true);
    try {
      final cash = await ref.read(shiftRepositoryProvider)
          .getSystemCash(shift.id, shift.openingCash);
      state = state.copyWith(systemCash: cash, systemCashLoading: false);
    } catch (_) {
      state = state.copyWith(systemCashLoading: false);
    }
  }

  Future<void> loadInventory(String branchId) async {
    final items = await ref.read(shiftRepositoryProvider).getInventory(branchId);
    state = state.copyWith(inventory: items);
  }

  void onShiftClosed() {
    state = state.copyWith(clearShift: true, systemCash: 0);
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('409')) return 'A shift is already open for this branch';
    if (s.contains('404')) return 'Shift not found';
    if (s.contains('401')) return 'Session expired — please sign in again';
    return 'Something went wrong — please try again';
  }
}

final shiftProvider =
    NotifierProvider<ShiftNotifier, ShiftState>(ShiftNotifier.new);
