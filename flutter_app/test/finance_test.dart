import 'package:flutter_test/flutter_test.dart';
import 'package:centavus_flutter/domain/finance.dart';

void main() {
  test('dinheiro brasileiro e entradas inválidas', () {
    expect(parseMoney('1.234,56'), 123456);
    expect(parseMoney('1234.56'), 123456);
    expect(() => parseMoney('12 lixo'), throwsFormatException);
    expect(() => parseMoney('NaN'), throwsFormatException);
  });
  test('parcelas conservam centavos e atravessam ano/fim de mês', () {
    final t = Movement(
      id: 'a',
      description: 'Compra',
      cents: -10000,
      date: DateTime(2026, 12, 31),
      installments: 3,
    );
    final parts = t.parts();
    expect(parts.map((e) => e.cents).toList(), [-3334, -3333, -3333]);
    expect(parts.fold<int>(0, (s, e) => s + e.cents), -10000);
    expect(parts[2].date, DateTime(2027, 2, 28));
  });
  test('resumo filtra competência e não confunde transferências', () {
    final t = Movement(
      id: 'a',
      description: 'Salário',
      cents: 500000,
      date: DateTime(2026, 11, 1),
    );
    final x = Movement(
      id: 'b',
      description: 'Compra',
      cents: -10000,
      date: DateTime(2026, 11, 2),
      installments: 2,
    );
    final s = MonthSummary.from([t, ...x.parts()], DateTime(2026, 11));
    expect(s.income, 500000);
    expect(s.expense, 5000);
  });
  test('fatura paga não gera nova despesa e antecipada sai do devido', () {
    final t = Movement(
      id: 'a',
      description: 'Compra',
      cents: -10000,
      date: DateTime(2026, 11, 2),
      installments: 2,
      cardId: 'c',
      payment: 'credito',
      advanced: [2],
    );
    expect(invoiceDue([t], 'c', DateTime(2026, 11), payments: 1000), 4000);
    expect(invoiceDue([t], 'c', DateTime(2026, 12)), 0);
  });
  test('indexação produz o mesmo resultado da baseline', () {
    final data = List.generate(
      100,
      (i) => Movement(
        id: '$i',
        description: 'Teste',
        cents: i.isEven ? 100 : -50,
        date: DateTime(2026, i % 12 + 1, 1),
      ),
    );
    final index = indexMonths(data);
    for (var m = 1; m <= 12; m++) {
      expect(
        index[monthKey(DateTime(2026, m))],
        MonthSummary.from(data, DateTime(2026, m)),
      );
    }
  });
}
