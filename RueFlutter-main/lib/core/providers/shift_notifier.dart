import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/inventory.dart';
import '../models/pending_action.dart';
import '../models/shift.dart';
import '../repositories/shift_repository.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue.dart';
import '../storage/storage_service.dart';

class ShiftState {
  final bool               isLoading;
  final Shift?             shift;
  final int                suggestedOpeningCash;
  final List<InventoryItem> inventory;
  final int                systemCash;
  final bool               systemCashLoading;
  final String?            error;
  final bool               fromCache;
  /// True if the current shift was opened offline and not yet synced.
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
      // Try cache
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

  /// Open shift. Works offline — generates local UUID and queues.
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
        state = state.copyWith(isLoading: false, error: _friendly(e));
        return false;
      }
    }

    // ── OFFLINE ──────────────────────────────────────────────
    final shiftId  = const Uuid().v4();
    final now      = DateTime.now();
    final localShift = Shift(
      id:           shiftId,
      branchId:     branchId,
      tellerId:     '',        // filled on sync
      tellerName:   '',
      status:       'open',
      openingCash:  openingCash,
      openedAt:     now,
    );

    // Persist locally so the app continues to work
    await ref.read(storageServiceProvider)
        .saveShift(branchId, localShift.toJson());

    // Enqueue for sync
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

  /// Close shift. Works offline — queues the close payload.
  Future<bool> closeShift({
    required String branchId,
    required int    closingCash,
    String?         note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    if (state.shift == null) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    final isOnline = ConnectivityService.instance.isOnline;
    final shiftId  = state.shift!.id;
    final now      = DateTime.now();

    if (isOnline) {
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
        state = state.copyWith(isLoading: false, error: _friendly(e));
        return false;
      }
    }

    // ── OFFLINE ──────────────────────────────────────────────
    await ref.read(offlineQueueProvider.notifier).enqueueShiftClose(
      PendingShiftClose(
        localId:         const Uuid().v4(),
        createdAt:       now,
        branchId:        branchId,
        shiftId:         shiftId,
        closingCash:     closingCash,
        cashNote:        note,
        inventoryCounts: inventoryCounts,
        closedAt:        now,
      ),
    );

    // Mark shift as closed locally
    await ref.read(storageServiceProvider).removeShift(branchId);
    state = state.copyWith(
        isLoading: false, clearShift: true, systemCash: 0);
    return true;
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
