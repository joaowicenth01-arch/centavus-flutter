import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../domain/benchmark.dart';
import 'common.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});
  @override
  State<PerformanceScreen> createState() => _PerformanceState();
}

class _PerformanceState extends State<PerformanceScreen> {
  bool running = false, collecting = false;
  Map<String, dynamic>? result;
  String? error;
  final frames = <int>[];
  int hz = 60;
  void collect(List<FrameTiming> list) {
    if (!collecting) return;
    frames.addAll(list.map((f) => f.totalSpan.inMicroseconds));
    if (frames.length > 10000) frames.removeRange(0, frames.length - 10000);
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(collect);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(collect);
    super.dispose();
  }

  Future<void> benchmark() async {
    setState(() {
      running = true;
      error = null;
    });
    try {
      final r = await compute(runBenchmark, 50000);
      if (mounted) setState(() => result = r);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [...frames]..sort();
    final budget = 1000000 / hz;
    final stats = {
      'mode': kProfileMode
          ? 'profile'
          : kReleaseMode
          ? 'release'
          : 'debug',
      'targetHz': hz,
      'samples': frames.length,
      'p95Micros': ordered.isEmpty
          ? null
          : ordered[((ordered.length - 1) * .95).floor()],
      'overBudget': frames.where((n) => n > budget).length,
      'note':
          'Tempo total de frame observado; não é leitura de FPS nem de memória.',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Laboratório de desempenho')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Panel(
            child: Text(
              'Os dados deste laboratório são sintéticos e não alteram suas contas. Compare no mesmo dispositivo e modo de execução.',
              style: TextStyle(color: muted, height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '1. CPU: agregação por mês',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Baseline: percorre o histórico para cada mês. Otimizada: cria um índice em uma passagem. Ambas precisam produzir o mesmo resultado.',
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: running ? null : benchmark,
            child: Text(
              running ? 'Medindo…' : 'Medir com 50 mil movimentações',
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 14),
            Panel(
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(result),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
          if (error != null) Text(error!, style: const TextStyle(color: coral)),
          const SizedBox(height: 24),
          const Text(
            '2. UI: lista sob demanda',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Abra a lista, inicie a coleta e role. Repita com a outra estratégia. Use modo profile e Flutter DevTools para capturar CPU e memória.',
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SyntheticList(lazy: false),
                  ),
                ),
                child: const Text('Baseline: eager'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SyntheticList(lazy: true),
                  ),
                ),
                child: const Text('Otimizada: lazy'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: hz,
            decoration: const InputDecoration(
              labelText: 'Frequência de referência do dispositivo',
            ),
            items: const [
              DropdownMenuItem(value: 60, child: Text('60 Hz')),
              DropdownMenuItem(value: 120, child: Text('120 Hz')),
            ],
            onChanged: (v) => setState(() => hz = v!),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => setState(() {
              collecting = !collecting;
              if (collecting) frames.clear();
            }),
            child: Text(
              collecting
                  ? 'Parar coleta de frames'
                  : 'Iniciar coleta de frames',
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(stats),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '3. Offline e banco indexado',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'O extrato consulta 50 registros por página usando índice (usuário, mês, data). A restauração valida o backup antes de abrir uma transação. No Android/iOS, compute() leva o processamento de backups e o benchmark para outro isolate; no Web ele não garante paralelismo.',
            style: TextStyle(color: muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class SyntheticList extends StatelessWidget {
  final bool lazy;
  const SyntheticList({super.key, required this.lazy});
  Widget row(int i) => ListTile(
    leading: const Icon(Icons.receipt_long_outlined),
    title: Text('Movimentação sintética ${i + 1}'),
    subtitle: const Text('Amostra para medir rolagem'),
    trailing: Text(money(10000 + i)),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(lazy ? 'Lista lazy · 5 mil' : 'Lista eager · 5 mil'),
    ),
    body: lazy
        ? ListView.builder(
            itemCount: 5000,
            itemExtent: 76,
            itemBuilder: (_, i) => row(i),
          )
        : ListView(children: List.generate(5000, row)),
  );
}
