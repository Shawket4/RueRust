import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../api/client.dart';
import '../models/inventory.dart';
import '../models/pending_action.dart';
import '../models/shift.dart';
import '../repositories/shift_repository.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue.dart';
import '../storage/storage_service.dart';
import 'auth_notifier.dart';

class ShiftState {
  final bool               isLoading;
  final Shift?             shift;
  final int                suggestedOpeningCash;
  final List<InventoryItem> inventory;
  final int                systemCash;
  final bool               systemCashLoading;
  final String?            error;
  final bool               fromCache;
  final bool               isLocalShift;

  const ShiftState({
    this.isLoading            = false,
    this.shift,
    this.suggestedOpeningCash = 0,
    this.inventory            = const [],
    this.systemCash           = 0,
    this.systemCashLoading    = false,
    this.error,
    this.fromCache            = false,
    this.isLocalShift         = false,
  });

  bool get hasOpenShift => shift?.isOpen ?? false;

  ShiftState copyWith({
    bool?               isLoading,
    Shift?              shift,
    int?                suggestedOpeningCash,
    List<InventoryItem>? inventory,
    int?                systemCash,
    bool?               systemCashLoading,
    String?             error,
    bool?               fromCache,
    bool?               isLocalShift,
    bool                clearShift = false,
    bool                clearError = false,
  }) => ShiftState(
    isLoading:            isLoading            ?? this.isLoading,
    shift:                clearShift ? null    : (shift ?? this.shift),
    suggestedOpeningCash: suggestedOpeningCash ?? this.suggestedOpeningCash,
    inventory:            inventory            ?? this.inventory,
    systemCash:           systemCash           ?? this.systemCash,
    systemCashLoading:    systemCashLoading    ?? this.systemCashLoading,
    error:                clearError ? null    : (error ?? this.error),
    fromCache:            fromCache            ?? this.fromCache,
    isLocalShift:         isLocalShift         ?? this.isLocalShift,
  );
}

class ShiftNotifier extends Notifier<ShiftState> {
  @override
  ShiftState build() => const ShiftState();

  Future<void> load(String branchId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final preFill = await ref.read(shiftRepositoryProvider)
          .currentShift(branchId);
      state = state.copyWith(
        isLoading:            false,
        shift:                preFill.openShift,
        suggestedOpeningCash: preFill.suggestedOpeningCash,
        fromCache:            false,
        isLocalShift:         false,
        clearShift:           preFill.openShift == null,
      );
    } catch (_) {
      final cached = ref.read(storageServiceProvider).loadShift(branchId);
      if (cached != null) {
        state = state.copyWith(
          isLoading: false, fromCache: true,
          shift: Shift.fromJson(cached),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not load shift — check connection',
        );
      }
    }
  }

  Future<bool> openShift(String branchId, int openingCash) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final isOnline = ConnectivityService.instance.isOnline;

    if (isOnline) {
      try {
        final shift = await ref.read(shiftRepositoryProvider)
            .openShift(branchId, openingCash);
        state = state.copyWith(
            isLoading: false, shift: shift, isLocalShift: false);
        return true;
      } catch (e) {
        state = state.copyWith(isLoading: false, error: friendlyError(e)); // Task 4.2
        return false;
      }
    }

    // ── OFFLINE ──────────────────────────────────────────────
    // Task 1.3: Stamp offline shifts
    final user = ref.read(authProvider).user;
    if (user == null) {
      state = state.copyWith(isLoading: false, error: 'User not authenticated');
      return false;
    }

    final shiftId  = const Uuid().v4();
    final now      = DateTime.now();
    final localShift = Shift(
      id:           shiftId,
      branchId:     branchId,
      tellerId:     user.id,
      tellerName:   user.name,
      status:       'open',
      openingCash:  openingCash,
      openedAt:     now,
    );

    await ref.read(storageServiceProvider)
        .saveShift(branchId, localShift.toJson());

    await ref.read(offlineQueueProvider.notifier).enqueueShiftOpen(
      PendingShiftOpen(
        localId:     const Uuid().v4(),
        createdAt:   now,
        branchId:    branchId,
        shiftId:     shiftId,
        openingCash: openingCash,
        openedAt:    now,
      ),
    );

    state = state.copyWith(
        isLoading: false, shift: localShift, isLocalShift: true);
    return true;
  }

  Future<bool> closeShift({
    required String branchId,
    required int    closingCash,
    String?         note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    if (state.shift == null) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    
    // Task 2.1: strictly online action
    final isOnline = ConnectivityService.instance.isOnline;
    if (!isOnline) {
      state = state.copyWith(isLoading: false, error: 'Internet required to close shift');
      return false;
    }

    final shiftId  = state.shift!.id;

    try {
      await ref.read(shiftRepositoryProvider).closeShift(
        shiftId,
        branchId:        branchId,
        closingCash:     closingCash,
        note:            note,
        inventoryCounts: inventoryCounts,
      );
      await ref.read(storageServiceProvider).removeShift(branchId);
      state = state.copyWith(
          isLoading: false, clearShift: true, systemCash: 0);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e)); // Task 4.2
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
    final items = await ref.read(shiftRepositoryProvider)
        .getInventory(branchId);
    state = state.copyWith(inventory: items);
  }
}

final shiftProvider =
    NotifierProvider<ShiftNotifier, ShiftState>(ShiftNotifier.new);
