import 'package:flutter_test/flutter_test.dart';
import 'package:centavus_flutter/domain/finance.dart';

void main() {
  test('projeção com taxa zero e capitalização sem duplicação', () {
    expect(projection(10000, 1000, 12, 0), 22000);
    final r = {
      'id': 'main',
      'balance': 10000,
      'annual': 12.0,
      'monthly': 0,
      'lastYieldAt': '2026-01-31',
      'history': <dynamic>[],
    };
    final first = accrueReserve(r, DateTime(2026, 3, 31));
    expect(first['balance'], greaterThan(10000));
    expect((first['history'] as List).length, 2);
    expect(
      accrueReserve(first, DateTime(2026, 3, 31))['balance'],
      first['balance'],
    );
  });
}
