import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'controller.dart';

const mint = Color(0xff86e9bc),
    muted = Color(0xff9cb7a7),
    coral = Color(0xffffb3a4);

const bankColors = <String, Color>{
  'verde': Color(0xff1b9d68),
  'roxo': Color(0xff8b5cf6),
  'laranja': Color(0xffff8a35),
  'azul': Color(0xff2d87ee),
  'rosa': Color(0xffec5aa6),
  'grafite': Color(0xff48545b),
};
const goalTypes = <String, String>{
  'Carro / automóvel': '🚗',
  'Pagar conta': '🧾',
  'Viagem': '✈️',
  'Casa própria': '🏠',
  'Estudos': '🎓',
  'Reserva': '🛟',
  'Outro sonho': '✨',
};
Color bankColor(dynamic value, {Color fallback = mint}) =>
    bankColors[value?.toString()] ?? fallback;
String goalEmoji(dynamic type) => goalTypes[type?.toString()] ?? '🎯';
String money(int cents) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(cents / 100);
String amountInput(int cents) =>
    (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
String monthLabel(DateTime date) =>
    DateFormat('MMMM yyyy', 'pt_BR').format(date);
void message(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('FormatException: ', '')),
      ),
    );
Future<bool> confirm(BuildContext context, String title, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xff13271c),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xff254332)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class Fold extends StatelessWidget {
  final FinanceController c;
  final String id, title;
  final IconData icon;
  final List<Widget> children;
  final bool initial;
  const Fold({
    super.key,
    required this.c,
    required this.id,
    required this.title,
    required this.icon,
    required this.children,
    this.initial = false,
  });
  @override
  Widget build(BuildContext context) => Panel(
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      key: ValueKey('$id:${c.folds[id] ?? initial}'),
      initiallyExpanded: c.folds[id] ?? initial,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(icon, color: mint, size: 21),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      trailing: Icon(
        (c.folds[id] ?? initial) ? Icons.remove : Icons.add,
        color: muted,
        size: 20,
      ),
      onExpansionChanged: (v) => c.setFold(id, v),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: children,
    ),
  );
}

class Empty extends StatelessWidget {
  final String text;
  const Empty(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: muted, height: 1.5),
    ),
  );
}
