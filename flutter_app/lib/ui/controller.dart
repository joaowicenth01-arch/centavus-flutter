import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/repository.dart';
import '../domain/finance.dart';

class FinanceController extends ChangeNotifier {
  final Repository repo;
  LocalUser user;
  String? avatarData;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  MonthSummary summary = const MonthSummary(0, 0);
  int balance = 0;
  bool loading = true, more = true, loadingMore = false, hidden = false;
  String? error;
  String query = '';
  Timer? _searchTimer;
  int _generation = 0;
  bool _alive = true;
  final entities = <String, List<Map<String, dynamic>>>{};
  final balances = <String, int>{}, invoices = <String, int>{};
  Map<String, int> categories = {};
  List<Map<String, dynamic>> rows = [];
  final folds = <String, bool>{};
  FinanceController(this.repo, this.user);
  List<Map<String, dynamic>> items(String type) => entities[type] ?? [];
  Future<void> initialize() async {
    try {
      avatarData = await repo.profilePhoto(user.id);
      await repo.refreshRecurring(user.id);
      await repo.refreshReserve(user.id);
      await refresh();
    } catch (e) {
      if (_alive) {
        error = e.toString();
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> updateProfile(String name, String? photo) async {
    user = await repo.updateProfile(user, name: name, avatarBase64: photo);
    avatarData = photo;
    if (_alive) notifyListeners();
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final nextEntities = <String, List<Map<String, dynamic>>>{};
      for (final type in [
        'accounts',
        'cards',
        'goals',
        'budgets',
        'reserve',
        'investments',
        'preferences',
        'transfers',
        'payments',
      ]) {
        nextEntities[type] = await repo.entities(user.id, type);
      }
      final s = await repo.summary(user.id, month),
          b = await repo.balance(user.id, month);
      final list = await repo.movements(user.id, month, query: query),
          cat = await repo.categories(user.id, month);
      final acc = <String, int>{}, inv = <String, int>{};
      for (final a in nextEntities['accounts']!) {
        acc[a['id'].toString()] = await repo.accountBalance(
          user.id,
          a['id'].toString(),
          month: month,
        );
      }
      for (final c in nextEntities['cards']!) {
        inv[c['id'].toString()] = await repo.invoice(
          user.id,
          c['id'].toString(),
          month,
        );
      }
      if (!_alive || gen != _generation) return;
      entities
        ..clear()
        ..addAll(nextEntities);
      summary = s;
      balance = b;
      rows = list;
      categories = cat;
      balances
        ..clear()
        ..addAll(acc);
      invoices
        ..clear()
        ..addAll(inv);
      more = list.length == 50;
      final prefs = items('preferences').where((e) => e['id'] == 'panels');
      if (prefs.isNotEmpty) {
        folds
          ..clear()
          ..addAll(Map<String, bool>.from(prefs.first['values'] ?? {}));
      }
    } catch (e) {
      if (_alive && gen == _generation) error = e.toString();
    }
    if (_alive && gen == _generation) {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!more || loadingMore || loading) return;
    loadingMore = true;
    final gen = _generation;
    notifyListeners();
    try {
      final list = await repo.movements(
        user.id,
        month,
        offset: rows.length,
        query: query,
      );
      if (_alive && gen == _generation) {
        rows.addAll(list);
        more = list.length == 50;
      }
    } catch (e) {
      if (_alive) error = e.toString();
    }
    if (_alive) {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> shift(int delta) async {
    month = addMonths(month, delta);
    await refresh();
  }

  void search(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      query = value;
      refresh();
    });
  }

  Future<void> setFold(String id, bool value) async {
    final old = Map<String, bool>.from(folds);
    folds[id] = value;
    notifyListeners();
    try {
      await repo.putEntity(user.id, 'preferences', {
        'id': 'panels',
        'values': folds,
      });
    } catch (e) {
      folds
        ..clear()
        ..addAll(old);
      if (_alive) {
        error = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> allFolds(bool open) async {
    for (final id in [
      'summary',
      'month-details',
      'accounts',
      'cards',
      'transfers',
      'goals',
      'budgets',
      'reserve',
      'investments',
      'categories',
      'invoices',
    ]) {
      folds[id] = open;
    }
    await repo.putEntity(user.id, 'preferences', {
      'id': 'panels',
      'values': folds,
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _alive = false;
    super.dispose();
  }
}
