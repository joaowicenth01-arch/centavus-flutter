import 'dart:math' as math;

String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';
String isoDate(DateTime d) =>
    '${monthKey(d)}-${d.day.toString().padLeft(2, '0')}';
DateTime addMonths(DateTime date, int months) {
  final first = DateTime(date.year, date.month + months);
  return DateTime(
    first.year,
    first.month,
    math.min(date.day, DateTime(first.year, first.month + 1, 0).day),
  );
}

int parseMoney(String input) {
  var s = input.replaceAll(RegExp(r'R\$|\s'), '');
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(s)) {
    throw const FormatException('Informe um valor válido, como 123,45.');
  }
  final sign = s.startsWith('-') ? -1 : 1;
  final parts = s.replaceAll('-', '').split('.');
  final result =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  if (result > 9000000000000) throw const FormatException('Valor muito alto.');
  return sign * result;
}

class Movement {
  final String id, description, category, payment;
  final int cents, installments;
  final DateTime date;
  final String? accountId, cardId;
  final List<int> advanced;
  final bool recurring;

  /// First competence generated after the original recurring movement.
  /// This is useful when importing legacy backups that already contain
  /// historical copies of a recurring item.
  final DateTime? recurringFrom;
  const Movement({
    required this.id,
    required this.description,
    required this.cents,
    required this.date,
    this.category = 'Outros',
    this.payment = 'pix',
    this.installments = 1,
    this.accountId,
    this.cardId,
    this.advanced = const [],
    this.recurring = false,
    this.recurringFrom,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'cents': cents,
    'date': isoDate(date),
    'category': category,
    'payment': payment,
    'installments': installments,
    'accountId': accountId,
    'cardId': cardId,
    'advanced': advanced,
    'recurring': recurring,
    'recurringFrom': recurringFrom == null ? null : isoDate(recurringFrom!),
  };
  factory Movement.fromJson(Map<String, dynamic> j) => Movement(
    id: j['id'].toString(),
    description: j['description'] as String,
    cents: j['cents'] as int,
    date: DateTime.parse(j['date'] as String),
    category: j['category'] as String? ?? 'Outros',
    payment: j['payment'] as String? ?? 'pix',
    installments: j['installments'] as int? ?? 1,
    accountId: j['accountId']?.toString(),
    cardId: j['cardId']?.toString(),
    advanced: List<int>.from(j['advanced'] ?? []),
    recurring: j['recurring'] == true,
    recurringFrom: j['recurringFrom'] == null
        ? null
        : DateTime.parse(j['recurringFrom'] as String),
  );
  List<Movement> parts() {
    if (installments < 1 || installments > 60) {
      throw const FormatException('Use entre 1 e 60 parcelas.');
    }
    final base = cents.abs() ~/ installments,
        remainder = cents.abs() % installments;
    return List.generate(
      installments,
      (i) => Movement(
        id: '$id:${i + 1}',
        description: installments > 1
            ? '$description · ${i + 1}/$installments'
            : description,
        cents: (base + (i < remainder ? 1 : 0)) * cents.sign,
        date: addMonths(date, i),
        category: category,
        payment: payment,
        accountId: accountId,
        cardId: cardId,
        advanced: advanced.contains(i + 1) ? [1] : const [],
      ),
    );
  }
}

class MonthSummary {
  final int income, expense;
  const MonthSummary(this.income, this.expense);
  int get net => income - expense;
  factory MonthSummary.from(Iterable<Movement> items, DateTime month) {
    var income = 0, expense = 0;
    for (final t in items) {
      if (monthKey(t.date) != monthKey(month)) continue;
      if (t.cents > 0) {
        income += t.cents;
      } else {
        expense -= t.cents;
      }
    }
    return MonthSummary(income, expense);
  }
  @override
  bool operator ==(Object other) =>
      other is MonthSummary &&
      income == other.income &&
      expense == other.expense;
  @override
  int get hashCode => Object.hash(income, expense);
}

Map<String, MonthSummary> indexMonths(Iterable<Movement> items) {
  final index = <String, MonthSummary>{};
  for (final t in items) {
    final key = monthKey(t.date),
        old = index[monthKey(t.date)] ?? const MonthSummary(0, 0);
    index[key] = MonthSummary(
      old.income + (t.cents > 0 ? t.cents : 0),
      old.expense + (t.cents < 0 ? -t.cents : 0),
    );
  }
  return index;
}

int invoiceDue(
  Iterable<Movement> plans,
  String card,
  DateTime month, {
  int payments = 0,
}) {
  var total = 0;
  for (final t in plans.where(
    (t) => t.cardId == card && t.payment == 'credito',
  )) {
    for (final p in t.parts()) {
      if (monthKey(p.date) == monthKey(month) &&
          p.cents < 0 &&
          p.advanced.isEmpty) {
        total -= p.cents;
      }
    }
  }
  return math.max(0, total - payments);
}

double projection(
  int principal,
  int monthly,
  int months,
  double annualPercent,
) {
  final rate = math.pow(1 + annualPercent / 100, 1 / 12) - 1;
  if (rate == 0) return (principal + monthly * months).toDouble();
  final factor = math.pow(1 + rate, months);
  return principal * factor + monthly * (factor - 1) / rate;
}

Map<String, dynamic> accrueReserve(Map<String, dynamic> reserve, DateTime now) {
  final result = Map<String, dynamic>.from(reserve),
      history = List<dynamic>.from(reserve['history'] ?? []);
  var balance = reserve['balance'] as int;
  final annual = (reserve['annual'] as num).toDouble();
  if (balance <= 0 || annual <= 0) return result;
  var last = DateTime.tryParse(reserve['lastYieldAt'] as String? ?? '') ?? now;
  final rate = math.pow(1 + annual / 100, 1 / 12) - 1;
  for (var i = 0; i < 120; i++) {
    final next = addMonths(last, 1);
    if (next.isAfter(now)) break;
    final interest = (balance * rate).round();
    balance += interest;
    last = next;
    history.add({
      'date': isoDate(next),
      'cents': interest,
      'type': 'rendimento simulado',
    });
  }
  return {
    ...result,
    'balance': balance,
    'lastYieldAt': isoDate(last),
    'history': history,
  };
}
