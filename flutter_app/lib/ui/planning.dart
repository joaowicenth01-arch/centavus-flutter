import 'package:material_ui/material_ui.dart';
import '../domain/finance.dart';
import 'controller.dart';
import 'common.dart';
import 'entities.dart';

List<Widget> planning(
  BuildContext context,
  FinanceController c,
  String Function(int) cash,
) => [
  Fold(
    c: c,
    id: 'goals',
    title: 'Minhas metas',
    icon: Icons.flag_outlined,
    initial: true,
    children: [
      for (final g in c.items('goals'))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: const Color(0xff193226),
            borderRadius: BorderRadius.circular(18),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Text(
                g['emoji']?.toString() ?? goalEmoji(g['goalType']),
                style: const TextStyle(fontSize: 30),
              ),
              title: Text(
                g['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g['goalType']?.toString() ?? 'Meta pessoal',
                      style: const TextStyle(color: mint, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${cash(g['current'] as int)} de ${cash(g['target'] as int)}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (g['target'] as int) > 0
                          ? ((g['current'] as int) / (g['target'] as int))
                                .clamp(0, 1)
                          : 0,
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 19),
              onTap: () => editEntity(context, c, 'goals', value: g),
            ),
          ),
        ),
      if (c.items('goals').isEmpty)
        const Empty('Uma meta deixa seu próximo passo mais claro.'),
      TextButton.icon(
        onPressed: () => editEntity(context, c, 'goals'),
        icon: const Icon(Icons.add),
        label: const Text('Criar meta'),
      ),
    ],
  ),
  Fold(
    c: c,
    id: 'budgets',
    title: 'Limites por categoria',
    icon: Icons.speed,
    children: [
      for (final b in c.items('budgets'))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(b['name'] as String),
          subtitle: Text(
            '${cash(c.categories[b['name']] ?? 0)} de ${cash(b['limit'] as int)}',
            style: TextStyle(
              color: (c.categories[b['name']] ?? 0) > (b['limit'] as int)
                  ? coral
                  : muted,
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.edit_outlined, size: 19),
          onTap: () => editEntity(context, c, 'budgets', value: b),
        ),
      if (c.items('budgets').isEmpty)
        const Empty('Defina quanto quer gastar em cada categoria.'),
      TextButton.icon(
        onPressed: () => editEntity(context, c, 'budgets'),
        icon: const Icon(Icons.add),
        label: const Text('Definir limite'),
      ),
    ],
  ),
  Fold(
    c: c,
    id: 'reserve',
    title: 'Minha reserva',
    icon: Icons.savings_outlined,
    children: [
      Builder(
        builder: (context) {
          final r =
              c.items('reserve').firstOrNull ??
              {'id': 'main', 'balance': 0, 'annual': 0.0, 'monthly': 0};
          final balance = r['balance'] as int,
              annual = (r['annual'] as num).toDouble(),
              monthly = r['monthly'] as int;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                cash(balance),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Projeção em 12 meses: ${cash(projection(balance, monthly, 12, annual).round())}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Taxa de simulação: ${annual.toStringAsFixed(2)}% ao ano. Aporte mensal: ${cash(monthly)}. Projeção matemática, sem garantia de rendimento e sem taxas/impostos.',
                style: const TextStyle(color: muted, fontSize: 11, height: 1.5),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => reserveDialog(context, c, r),
                child: const Text('Gerenciar reserva'),
              ),
            ],
          );
        },
      ),
    ],
  ),
  Fold(
    c: c,
    id: 'investments',
    title: 'Renda fixa / salário',
    icon: Icons.event_repeat,
    children: [
      const Text(
        'Receita mensal reconhecida durante o período cadastrado, como na versão anterior.',
        style: TextStyle(color: muted, fontSize: 12, height: 1.5),
      ),
      for (final r in c.items('investments'))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(r['name'] as String),
          subtitle: Text(
            '${cash(r['value'] as int)} por mês · ${r['months']} meses\nInício ${r['start']}',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          trailing: const Icon(Icons.edit_outlined, size: 19),
          onTap: () => editEntity(context, c, 'investments', value: r),
        ),
      TextButton.icon(
        onPressed: () => editEntity(context, c, 'investments'),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar renda fixa'),
      ),
    ],
  ),
];

Future<void> reserveDialog(
  BuildContext context,
  FinanceController c,
  Map<String, dynamic> reserve,
) async {
  final value = TextEditingController(text: '0'),
      annual = TextEditingController(text: reserve['annual'].toString()),
      monthly = TextEditingController(
        text: amountInput(reserve['monthly'] as int),
      );
  bool withdraw = false, busy = false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, set) => AlertDialog(
        title: const Text('Gerenciar reserva'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Resgatar valor'),
                value: withdraw,
                onChanged: (v) => set(() => withdraw = v),
              ),
              TextField(
                controller: value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: withdraw
                      ? 'Valor a resgatar'
                      : 'Valor a adicionar',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: annual,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Taxa de referência anual (%)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: monthly,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Aporte mensal para simulação',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Controle manual da reserva. Não movimenta dinheiro bancário.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: coral)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialog),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    set(() => busy = true);
                    try {
                      final delta = parseMoney(value.text),
                          rate = double.parse(annual.text.replaceAll(',', '.')),
                          perMonth = parseMoney(monthly.text);
                      if (delta < 0 ||
                          perMonth < 0 ||
                          !rate.isFinite ||
                          rate < 0 ||
                          rate > 100) {
                        throw const FormatException(
                          'Valores inválidos. Taxa entre 0 e 100%.',
                        );
                      }
                      final balance =
                          (reserve['balance'] as int) +
                          (withdraw ? -delta : delta);
                      if (balance < 0) {
                        throw const FormatException(
                          'O resgate ultrapassa o saldo.',
                        );
                      }
                      await c.repo.putEntity(c.user.id, 'reserve', {
                        ...reserve,
                        'balance': balance,
                        'annual': rate,
                        'monthly': perMonth,
                        'lastYieldAt':
                            ((reserve['balance'] as int) == 0
                                ? null
                                : reserve['lastYieldAt']) ??
                            isoDate(DateTime.now()),
                        'history': [
                          ...reserve['history'] as List? ?? [],
                          {
                            'date': isoDate(DateTime.now()),
                            'cents': withdraw ? -delta : delta,
                            'type': withdraw ? 'resgate' : 'aporte',
                          },
                        ],
                      });
                      await c.refresh();
                      if (dialog.mounted) Navigator.pop(dialog);
                    } catch (e) {
                      set(() {
                        busy = false;
                        error = e.toString();
                      });
                    }
                  },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
  value.dispose();
  annual.dispose();
  monthly.dispose();
}
