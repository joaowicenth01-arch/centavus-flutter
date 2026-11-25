import 'package:material_ui/material_ui.dart';
import '../data/repository.dart';
import '../domain/finance.dart';
import 'controller.dart';
import 'common.dart';
import 'editor.dart';
import 'entities.dart';
import 'planning.dart';
import 'settings.dart';

class HomeScreen extends StatefulWidget {
  final Repository repository;
  final LocalUser user;
  final Future<void> Function() onLogout;
  const HomeScreen({
    super.key,
    required this.repository,
    required this.user,
    required this.onLogout,
  });
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  late final FinanceController c;
  int page = 0;
  bool privacy = false;
  @override
  void initState() {
    super.initState();
    c = FinanceController(widget.repository, widget.user);
    c.initialize();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  String cash(int n) => privacy ? '••••' : money(n);
  Future<void> safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) message(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/logo.jpg', width: 36, height: 36),
            ),
            const SizedBox(width: 12),
            const Text(
              'Centavus',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: privacy ? 'Mostrar valores' : 'Ocultar valores',
            onPressed: () => setState(() => privacy = !privacy),
            icon: Icon(
              privacy
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Configurações',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(c: c, onLogout: widget.onLogout),
              ),
            ),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        [
                          'Movimentação do mês',
                          'Meu extrato',
                          'Meu dinheiro',
                          'Planejar',
                          'Análises',
                        ][page],
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Mês anterior',
                            onPressed: c.loading ? null : () => c.shift(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: c.loading
                                  ? null
                                  : () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: c.month,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (d != null) {
                                        c.month = DateTime(d.year, d.month);
                                        await c.refresh();
                                      }
                                    },
                              icon: const Icon(
                                Icons.calendar_month_outlined,
                                size: 19,
                              ),
                              label: Text(
                                monthLabel(c.month),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Próximo mês',
                            onPressed: c.loading ? null : () => c.shift(1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      if (page == 1)
                        TextField(
                          onChanged: c.search,
                          decoration: const InputDecoration(
                            hintText: 'Buscar descrição ou categoria',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                        ),
                      if (page != 1)
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => safe(() => c.allFolds(true)),
                                icon: const Icon(Icons.unfold_more, size: 16),
                                label: const Text(
                                  'Abrir tudo',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => safe(() => c.allFolds(false)),
                                icon: const Icon(Icons.unfold_less, size: 16),
                                label: const Text(
                                  'Recolher tudo',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (c.error != null)
                  MaterialBanner(
                    content: Text(c.error!, maxLines: 3),
                    actions: [
                      TextButton(
                        onPressed: c.refresh,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                if (c.loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: c.refresh,
                      child: page == 1
                          ? statement()
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                              children: spaced(switch (page) {
                                0 => overview(),
                                2 => wallet(),
                                3 => planning(context, c, cash),
                                _ => analysis(),
                              }),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (i) => setState(() => page = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Extrato',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Contas',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes),
            label: 'Planejar',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Análises'),
        ],
      ),
      floatingActionButton: page == 1
          ? FloatingActionButton(
              tooltip: 'Nova movimentação',
              onPressed: () => editMovement(context, c),
              child: const Icon(Icons.add),
            )
          : null,
    ),
  );
  List<Widget> spaced(List<Widget> items) => [
    for (final w in items) ...[w, const SizedBox(height: 16)],
  ];
  Widget stat(
    String label,
    int value,
    IconData icon, {
    Color color = mint,
    bool large = false,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    cash(value),
                    style: TextStyle(
                      fontSize: large ? 30 : 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  List<Widget> overview() => [
    Fold(
      c: c,
      id: 'summary',
      title: 'Resumo do mês',
      icon: Icons.wallet_outlined,
      initial: true,
      children: [
        stat(
          'Saldo consolidado',
          c.balance,
          Icons.account_balance_wallet_outlined,
          large: true,
        ),
        const Text(
          'Extrato acumulado + reserva',
          style: TextStyle(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 12),
        const Divider(),
        stat(
          'Entradas do mês',
          c.summary.income,
          Icons.south_west,
          onTap: () => setState(() => page = 1),
        ),
        stat(
          'Saídas do mês',
          c.summary.expense,
          Icons.north_east,
          color: coral,
          onTap: () => setState(() => page = 1),
        ),
      ],
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        quick(
          'Receita',
          Icons.add,
          () => editMovement(context, c, income: true),
          key: const Key('add-income'),
        ),
        quick(
          'Despesa',
          Icons.remove,
          () => editMovement(context, c),
          key: const Key('add-expense'),
        ),
        quick('Extrato', Icons.receipt_long, () => setState(() => page = 1)),
        quick('Metas', Icons.track_changes, () => setState(() => page = 3)),
      ],
    ),
    Fold(
      c: c,
      id: 'month-details',
      title: 'Mais sobre o mês',
      icon: Icons.insights_outlined,
      children: [
        ListTile(
          title: const Text('Resultado do mês'),
          trailing: Text(
            cash(c.summary.net),
            style: const TextStyle(color: mint, fontWeight: FontWeight.w700),
          ),
        ),
        ListTile(
          title: const Text('Taxa de economia'),
          trailing: Text(
            c.summary.income == 0
                ? '—'
                : '${(100 * c.summary.net / c.summary.income).toStringAsFixed(1)}%',
          ),
        ),
      ],
    ),
    Panel(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          navRow(
            'Meu dinheiro',
            'Contas e faturas',
            Icons.account_balance_wallet_outlined,
            2,
          ),
          navRow(
            'Planejar',
            'Metas, limites e reserva',
            Icons.track_changes,
            3,
          ),
          navRow('Análises', 'Seu mês por categoria', Icons.bar_chart, 4),
        ],
      ),
    ),
  ];
  Widget quick(String label, IconData icon, VoidCallback action, {Key? key}) =>
      Column(
        children: [
          IconButton.filledTonal(
            key: key,
            onPressed: action,
            icon: Icon(icon),
            style: IconButton.styleFrom(
              fixedSize: const Size(52, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: muted)),
        ],
      );
  Widget navRow(String title, String sub, IconData icon, int index) => ListTile(
    leading: Icon(icon, color: mint),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
    subtitle: Text(sub, style: const TextStyle(color: muted, fontSize: 11)),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: () => setState(() => page = index),
  );
  Widget statement() => NotificationListener<ScrollNotification>(
    onNotification: (n) {
      if (n.metrics.extentAfter < 350) c.loadMore();
      return false;
    },
    child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
      itemCount: c.rows.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Receitas ${cash(c.summary.income)} · Despesas ${cash(c.summary.expense)}\nToque em uma movimentação para editar a série.',
              style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
            ),
          );
        }
        if (index == c.rows.length + 1) {
          return c.loadingMore
              ? const Center(child: CircularProgressIndicator())
              : c.rows.isEmpty
              ? const Empty(
                  'Nenhuma movimentação neste mês.\nUse + para adicionar a primeira.',
                )
              : c.more
              ? TextButton(
                  onPressed: c.loadMore,
                  child: const Text('Carregar mais'),
                )
              : const SizedBox();
        }
        final row = c.rows[index - 1], t = Movement.fromJson(row);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                t.cents > 0 ? Icons.south_west : Icons.north_east,
                color: t.cents > 0 ? mint : coral,
              ),
              title: Text(
                t.description,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                '${isoDate(t.date)} · ${t.category}',
                style: const TextStyle(fontSize: 10, color: muted),
              ),
              trailing: Text(
                cash(t.cents),
                style: TextStyle(
                  color: t.cents > 0 ? mint : coral,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              onTap: () => safe(() async {
                final plan = await c.repo.plan(
                  c.user.id,
                  row['planId'] as String,
                );
                if (context.mounted) {
                  await editMovement(context, c, existing: plan);
                }
              }),
            ),
          ),
        );
      },
    ),
  );
  List<Widget> wallet() => [
    Fold(
      c: c,
      id: 'accounts',
      title: 'Minhas contas',
      icon: Icons.account_balance_outlined,
      initial: true,
      children: [
        for (final a in c.items('accounts'))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: bankColor(a['color']).withValues(alpha: .17),
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                leading: CircleAvatar(
                  backgroundColor: bankColor(a['color']),
                  child: const Icon(
                    Icons.account_balance_outlined,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  a['name'] as String,
                  style: TextStyle(
                    color: bankColor(a['color']),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  a['type'] as String? ?? 'Conta',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                trailing: Text(
                  cash(c.balances[a['id']] ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => editEntity(context, c, 'accounts', value: a),
              ),
            ),
          ),
        if (c.items('accounts').isEmpty)
          const Empty('Cadastre uma conta para acompanhar o saldo.'),
        TextButton.icon(
          onPressed: () => editEntity(context, c, 'accounts'),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar conta'),
        ),
      ],
    ),
    Fold(
      c: c,
      id: 'cards',
      title: 'Cartões e minhas faturas',
      icon: Icons.credit_card,
      initial: true,
      children: [
        for (final card in c.items('cards'))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: bankColor(card['color']).withValues(alpha: .24),
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        card['name'] as String,
                        style: TextStyle(
                          color: bankColor(card['color']),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${card['brand']} •••• ${card['last4'] ?? ''}',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                      trailing: IconButton(
                        tooltip: 'Editar cartão',
                        onPressed: () =>
                            editEntity(context, c, 'cards', value: card),
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                    ),
                    Text(
                      'Fatura do mês: ${cash(c.invoices[card['id']] ?? 0)}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Limite ${cash(card['limit'] as int)} · Disponível ${cash((card['limit'] as int) - (c.invoices[card['id']] ?? 0))}\nFecha dia ${card['closeDay']} · Vence dia ${card['dueDay']}',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                        height: 1.7,
                      ),
                    ),
                    ExpansionTile(
                      title: const Text(
                        'Próximas faturas',
                        style: TextStyle(fontSize: 12),
                      ),
                      children: [
                        for (var i = 1; i <= 6; i++)
                          FutureBuilder<int>(
                            future: c.repo.invoice(
                              c.user.id,
                              card['id'].toString(),
                              addMonths(c.month, i),
                            ),
                            builder: (context, s) => ListTile(
                              dense: true,
                              title: Text(
                                monthLabel(addMonths(c.month, i)),
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Text(s.hasData ? cash(s.data!) : '…'),
                            ),
                          ),
                      ],
                    ),
                    FilledButton.tonal(
                      onPressed: (c.invoices[card['id']] ?? 0) == 0
                          ? null
                          : () => safe(() async {
                              if (await confirm(
                                context,
                                'Registrar pagamento?',
                                'Dar baixa em ${cash(c.invoices[card['id']]!)} da fatura de ${monthLabel(c.month)}? Isso registra o controle local e não efetua um pagamento bancário.',
                              )) {
                                await c.repo.payInvoice(
                                  c.user.id,
                                  card['id'].toString(),
                                  c.month,
                                );
                                await c.refresh();
                              }
                            }),
                      child: const Text('Registrar fatura paga'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (c.items('cards').isEmpty)
          const Empty('Seus cartões e faturas aparecerão aqui.'),
        TextButton.icon(
          onPressed: () => editEntity(context, c, 'cards'),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar cartão'),
        ),
      ],
    ),
    Fold(
      c: c,
      id: 'transfers',
      title: 'Transferências',
      icon: Icons.swap_horiz,
      children: [
        const Text(
          'Entre suas contas, sem alterar entradas e saídas.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        TextButton.icon(
          onPressed: () => transferDialog(context, c),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Nova transferência'),
        ),
        for (final t in c.items('transfers').reversed.take(20))
          ListTile(
            dense: true,
            title: Text(
              '${accountName(t['from'])} → ${accountName(t['to'])}',
              style: const TextStyle(fontSize: 12),
            ),
            subtitle: Text(
              t['date'] as String? ?? '',
              style: const TextStyle(fontSize: 10),
            ),
            trailing: Text(cash(t['value'] as int)),
          ),
      ],
    ),
  ];
  String accountName(dynamic id) =>
      c
          .items('accounts')
          .where((a) => a['id'] == id)
          .map((a) => a['name'] as String)
          .firstOrNull ??
      'Conta';
  List<Widget> analysis() => [
    Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resultado do mês', style: TextStyle(color: muted)),
          const SizedBox(height: 8),
          Text(
            cash(c.summary.net),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            c.summary.net >= 0
                ? 'As entradas cobrem as saídas neste mês.'
                : 'As saídas superam as entradas neste mês.',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    ),
    Fold(
      c: c,
      id: 'categories',
      title: 'Saídas por categoria',
      icon: Icons.donut_large,
      initial: true,
      children: [
        if (c.categories.isEmpty)
          const Empty('Adicione despesas para ver esta análise.'),
        for (final e in c.categories.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: _categoryColor(
                        e.key,
                      ).withValues(alpha: .2),
                      child: Text(_categoryEmoji(e.key)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${cash(e.value)} · ${(100 * e.value / c.summary.expense).toStringAsFixed(0)}%',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: c.summary.expense == 0
                        ? 0
                        : e.value / c.summary.expense,
                    minHeight: 7,
                    color: _categoryColor(e.key),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assistente local',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            c.categories.isEmpty
                ? 'Ainda não há despesas para analisar.'
                : 'Maior categoria: ${c.categories.keys.first}. Ela representa ${(100 * c.categories.values.first / c.summary.expense).toStringAsFixed(1)}% das saídas.',
            style: const TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Resumo calculado neste aparelho. Sem IA externa ou integração bancária.',
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ),
    ),
    Fold(
      c: c,
      id: 'planning-sync',
      title: 'Planejamento conectado',
      icon: Icons.link_outlined,
      children: [
        if (c.items('budgets').isEmpty && c.items('goals').isEmpty)
          const Empty(
            'Crie uma meta ou limite em Planejar para acompanhar aqui.',
          ),
        for (final b in c.items('budgets'))
          ListTile(
            dense: true,
            leading: const Icon(Icons.speed_outlined, color: mint),
            title: Text(b['name'] as String),
            subtitle: Text(
              '${cash(c.categories[b['name']] ?? 0)} usados de ${cash(b['limit'] as int)}',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
            trailing: Text(
              '${((100 * (c.categories[b['name']] ?? 0) / (b['limit'] as int)).clamp(0, 999)).toStringAsFixed(0)}%',
              style: TextStyle(
                color: (c.categories[b['name']] ?? 0) > (b['limit'] as int)
                    ? coral
                    : mint,
              ),
            ),
          ),
        for (final g in c.items('goals'))
          ListTile(
            dense: true,
            leading: Text(
              g['emoji']?.toString() ?? goalEmoji(g['goalType']),
              style: const TextStyle(fontSize: 22),
            ),
            title: Text(g['name'] as String),
            subtitle: Text(
              '${cash(g['current'] as int)} de ${cash(g['target'] as int)}',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ),
      ],
    ),
  ];

  String _categoryEmoji(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('aliment')) return '🍽️';
    if (lower.contains('transporte') || lower.contains('carro')) return '🚗';
    if (lower.contains('casa') || lower.contains('moradia')) return '🏠';
    if (lower.contains('viagem')) return '✈️';
    if (lower.contains('conta')) return '🧾';
    if (lower.contains('saúde')) return '💚';
    return '📊';
  }

  Color _categoryColor(String category) {
    final palette = bankColors.values.toList();
    final index =
        category.codeUnits.fold<int>(0, (sum, n) => sum + n) % palette.length;
    return palette[index];
  }
}
