import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:centavus_flutter/data/repository.dart';
import 'package:centavus_flutter/main.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('login valida e permite cadastro local', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      sqfliteFfiInit();
      final repo = await Repository.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      await tester.pumpWidget(CentavusApp(repository: repo));
      await waitFor(tester, find.text('Acesse sua conta'));
      expect(find.text('Acesse sua conta'), findsOneWidget);
      await tester.tap(find.text('Entrar no Centavus'));
      await tester.pumpAndSettle();
      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      await tester.ensureVisible(find.text('Criar conta'));
      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();
      expect(find.text('Crie sua conta'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await repo.close();
    });
  });
  testWidgets('abre resumo e cria receita funcional', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      sqfliteFfiInit();
      final repo = await Repository.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      late LocalUser user;
      user = await repo.register(
        'Teste',
        'teste@exemplo.com',
        'senha-de-teste',
      );
      await repo.remember(user);
      await tester.pumpWidget(CentavusApp(repository: repo));
      await waitFor(tester, find.text('Movimentação do mês'));
      await waitFor(tester, find.byKey(const Key('add-income')));
      expect(find.text('Movimentação do mês'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-income')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('movement-description')),
        'Salário',
      );
      await tester.enterText(
        find.byKey(const Key('movement-value')),
        '1234,56',
      );
      await tester.ensureVisible(find.text('Salvar movimentação'));
      await tester.tap(find.text('Salvar movimentação'));
      await waitFor(tester, find.text('Movimentação do mês'));
      expect((await repo.summary(user.id, DateTime.now())).income, 123456);
      await tester.pumpWidget(const SizedBox());
      await repo.close();
    });
  });
}
