import 'package:material_ui/material_ui.dart';
import '../data/repository.dart';
import 'common.dart';

class LoginScreen extends StatefulWidget {
  final Repository repository;
  final ValueChanged<LocalUser> onLogin;
  const LoginScreen({
    super.key,
    required this.repository,
    required this.onLogin,
  });
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool registering = false, hidden = true, remember = false, busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final u = registering
          ? await widget.repository.register(
              name.text,
              email.text,
              password.text,
            )
          : await widget.repository.login(email.text, password.text);
      await widget.repository.remember(remember ? u : null);
      if (mounted) widget.onLogin(u);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e.toString().replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [Color(0xff1b3f2c), Color(0xff09150f)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 56),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/logo.jpg',
                              width: 76,
                              height: 76,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Centavus',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SMART FINANCE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 9,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 38),
                        Text(
                          registering
                              ? 'SEU PRÓXIMO PASSO'
                              : 'BEM-VINDO DE VOLTA',
                          style: const TextStyle(
                            color: mint,
                            fontSize: 10,
                            letterSpacing: 1.7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          registering ? 'Crie sua conta' : 'Acesse sua conta',
                          style: const TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (registering) ...[
                          TextFormField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'Seu nome',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Informe seu nome.' : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            hintText: 'voce@email.com',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (v) => v!.trim().isEmpty
                              ? 'Informe seu e-mail.'
                              : !RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(v)
                              ? 'E-mail inválido.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: password,
                          obscureText: hidden,
                          onFieldSubmitted: (_) => busy ? null : submit(),
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            hintText: 'Pelo menos 8 caracteres',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: hidden
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: () => setState(() => hidden = !hidden),
                              icon: Icon(
                                hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) => v!.length < 8
                              ? 'Use pelo menos 8 caracteres.'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: remember,
                              onChanged: (v) => setState(() => remember = v!),
                            ),
                            const Expanded(
                              child: Text(
                                'Lembrar de mim',
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ),
                            if (!registering)
                              TextButton(
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Conta local'),
                                    content: const Text(
                                      'Este app não envia e-mails. A senha pode ser alterada após entrar, nas configurações. Guarde seu backup em um local seguro.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: const Text('Entendi'),
                                      ),
                                    ],
                                  ),
                                ),
                                child: const Text(
                                  'Esqueci a senha',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              error!,
                              style: const TextStyle(color: coral),
                            ),
                          ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          child: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  registering
                                      ? 'Criar minha conta'
                                      : 'Entrar no Centavus',
                                ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  registering = !registering;
                                  error = null;
                                  form.currentState?.reset();
                                }),
                          child: Text(
                            registering ? 'Já tenho conta' : 'Criar conta',
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Seus dados ficam neste aparelho.\nUse o backup para transferir para outro dispositivo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 10,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
