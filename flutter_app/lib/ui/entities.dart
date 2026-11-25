import 'package:material_ui/material_ui.dart';
import '../data/repository.dart';
import '../domain/finance.dart';
import 'controller.dart';
import 'common.dart';

class EntityField {
  final String id, label, kind;
  final String initial;
  const EntityField(
    this.id,
    this.label, {
    this.kind = 'text',
    this.initial = '',
  });
}

const entityFields = <String, List<EntityField>>{
  'accounts': [
    EntityField('name', 'Nome da conta'),
    EntityField(
      'type',
      'Tipo (corrente, poupança, dinheiro)',
      initial: 'corrente',
    ),
    EntityField('initial', 'Saldo inicial', kind: 'money', initial: '0'),
  ],
  'cards': [
    EntityField('name', 'Nome do cartão'),
    EntityField('brand', 'Bandeira', initial: 'Mastercard'),
    EntityField('last4', 'Últimos 4 dígitos', kind: 'last4'),
    EntityField('limit', 'Limite', kind: 'money', initial: '0'),
    EntityField('fatura', 'Fatura inicial', kind: 'money', initial: '0'),
    EntityField(
      'closeDay',
      'Dia do fechamento (1–28)',
      kind: 'day',
      initial: '1',
    ),
    EntityField(
      'dueDay',
      'Dia do vencimento (1–28)',
      kind: 'day',
      initial: '10',
    ),
  ],
  'goals': [
    EntityField('name', 'Nome da meta'),
    EntityField('target', 'Valor desejado', kind: 'positiveMoney'),
    EntityField('current', 'Valor guardado', kind: 'money', initial: '0'),
  ],
  'budgets': [
    EntityField(
      'name',
      'Categoria (igual à das despesas)',
      initial: 'Alimentação',
    ),
    EntityField('limit', 'Limite mensal', kind: 'positiveMoney'),
  ],
  'investments': [
    EntityField('name', 'Nome da renda fixa / salário'),
    EntityField('value', 'Receita mensal', kind: 'positiveMoney'),
    EntityField('start', 'Data inicial (AAAA-MM-DD)', kind: 'date'),
    EntityField(
      'months',
      'Prazo em meses (1–120)',
      kind: 'months',
      initial: '12',
    ),
  ],
};
Future<void> editEntity(
  BuildContext context,
  FinanceController c,
  String type, {
  Map<String, dynamic>? value,
}) async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => EntityEditor(c: c, type: type, existing: value),
    ),
  );
}

class EntityEditor extends StatefulWidget {
  final FinanceController c;
  final String type;
  final Map<String, dynamic>? existing;
  const EntityEditor({
    super.key,
    required this.c,
    required this.type,
    this.existing,
  });
  @override
  State<EntityEditor> createState() => _EntityEditorState();
}

class _EntityEditorState extends State<EntityEditor> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  bool busy = false;
  String? error;
  late String selectedColor;
  late String selectedGoalType;
  @override
  void initState() {
    super.initState();
    for (final f in entityFields[widget.type]!) {
      final v = widget.existing?[f.id];
      controllers[f.id] = TextEditingController(
        text: v == null
            ? (f.kind == 'date' ? isoDate(widget.c.month) : f.initial)
            : (f.kind.contains('Money') || f.kind == 'money'
                  ? amountInput(v as int)
                  : v.toString()),
      );
    }
    selectedColor = widget.existing?['color']?.toString() ?? 'verde';
    selectedGoalType =
        widget.existing?['goalType']?.toString() ?? 'Outro sonho';
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? validate(EntityField f, String? input) {
    final s = input!.trim();
    if (s.isEmpty && f.kind != 'last4') return 'Preencha este campo.';
    try {
      if (f.kind == 'money' || f.kind == 'positiveMoney') {
        final v = parseMoney(s);
        if ((v < 0 && !(widget.type == 'accounts' && f.id == 'initial')) ||
            f.kind == 'positiveMoney' && v == 0) {
          return 'Informe um valor ${f.kind == 'positiveMoney' ? 'positivo' : 'não negativo'}.';
        }
      }
      if (f.kind == 'day' || f.kind == 'months') {
        final v = int.parse(s);
        if (v < 1 || v > (f.kind == 'day' ? 28 : 120)) {
          return 'Valor fora do intervalo.';
        }
      }
      if (f.kind == 'last4' &&
          s.isNotEmpty &&
          !RegExp(r'^\d{4}$').hasMatch(s)) {
        return 'Use 4 dígitos.';
      }
      if (f.kind == 'date') {
        final d = DateTime.parse(s);
        if (isoDate(d) != s || d.year < 2000 || d.year > 2100) {
          return 'Use uma data válida.';
        }
      }
    } catch (_) {
      return 'Valor inválido.';
    }
    return null;
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = <String, dynamic>{
        ...?widget.existing,
        'id': widget.existing?['id'] ?? newId(),
      };
      for (final f in entityFields[widget.type]!) {
        final s = controllers[f.id]!.text.trim();
        data[f.id] = f.kind == 'money' || f.kind == 'positiveMoney'
            ? parseMoney(s)
            : f.kind == 'day' || f.kind == 'months'
            ? int.parse(s)
            : s;
      }
      if (widget.type == 'accounts' || widget.type == 'cards') {
        data['color'] = selectedColor;
      }
      if (widget.type == 'goals') {
        data['goalType'] = selectedGoalType;
        data['emoji'] = goalEmoji(selectedGoalType);
      }
      if (widget.type == 'cards') {
        data['openingMonth'] ??= monthKey(widget.c.month);
        if ((data['fatura'] as int) > (data['limit'] as int)) {
          throw const FormatException(
            'A fatura não pode ultrapassar o limite informado.',
          );
        }
      }
      await widget.c.repo.putEntity(widget.c.user.id, widget.type, data);
      await widget.c.refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.existing == null ? 'Adicionar registro' : 'Editar registro',
      ),
    ),
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final f in entityFields[widget.type]!) ...[
              TextFormField(
                controller: controllers[f.id],
                decoration: InputDecoration(labelText: f.label),
                keyboardType: f.kind == 'text' || f.kind == 'date'
                    ? TextInputType.text
                    : const TextInputType.numberWithOptions(decimal: true),
                validator: (s) => validate(f, s),
              ),
              const SizedBox(height: 18),
            ],
            if (widget.type == 'goals') ...[
              const Text(
                'Qual é o seu sonho?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: goalTypes.entries
                    .map(
                      (item) => ChoiceChip(
                        label: Text('${item.value} ${item.key}'),
                        selected: selectedGoalType == item.key,
                        onSelected: (_) =>
                            setState(() => selectedGoalType = item.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
            ],
            if (widget.type == 'accounts' || widget.type == 'cards') ...[
              Text(
                widget.type == 'cards'
                    ? 'Cor para identificar o cartão'
                    : 'Cor para identificar a conta',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: bankColors.entries
                    .map(
                      (item) => ChoiceChip(
                        avatar: CircleAvatar(
                          radius: 9,
                          backgroundColor: item.value,
                        ),
                        label: Text(
                          item.key[0].toUpperCase() + item.key.substring(1),
                        ),
                        selected: selectedColor == item.key,
                        onSelected: (_) =>
                            setState(() => selectedColor = item.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
            ],
            if (widget.type == 'investments')
              const Text(
                'Receita reconhecida todo mês durante o prazo, como na versão anterior. Não representa cotação nem rendimento bancário.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            if (error != null)
              Text(error!, style: const TextStyle(color: coral)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Salvando…' : 'Salvar'),
            ),
            if (widget.existing != null)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (await confirm(
                          context,
                          'Excluir registro?',
                          'Esta ação remove o registro selecionado.',
                        )) {
                          try {
                            await widget.c.repo.deleteEntity(
                              widget.c.user.id,
                              widget.type,
                              widget.existing!['id'].toString(),
                            );
                            await widget.c.refresh();
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) message(context, e);
                          }
                        }
                      },
                child: const Text(
                  'Excluir registro',
                  style: TextStyle(color: coral),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> transferDialog(BuildContext context, FinanceController c) async {
  if (c.items('accounts').length < 2) {
    message(context, 'Cadastre duas contas para transferir.');
    return;
  }
  String? from, to;
  final value = TextEditingController();
  String? error;
  bool busy = false;
  await showDialog<void>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, set) => AlertDialog(
        title: const Text('Transferir entre contas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Origem'),
              items: c
                  .items('accounts')
                  .map(
                    (e) => DropdownMenuItem(
                      value: e['id'].toString(),
                      child: Text(e['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (v) => from = v,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Destino'),
              items: c
                  .items('accounts')
                  .map(
                    (e) => DropdownMenuItem(
                      value: e['id'].toString(),
                      child: Text(e['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (v) => to = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Valor'),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: coral)),
          ],
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
                      await c.repo.transfer(
                        c.user.id,
                        from ?? '',
                        to ?? '',
                        parseMoney(value.text),
                        c.month,
                      );
                      await c.refresh();
                      if (dialog.mounted) Navigator.pop(dialog);
                    } catch (e) {
                      set(() {
                        busy = false;
                        error = e.toString();
                      });
                    }
                  },
            child: const Text('Transferir'),
          ),
        ],
      ),
    ),
  );
  value.dispose();
}
