import 'dart:math';
import 'finance.dart';

Map<String, dynamic> runBenchmark(int count) {
  final data = List.generate(
    count,
    (i) => Movement(
      id: '$i',
      description: 'Movimentação sintética $i',
      cents: i.isEven ? 10000 + i % 1000 : -(2000 + i % 700),
      date: DateTime(2020 + i % 7, i % 12 + 1, i % 28 + 1),
    ),
  );
  final months = List.generate(84, (i) => DateTime(2020 + i ~/ 12, i % 12 + 1));
  List<int> baseline() =>
      months.map((m) => MonthSummary.from(data, m).net).toList();
  List<int> optimized() {
    final index = indexMonths(data);
    return months.map((m) => index[monthKey(m)]?.net ?? 0).toList();
  }

  baseline();
  optimized(); // Warm up both paths before timed trials.
  final before = <int>[], after = <int>[];
  var checksum = 0;
  for (var trial = 0; trial < 7; trial++) {
    final sw = Stopwatch()..start();
    final a = baseline();
    sw.stop();
    before.add(sw.elapsedMicroseconds);
    sw
      ..reset()
      ..start();
    final b = optimized();
    sw.stop();
    after.add(sw.elapsedMicroseconds);
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) throw StateError('Resultados divergentes.');
      checksum += a[i];
    }
  }
  before.sort();
  after.sort();
  return {
    'date': DateTime.now().toIso8601String(),
    'rows': count,
    'months': 84,
    'trials': 7,
    'warmup': 1,
    'baselineMedianMicros': before[3],
    'indexedMedianMicros': after[3],
    'speedup': before[3] / max(1, after[3]),
    'equivalent': true,
    'checksum': checksum,
    'scope':
        'CPU de agregação em memória; não mede RAM, inicialização nem FPS.',
  };
}
