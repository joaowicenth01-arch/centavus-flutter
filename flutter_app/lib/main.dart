import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'data/repository.dart';
import 'ui/login.dart';
import 'ui/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repo = await Repository.open(
      factory: kIsWeb ? databaseFactoryFfiWeb : null,
    );
    runApp(CentavusApp(repository: repo));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível abrir o banco local. Reabra o aplicativo. Seus dados não foram apagados.\n$e',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CentavusApp extends StatefulWidget {
  final Repository repository;
  const CentavusApp({super.key, required this.repository});
  @override
  State<CentavusApp> createState() => _AppState();
}

class _AppState extends State<CentavusApp> {
  LocalUser? user;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    widget.repository.session().then((u) {
      if (mounted) {
        setState(() {
          user = u;
          ready = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Centavus',
    debugShowCheckedModeBanner: false,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff70e0b3),
        brightness: Brightness.dark,
        primary: const Color(0xff86e9bc),
        surface: const Color(0xff102019),
      ),
      scaffoldBackgroundColor: const Color(0xff09150f),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff172b20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xff2b4535)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff09150f),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xff102019),
        height: 72,
      ),
    ),
    home: !ready
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : user == null
        ? LoginScreen(
            repository: widget.repository,
            onLogin: (u) => setState(() => user = u),
          )
        : HomeScreen(
            key: ValueKey(user!.id),
            repository: widget.repository,
            user: user!,
            onLogout: () async {
              await widget.repository.remember(null);
              if (mounted) setState(() => user = null);
            },
          ),
  );
}
