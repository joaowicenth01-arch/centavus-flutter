import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:centavus_flutter/data/repository.dart';
import 'package:centavus_flutter/domain/finance.dart';

void main() {
  late Repository repo;
  setUp(() async {
    sqfliteFfiInit();
    repo = await Repository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() async {
    await repo.close();
  });
  test('cadastro, senha incorreta e isolamento de usuários', () async {
    final a = await repo.register('Ana', 'ana@teste.com', 'senha12345');
    expect(
      () => repo.login('ana@teste.com', 'errada'),
      throwsA(isA<Exception>()),
    );
    await repo.saveMovement(
      a.id,
      Movement(
        id: 'x',
        description: 'Salário',
        cents: 10000,
        date: DateTime(2026, 11, 1),
      ),
    );
    final b = await repo.register('Bia', 'bia@teste.com', 'senha12345');
    expect(await repo.movements(b.id, DateTime(2026, 11)), isEmpty);
    expect((await repo.summary(a.id, DateTime(2026, 11))).income, 10000);
    expect((await repo.login('ANA@TESTE.COM', 'senha12345')).id, a.id);
    final changed = await repo.updateProfile(
      a,
      name: 'Ana Silva',
      avatarBase64: 'aGVsbG8=',
    );
    expect(changed.name, 'Ana Silva');
    expect(await repo.profilePhoto(a.id), 'aGVsbG8=');
    await repo.updateProfile(changed, name: 'Ana Silva', avatarBase64: null);
    expect(await repo.profilePhoto(a.id), isNull);
  });
  test('parcelas persistidas, editadas em série e restauradas', () async {
    final u = await repo.register('Ana', 'ana@teste.com', 'senha12345');
    await repo.saveMovement(
      u.id,
      Movement(
        id: 'x',
        description: 'Compra',
        cents: -10000,
        date: DateTime(2026, 12, 31),
        installments: 3,
      ),
    );
    expect((await repo.summary(u.id, DateTime(2027, 2))).expense, 3333);
    final backup = await repo.exportBackup(u.id);
    await repo.deleteMovement(u.id, 'x');
    expect((await repo.summary(u.id, DateTime(2027, 2))).expense, 0);
    await repo.restoreBackup(u.id, backup);
    expect((await repo.summary(u.id, DateTime(2027, 2))).expense, 3333);
    expect(
      () => repo.restoreBackup(u.id, '{"transactions":"bad"}'),
      throwsFormatException,
    );
    expect((await repo.summary(u.id, DateTime(2027, 2))).expense, 3333);
  });
  test(
    'transferências não alteram entradas/saídas e pagamento é idempotente',
    () async {
      final u = await repo.register('Ana', 'ana@teste.com', 'senha12345');
      await repo.putEntity(u.id, 'accounts', {
        'id': 'a',
        'name': 'Conta',
        'initial': 10000,
      });
      await repo.putEntity(u.id, 'accounts', {
        'id': 'b',
        'name': 'Carteira',
        'initial': 0,
      });
      await repo.transfer(u.id, 'a', 'b', 2000, DateTime(2026, 11, 2));
      expect(await repo.accountBalance(u.id, 'a'), 8000);
      expect((await repo.summary(u.id, DateTime(2026, 11))).income, 0);
      await repo.saveMovement(
        u.id,
        Movement(
          id: 'c',
          description: 'Compra',
          cents: -1000,
          date: DateTime(2026, 11, 2),
          cardId: 'v',
          payment: 'credito',
        ),
      );
      await repo.payInvoice(u.id, 'v', DateTime(2026, 11));
      expect(await repo.invoice(u.id, 'v', DateTime(2026, 11)), 0);
      await repo.payInvoice(u.id, 'v', DateTime(2026, 11));
      expect((await repo.summary(u.id, DateTime(2026, 11))).expense, 1000);
    },
  );
  test('backup v3 converte valores e parcelas sem perder centavos', () async {
    final u = await repo.register('Ana', 'ana@teste.com', 'senha12345');
    await repo.restoreBackup(
      u.id,
      '{"app":"Centavus","version":3,"transactions":[{"id":1,"desc":"Compra","amount":-33.33,"total":100,"parcelas":3,"iso":"2026-12-31","pay":"credito"}],"accounts":[{"id":1,"name":"Banco","initial":50}]}',
    );
    expect((await repo.summary(u.id, DateTime(2027, 1))).expense, 3333);
    expect(await repo.accountBalance(u.id, '1'), 5000);
  });
  test('backup v3 recorrente não regenera cópias históricas', () async {
    final u = await repo.register('Ana', 'ana@teste.com', 'senha12345');
    final now = DateTime.now(),
        previous = DateTime(now.year, now.month - 1, 1),
        next = DateTime(now.year, now.month + 1, 1);
    await repo.restoreBackup(
      u.id,
      '{"app":"Centavus","version":3,"transactions":[{"id":1,"desc":"Receita","amount":100,"iso":"${previous.toIso8601String().substring(0, 10)}","recorrente":true,"proxIso":"${next.toIso8601String().substring(0, 10)}"},{"id":2,"desc":"Receita","amount":100,"iso":"${DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10)}"}]}',
    );
    expect((await repo.summary(u.id, now)).income, 10000);
    await repo.refreshRecurring(u.id);
    expect((await repo.summary(u.id, now)).income, 10000);
  });
  test(
    'conta respeita o mês e pagamento concorrente não duplica histórico',
    () async {
      final u = await repo.register('Ana', 'ana@teste.com', 'senha12345');
      await repo.putEntity(u.id, 'accounts', {
        'id': 'a',
        'name': 'Banco',
        'initial': 10000,
      });
      await repo.saveMovement(
        u.id,
        Movement(
          id: 'x',
          description: 'Compra futura',
          cents: -3000,
          date: DateTime(2027, 1, 1),
          installments: 3,
          accountId: 'a',
          cardId: 'v',
          payment: 'credito',
        ),
      );
      expect(
        await repo.accountBalance(u.id, 'a', month: DateTime(2026, 12)),
        10000,
      );
      expect(
        await repo.accountBalance(u.id, 'a', month: DateTime(2027, 1)),
        9000,
      );
      await Future.wait([
        repo.payInvoice(u.id, 'v', DateTime(2027, 1)),
        repo.payInvoice(u.id, 'v', DateTime(2027, 1)),
      ]);
      expect((await repo.entities(u.id, 'payments')).length, 1);
    },
  );
}
