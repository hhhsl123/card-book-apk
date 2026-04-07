import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/data.dart';
import '../services/sync.dart';
import '../services/storage.dart';

class AppProvider extends ChangeNotifier {
  AppData data = AppData();
  String? myRole;
  bool syncing = false;
  String syncStatus = '';
  String? syncMessage;
  Timer? _autoSyncTimer;

  static int _idCounter = 0;
  static final _rng = Random();

  String _uniqueId() {
    _idCounter++;
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_${_idCounter.toRadixString(36)}_${_rng.nextInt(0xFFFF).toRadixString(36)}';
  }

  bool _repairDuplicateIds() {
    bool changed = false;
    for (final batch in data.batches) {
      final seen = <String>{};
      for (final card in batch.cards) {
        if (!seen.add(card.id)) {
          card.id = _uniqueId();
          card.updatedAt = DateTime.now().millisecondsSinceEpoch;
          changed = true;
        }
      }
    }
    return changed;
  }

  Future<void> init() async {
    data = await StorageService.loadData();
    myRole = await StorageService.getRole();
    _repairDuplicateIds();
    await StorageService.saveData(data);
    notifyListeners();

    // Pull cloud data, repair if needed, then overwrite cloud with clean data
    syncing = true;
    syncStatus = '同步中...';
    notifyListeners();
    final remote = await SyncService.pull();
    if (remote != null) {
      data = remote;
      if (_repairDuplicateIds()) {
        await SyncService.overwrite(data);
      }
      await StorageService.saveData(data);
      syncStatus = '已同步';
      syncMessage = '同步成功';
    } else {
      syncStatus = '同步失败';
    }
    syncing = false;
    notifyListeners();

    _startAutoSync();
  }

  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!syncing) _silentPull();
    });
  }

  Future<void> _silentPull() async {
    try {
      final remote = await SyncService.pull();
      if (remote != null) {
        data = remote;
        if (_repairDuplicateIds()) {
          await SyncService.overwrite(data);
        }
        await StorageService.saveData(data);
        syncStatus = '已同步';
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  // ---- Role ----
  Future<void> setRole(String role) async {
    myRole = role;
    await StorageService.setRole(role);
    notifyListeners();
  }

  // ---- Sync ----
  Future<void> pullFromCloud() async {
    syncing = true;
    syncStatus = '同步中...';
    notifyListeners();
    final remote = await SyncService.pull();
    if (remote != null) {
      data = remote;
      if (_repairDuplicateIds()) {
        await SyncService.overwrite(data);
      }
      await StorageService.saveData(data);
      syncStatus = '已同步';
      syncMessage = '同步成功';
    } else {
      syncStatus = '同步失败';
      syncMessage = '同步失败';
    }
    syncing = false;
    notifyListeners();
  }

  Future<void> _save() async {
    _repairDuplicateIds();
    await StorageService.saveData(data);
    notifyListeners();

    syncing = true;
    syncStatus = '同步中...';
    notifyListeners();
    final merged = await SyncService.merge(data);
    if (merged != null) {
      data = merged;
      if (_repairDuplicateIds()) {
        await SyncService.overwrite(data);
      }
      await StorageService.saveData(data);
      syncStatus = '已同步';
      syncMessage = '同步成功';
    } else {
      syncStatus = '同步失败';
      syncMessage = '同步失败';
    }
    syncing = false;
    notifyListeners();
  }

  /// Clear the one-time sync message after it's been shown
  void clearSyncMessage() {
    syncMessage = null;
  }

  // ---- Persons ----
  Future<void> addPerson(String name) async {
    if (!data.persons.contains(name)) {
      data.persons.add(name);
      await _save();
    }
  }

  Future<void> removePerson(String name) async {
    data.persons.remove(name);
    await _save();
  }

  // ---- Batches ----
  Future<void> addBatch(Batch batch) async {
    data.batches.add(batch);
    await _save();
  }

  Future<void> deleteBatch(String batchId) async {
    data.batches.removeWhere((b) => b.id == batchId);
    if (!data.deletedBatchIds.contains(batchId)) {
      data.deletedBatchIds.add(batchId);
    }
    await _save();
  }

  // ---- Cards ----
  Future<void> sellCards(String batchId, Set<String> cardIds, String seller) async {
    final batch = data.batches.firstWhere((b) => b.id == batchId);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final c in batch.cards) {
      if (cardIds.contains(c.id)) {
        c.sold = true;
        c.soldBy = seller;
        c.soldPrice = c.face;
        c.soldDate = now;
        c.updatedAt = now;
      }
    }
    await _save();
  }

  Future<void> markBad(String batchId, Set<String> cardIds) async {
    final batch = data.batches.firstWhere((b) => b.id == batchId);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final c in batch.cards) {
      if (cardIds.contains(c.id)) {
        c.bad = true;
        c.updatedAt = now;
      }
    }
    await _save();
  }

  Future<void> deleteCard(String batchId, String cardId) async {
    final batch = data.batches.firstWhere((b) => b.id == batchId);
    batch.cards.removeWhere((c) => c.id == cardId);
    if (!data.deletedCardIds.contains(cardId)) {
      data.deletedCardIds.add(cardId);
    }
    await _save();
  }

  Future<void> deleteCards(String batchId, Set<String> cardIds) async {
    final batch = data.batches.firstWhere((b) => b.id == batchId);
    batch.cards.removeWhere((c) => cardIds.contains(c.id));
    for (final id in cardIds) {
      if (!data.deletedCardIds.contains(id)) {
        data.deletedCardIds.add(id);
      }
    }
    await _save();
  }

  Future<void> undoCards(String batchId, Set<String> cardIds) async {
    final batch = data.batches.firstWhere((b) => b.id == batchId);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final c in batch.cards) {
      if (cardIds.contains(c.id)) {
        c.sold = false;
        c.bad = false;
        c.soldBy = null;
        c.soldPrice = 0;
        c.soldDate = null;
        c.soldNote = '';
        c.updatedAt = now;
      }
    }
    await _save();
  }

  Future<void> pickCards(String batchId, List<CardItem> cards) async {
    final seller = myRole ?? '未知';
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = data.batches.firstWhere((b) => b.id == batchId);
    for (final c in batch.cards) {
      if (cards.any((pc) => pc.id == c.id)) {
        c.sold = true;
        c.soldBy = seller;
        c.soldPrice = c.face;
        c.soldDate = now;
        c.updatedAt = now;
      }
    }
    await _save();
  }
}
