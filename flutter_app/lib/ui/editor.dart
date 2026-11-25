import 'package:material_ui/material_ui.dart';
import '../data/repository.dart';
import '../domain/finance.dart';
import 'controller.dart';
import 'common.dart';

Future<void> editMovement(
  BuildContext context,
  FinanceController c, {
  bool income = false,
  Movement? existing,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => MovementEditor(c: c, income: income, existing: existing),
  ),
);

class MovementEditor extends StatefulWidget {
  final FinanceController c;
  final bool income;
  final Movement? existing;
  const MovementEditor({
    super.key,
    required this.c,
    this.income = false,
    this.existing,
  });
  @override
  State<MovementEditor> createState() => _MovementEditorState();
}

class _MovementEditorState extends State<MovementEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController description, value;
  late DateTime date;
  late bool income, recurring;
  late int installments;
  late String category, payment;
  String? account, card;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    description = TextEditingController(text: t?.description ?? '');
    value = TextEditingController(
      text: t == null ? '' : amountInput(t.cents.abs()),
    );
    date = t?.date ?? widget.c.month;
    income = t == null ? widget.income : t.cents > 0;
    recurring = t?.recurring ?? false;
    installments = t?.installments ?? 1;
    category = t?.category ?? 'Outros';
    payment = t?.payment ?? 'pix';
    account = t?.accountId;
    card = t?.cardId;
  }

  @override
  void dispose() {
    description.dispose();
    value.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final t = Movement(
        id: widget.existing?.id ?? newId(),
        description: description.text.trim(),
        cents: parseMoney(value.text) * (income ? 1 : -1),
        date: date,
        category: income ? 'Receita' : category,
        payment: payment,
        installments: income ? 1 : installments,
        accountId: account,
        cardId: ['credito', 'debito'].contains(payment) ? card : null,
        recurring: recurring,
        recurringFrom: date == widget.existing?.date
            ? widget.existing?.recurringFrom
            : null,
        advanced: widget.existing?.advanced ?? [],
      );
      if (['credito', 'debito'].contains(payment) && card == null) {
        throw const FormatException(
          'Cadastre e selecione um cartão na área Meu dinheiro.',
        );
      }
      await widget.c.repo.saveMovement(widget.c.user.id, t);
      await widget.c.refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var preview = '';
    try {
      final total = parseMoney(value.text);
      preview =
          '${money(total)} em $installments parcela(s) · primeira ${money((total / installments).ceil())}';
    } catch (_) {}
    final cards = widget.c.items('cards'),
        accounts = widget.c.items('accounts');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Nova movimentação' : 'Editar movimentação',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Receita'),
                    icon: Icon(Icons.south_west),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Despesa'),
                    icon: Icon(Icons.north_east),
                  ),
                ],
                selected: {income},
                onSelectionChanged: (v) => setState(() {
                  income = v.first;
                  installments = 1;
                  recurring = false;
                }),
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('movement-description'),
                controller: description,
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: (v) =>
                    v!.trim().isEmpty ? 'Informe a descrição.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('movement-value'),
                controller: value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Valor total',
                  prefixText: 'R\$ ',
                ),
                validator: (v) {
                  try {
                    if (parseMoney(v!) <= 0) {
                      return 'Informe um valor positivo.';
                    }
                  } catch (_) {
                    return 'Valor inválido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: mint),
                title: const Text('Competência da primeira parcela'),
                subtitle: Text(isoDate(date)),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100, 12, 31),
                  );
                  if (d != null) setState(() => date = d);
                },
              ),
              if (!income) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items:
                      {
                            'Alimentação',
                            'Roupas',
                            'Transporte',
                            'Lazer',
                            'Moradia',
                            'Saúde',
                            'Educação',
                            'Outros',
                            category,
                          }
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: payment,
                decoration: const InputDecoration(
                  labelText: 'Forma de pagamento',
                ),
                items: const [
                  DropdownMenuItem(value: 'pix', child: Text('Pix')),
                  DropdownMenuItem(value: 'dinheiro', child: Text('Dinheiro')),
                  DropdownMenuItem(value: 'credito', child: Text('Crédito')),
                  DropdownMenuItem(value: 'debito', child: Text('Débito')),
                ],
                onChanged: (v) => setState(() {
                  payment = v!;
                  if (payment != 'credito') installments = 1;
                }),
              ),
              const SizedBox(height: 16),
              if (['credito', 'debito'].contains(payment)) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: cards.any((e) => e['id'] == card) ? card : null,
                  decoration: const InputDecoration(labelText: 'Cartão'),
                  items: cards
                      .map(
                        (e) => DropdownMenuItem(
                          value: e['id'].toString(),
                          child: Text(e['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => card = v),
                  validator: (v) => v == null ? 'Selecione um cartão.' : null,
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: accounts.any((e) => e['id'] == account)
                    ? account
                    : null,
                decoration: const InputDecoration(labelText: 'Conta vinculada'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Sem conta vinculada'),
                  ),
                  ...accounts.map(
                    (e) => DropdownMenuItem(
                      value: e['id'].toString(),
                      child: Text(e['name'] as String),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => account = v),
              ),
              if (!income && payment == 'credito') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Parcelas',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Diminuir parcelas',
                      onPressed: installments > 1
                          ? () => setState(() => installments--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$installments x'),
                    IconButton(
                      tooltip: 'Aumentar parcelas',
                      onPressed: installments < 60
                          ? () => setState(() {
                              installments++;
                              recurring = false;
                            })
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                Text(
                  preview,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text(
                  'O mês escolhido define a fatura. Consulte o fechamento do seu cartão ao escolher a competência.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
              if (installments == 1)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repetir todo mês'),
                  subtitle: const Text('Gera ocorrências até o mês atual.'),
                  value: recurring,
                  onChanged: (v) => setState(() => recurring = v),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: coral)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Salvando…' : 'Salvar movimentação'),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirm(
                            context,
                            'Excluir movimentação?',
                            'A série inteira e suas parcelas serão excluídas.',
                          )) {
                            try {
                              await widget.c.repo.deleteMovement(
                                widget.c.user.id,
                                widget.existing!.id,
                              );
                              await widget.c.refresh();
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) message(context, e);
                            }
                          }
                        },
                  child: const Text(
                    'Excluir série',
                    style: TextStyle(color: coral),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
