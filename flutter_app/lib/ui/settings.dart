import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../data/backup.dart';
import 'controller.dart';
import 'common.dart';
import 'performance.dart';

class SettingsScreen extends StatefulWidget {
  final FinanceController c;
  final Future<void> Function() onLogout;
  const SettingsScreen({super.key, required this.c, required this.onLogout});
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  bool busy = false;
  Future<void> run(Future<void> Function() job) async {
    setState(() => busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    final backup = await widget.c.repo.exportBackup(widget.c.user.id),
        name =
            'centavus-flutter-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    final bytes = Uint8List.fromList(utf8.encode(backup));
    if (kIsWeb) {
      await FilePicker.platform.saveFile(
        fileName: name,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } else {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/json', name: name),
          ],
          fileNameOverrides: [name],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    }
  }

  Future<void> restore() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (selection == null) return;
    if (selection.files.single.size > 20 * 1024 * 1024) {
      throw const FormatException('Backup maior que 20 MB.');
    }
    final bytes = selection.files.single.bytes;
    if (bytes == null) {
      throw const FormatException('Não foi possível ler o arquivo.');
    }
    final decoded = await compute(decodeBackup, utf8.decode(bytes));
    if (!mounted) return;
    if (!await confirm(
      context,
      'Restaurar backup?',
      'Os dados financeiros da conta atual serão substituídos. O arquivo contém ${(decoded['transactions'] as List).length} movimentações. Exporte uma cópia antes de continuar.',
    )) {
      return;
    }
    await widget.c.repo.restoreDecoded(widget.c.user.id, decoded);
    await widget.c.refresh();
    if (mounted) message(context, 'Backup restaurado.');
  }

  ImageProvider<Object>? avatar(String? value) => value == null
      ? null
      : MemoryImage(Uint8List.fromList(base64Decode(value)));

  String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  Future<void> editProfile() async {
    final name = TextEditingController(text: widget.c.user.name);
    String? photo = widget.c.avatarData;
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, set) => AlertDialog(
          title: const Text('Editar perfil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: mint.withValues(alpha: .2),
                  backgroundImage: avatar(photo),
                  child: photo == null
                      ? Text(
                          initials(name.text),
                          style: const TextStyle(
                            color: mint,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final picked = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                          );
                          final bytes = picked?.files.single.bytes;
                          if (bytes == null) return;
                          if (bytes.length > 1024 * 1024) {
                            set(
                              () => error = 'Escolha uma foto menor que 1 MB.',
                            );
                            return;
                          }
                          set(() {
                            photo = base64Encode(bytes);
                            error = null;
                          });
                        },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Escolher foto'),
                ),
                if (photo != null)
                  TextButton(
                    onPressed: saving ? null : () => set(() => photo = null),
                    child: const Text('Remover foto'),
                  ),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => set(() {}),
                  decoration: const InputDecoration(labelText: 'Seu nome'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'A foto fica salva somente neste aparelho.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(error!, style: const TextStyle(color: coral)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialog),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      set(() => saving = true);
                      try {
                        await widget.c.updateProfile(name.text, photo);
                        if (dialog.mounted) Navigator.pop(dialog);
                      } catch (e) {
                        set(() {
                          saving = false;
                          error = e.toString().replaceFirst(
                            'FormatException: ',
                            '',
                          );
                        });
                      }
                    },
              child: const Text('Salvar perfil'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configurações')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: mint.withValues(alpha: .2),
                    backgroundImage: avatar(widget.c.avatarData),
                    child: widget.c.avatarData == null
                        ? Text(
                            initials(widget.c.user.name),
                            style: const TextStyle(
                              color: mint,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.c.user.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.c.user.email,
                          style: const TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar perfil',
                    onPressed: busy ? null : editProfile,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: busy ? null : editProfile,
                icon: const Icon(Icons.person_outline),
                label: const Text('Editar nome e foto'),
              ),
              const SizedBox(height: 14),
              const Text(
                'Conta local neste aparelho. Não há sincronização automática com outros dispositivos.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.file_download_outlined, color: mint),
          title: const Text('Exportar backup'),
          subtitle: const Text('Salvar ou compartilhar uma cópia JSON'),
          onTap: busy ? null : () => run(export),
        ),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined, color: mint),
          title: const Text('Restaurar backup'),
          subtitle: const Text('Aceita a versão anterior (v3) e Flutter (v4)'),
          onTap: busy ? null : () => run(restore),
        ),
        ListTile(
          leading: const Icon(Icons.password_outlined, color: mint),
          title: const Text('Alterar senha'),
          onTap: busy ? null : () => changePasswordDialog(context, widget.c),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.speed, color: mint),
          title: const Text('Laboratório de desempenho'),
          subtitle: const Text('Dados sintéticos, baseline e versão otimizada'),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const PerformanceScreen()),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Flutter e Dart · SQLite local\nSeus backups contêm dados financeiros. Guarde-os em um local protegido.',
          style: TextStyle(color: muted, fontSize: 11, height: 1.7),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => run(() async {
                  await widget.onLogout();
                  if (context.mounted) Navigator.pop(context);
                }),
          icon: const Icon(Icons.logout),
          label: const Text('Sair da conta'),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    ),
  );
}

Future<void> changePasswordDialog(
  BuildContext context,
  FinanceController c,
) async {
  final old = TextEditingController(), next = TextEditingController();
  String? error;
  bool busy = false;
  await showDialog<void>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, set) => AlertDialog(
        title: const Text('Alterar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: old,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha atual'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nova senha (8+ caracteres)',
              ),
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
                      await c.repo.changePassword(c.user, old.text, next.text);
                      if (dialog.mounted) Navigator.pop(dialog);
                    } catch (e) {
                      set(() {
                        busy = false;
                        error = e.toString();
                      });
                    }
                  },
            child: const Text('Salvar senha'),
          ),
        ],
      ),
    ),
  );
  old.dispose();
  next.dispose();
}
