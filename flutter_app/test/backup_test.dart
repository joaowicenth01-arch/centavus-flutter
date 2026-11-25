import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavus_flutter/data/backup.dart';

void main() {
  test('fatura legada usa o próximo vencimento e não mês da exportação', () {
    final b = decodeBackup(
      '{"app":"Centavus","version":3,"exportedAt":"2026-11-24T12:00:00Z","transactions":[],"cards":[{"id":1,"name":"Cartão","limit":1000,"fatura":500,"dueDay":10,"closeDay":1}]}',
    );
    expect((b['entities'] as Map)['cards'].single['openingMonth'], '2026-12');
  });
  test('backup rejeita campos monetários corrompidos antes de restaurar', () {
    final data = {
      'app': 'Centavus',
      'version': 4,
      'transactions': [],
      'entities': {
        'cards': [
          {'id': 'a', 'name': 'Cartão', 'limit': 'texto', 'fatura': 0},
        ],
      },
    };
    expect(() => decodeBackup(jsonEncode(data)), throwsFormatException);
  });
  test('backup rejeita data impossível e centavos fracionários', () {
    final data = {
      'app': 'Centavus',
      'version': 4,
      'transactions': [
        {'id': 'x', 'description': 'Teste', 'cents': 100, 'date': '2026-02-31'},
      ],
    };
    expect(() => decodeBackup(jsonEncode(data)), throwsFormatException);
    (data['transactions'] as List).first['date'] = '2026-02-28';
    (data['transactions'] as List).first['cents'] = 100.5;
    expect(() => decodeBackup(jsonEncode(data)), throwsFormatException);
  });
  test('backup legado normaliza referências numéricas de transferências', () {
    final data = {
      'app': 'Centavus',
      'version': 3,
      'transactions': [],
      'accounts': [
        {'id': 1, 'name': 'Banco', 'initial': 50},
        {'id': 2, 'name': 'Carteira', 'initial': 0},
      ],
      'transfers': [
        {'id': 1, 'from': 1, 'to': 2, 'value': 10, 'iso': '2026-11-24'},
      ],
    };
    final decoded = decodeBackup(jsonEncode(data));
    final t = (decoded['entities'] as Map)['transfers'].single;
    expect(t['from'], '1');
    expect(t['to'], '2');
    expect(t['date'], '2026-11-24');
  });
}
