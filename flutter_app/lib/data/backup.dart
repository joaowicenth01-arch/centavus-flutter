import 'dart:convert';
import '../domain/finance.dart';

/// Pure function, also used by compute() for large imports.
Map<String, dynamic> decodeBackup(String source) {
  try {
    return _decodeBackup(source);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('A estrutura do backup é inválida.');
  }
}

Map<String, dynamic> _decodeBackup(String source) {
  if (source.length > 20 * 1024 * 1024) {
    throw const FormatException('Backup maior que 20 MB.');
  }
  final raw = jsonDecode(source);
  if (raw is! Map<String, dynamic> ||
      raw['app'] != 'Centavus' ||
      ![3, 4].contains(raw['version'])) {
    throw const FormatException('Use um backup Centavus versão 3 ou 4.');
  }
  final version = raw['version'];
  final tx = raw['transactions'];
  if (tx is! List || tx.length > 100000) {
    throw const FormatException('Movimentações inválidas.');
  }
  int cents(dynamic v) {
    if (v is! num || !v.isFinite || v.abs() > 90000000000) {
      throw const FormatException('Valor inválido no backup.');
    }
    return version == 3 ? (v * 100).round() : v.toInt();
  }

  final plans = <Map<String, dynamic>>[];
  final ids = <String>{};
  for (final value in tx) {
    if (value is! Map) throw const FormatException('Movimentação inválida.');
    final j = Map<String, dynamic>.from(value);
    final id = j['id']?.toString();
    if (id == null || id.isEmpty || !ids.add(id)) {
      throw const FormatException('Identificador duplicado ou ausente.');
    }
    if (version == 3) {
      final n = (j['parcelas'] as num? ?? 1).toInt();
      final amount = cents(j['amount']);
      plans.add(
        Movement(
          id: id,
          description: j['desc'] as String,
          cents: n > 1
              ? cents(j['total'] ?? ((j['amount'] as num).abs() * n)) *
                    amount.sign
              : amount,
          date: DateTime.parse(j['iso'] as String),
          installments: n,
          category: j['cat'] as String? ?? 'Outros',
          payment: j['pay'] as String? ?? 'pix',
          accountId: j['accId']?.toString(),
          cardId: j['cardId']?.toString(),
          recurring: j['recorrente'] == true,
          recurringFrom: j['recorrente'] == true && j['proxIso'] is String
              ? DateTime.parse(j['proxIso'] as String)
              : null,
          advanced: List<int>.from(j['antecipadas'] ?? []),
        ).toJson(),
      );
    } else {
      plans.add(j);
    }
  }
  for (final j in plans) {
    final t = Movement.fromJson(j);
    if (isoDate(t.date) != j['date']) {
      throw const FormatException('Data inválida.');
    }
    if (t.description.trim().isEmpty ||
        t.cents.abs() > 9000000000000 ||
        t.cents == 0 ||
        t.date.year < 1900 ||
        t.date.year > 2200 ||
        (t.recurring && t.installments > 1)) {
      throw const FormatException('Dados financeiros inválidos.');
    }
    t.parts();
  }
  final entities = <String, List<Map<String, dynamic>>>{};
  const types = [
    'accounts',
    'cards',
    'goals',
    'budgets',
    'transfers',
    'payments',
    'investments',
    'reserve',
    'preferences',
  ];
  for (final type in types) {
    final list = version == 4
        ? ((raw['entities'] as Map? ?? {})[type])
        : raw[type];
    if (list != null && list is! List) {
      throw FormatException('Área $type inválida.');
    }
    final seen = <String>{};
    entities[type] = [];
    for (final item in (list as List? ?? [])) {
      if (item is! Map) throw const FormatException('Registro inválido.');
      final j = Map<String, dynamic>.from(item);
      j['id'] = (j['id'] ?? j['name'])?.toString();
      if (j['id'] == null || !seen.add(j['id'])) {
        throw const FormatException('Registro duplicado ou sem nome.');
      }
      if (version == 3) {
        for (final key in [
          'initial',
          'limit',
          'fatura',
          'target',
          'current',
          'value',
          'valor',
        ]) {
          if (j[key] != null) j[key] = cents(j[key]);
        }
        if (type == 'cards') j.remove('pagamentos');
      }
      entities[type]!.add(j);
    }
  }
  // Preserve legacy payments after the generic payments pass.
  if (version == 3) {
    entities['payments'] = [];
    for (final card in (raw['cards'] as List? ?? [])) {
      for (final p in (card['pagamentos'] as List? ?? [])) {
        entities['payments']!.add({
          'id': '${card['id']}:${p['id']}',
          'cardId': card['id'].toString(),
          'month': (p['data'] as String).substring(0, 7),
          'cents': cents(p['valor']),
          'date': p['data'],
        });
      }
    }
    final reserve = raw['cofrinho'];
    if (reserve is Map) {
      entities['reserve'] = [
        {
          'id': 'main',
          'balance': cents(reserve['saldo'] ?? 0),
          'annual': (reserve['cdi'] as num? ?? 0).toDouble(),
          'monthly': cents(reserve['mensal'] ?? 0),
          'lastYieldAt': reserve['lastYieldAt'],
          'history': reserve['hist'] ?? [],
        },
      ];
    }
    final fixed = raw['rendaFixa'];
    if (fixed is Map) {
      for (final item in fixed['itens'] as List? ?? []) {
        final j = Map<String, dynamic>.from(item);
        entities['investments']!.add({
          ...j,
          'id': j['id'].toString(),
          'value': cents(j['valor']),
          'start': j['dataIni'],
          'months': j['prazo'] ?? 12,
          'name': j['name'] ?? j['nome'] ?? 'Renda fixa',
        });
      }
    }
  }
  for (final group in entities.entries) {
    if (group.value.length > 100000) {
      throw const FormatException('Backup com registros demais.');
    }
    for (final j in group.value) {
      void integer(String key, {int fallback = 0, bool positive = false}) {
        final v = j[key] ?? fallback;
        if (v is! int || v.abs() > 9000000000000 || positive && v < 0) {
          throw FormatException('Valor inválido em ${group.key}: $key.');
        }
        j[key] = v;
      }

      void date(String key) {
        final v = j[key];
        if (v is! String || isoDate(DateTime.parse(v)) != v) {
          throw const FormatException('Data inválida.');
        }
      }

      if ([
        'accounts',
        'cards',
        'goals',
        'budgets',
        'investments',
      ].contains(group.key)) {
        if (j['name'] is! String || (j['name'] as String).trim().isEmpty) {
          throw const FormatException('Nome de registro inválido.');
        }
      }
      switch (group.key) {
        case 'accounts':
          integer('initial');
          j['type'] ??= 'corrente';
        case 'cards':
          integer('limit', positive: true);
          integer('fatura', positive: true);
          j['brand'] ??= 'Outro';
          j['last4'] ??= '';
          if (j['openingMonth'] == null) {
            final exported =
                DateTime.tryParse(raw['exportedAt'] as String? ?? '') ??
                DateTime.now();
            final due = (j['dueDay'] as num?)?.toInt() ?? 1;
            final nextDue = exported.day > due
                ? addMonths(DateTime(exported.year, exported.month, due), 1)
                : DateTime(exported.year, exported.month, due);
            j['openingMonth'] = monthKey(nextDue);
          }
          for (final day in ['closeDay', 'dueDay']) {
            integer(day, fallback: 1);
            if (j[day] < 1 || j[day] > 28) {
              throw const FormatException('Dia de cartão inválido.');
            }
          }
        case 'goals':
          integer('target', positive: true);
          integer('current', positive: true);
        case 'budgets':
          integer('limit', positive: true);
        case 'transfers':
          integer('value', positive: true);
          j['from'] = j['from'].toString();
          j['to'] = j['to'].toString();
          j['date'] ??= j['iso'];
          date('date');
          final accountIds = entities['accounts']!.map((a) => a['id']).toSet();
          if (j['from'] == j['to'] ||
              !accountIds.contains(j['from']) ||
              !accountIds.contains(j['to'])) {
            throw const FormatException('Transferência com conta inexistente.');
          }
        case 'payments':
          integer('cents', positive: true);
          date('date');
          if (!RegExp(
            r'^\d{4}-(0[1-9]|1[0-2])$',
          ).hasMatch(j['month'] as String)) {
            throw const FormatException('Competência inválida.');
          }
        case 'investments':
          integer('value', positive: true);
          integer('months', fallback: 12);
          if (j['months'] < 1 || j['months'] > 120) {
            throw const FormatException('Prazo inválido.');
          }
          date('start');
        case 'reserve':
          integer('balance', positive: true);
          integer('monthly', positive: true);
          final rate = j['annual'];
          if (rate is! num || !rate.isFinite || rate < 0 || rate > 100) {
            throw const FormatException('Taxa inválida.');
          }
          if (j['history'] is! List) {
            throw const FormatException('Histórico inválido.');
          }
        case 'preferences':
          if (j['id'] == 'panels' &&
              (j['values'] is! Map ||
                  (j['values'] as Map).values.any((v) => v is! bool))) {
            throw const FormatException('Preferências inválidas.');
          }
      }
    }
  }
  return {'transactions': plans, 'entities': entities};
}
