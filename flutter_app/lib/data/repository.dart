import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/finance.dart';
import 'backup.dart';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';

Future<String> derivePassword(Map<String, dynamic> job) async {
  final key =
      await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 210000,
        bits: 256,
      ).deriveKey(
        secretKey: SecretKey(utf8.encode(job['password'] as String)),
        nonce: List<int>.from(job['salt']),
      );
  return base64Encode(await key.extractBytes());
}

class LocalUser {
  final String id, name, email;
  const LocalUser(this.id, this.name, this.email);
  factory LocalUser.row(Map<String, Object?> r) =>
      LocalUser(r['id'] as String, r['name'] as String, r['email'] as String);
}

class Repository {
  final Database db;
  Repository._(this.db);
  static Future<Repository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final location =
        path ?? '${await f.getDatabasesPath()}/centavus_flutter.db';
    return Repository._(
      await f.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: 2,
          onUpgrade: (db, old, next) async {
            if (old < 2) {
              await db.execute(
                "ALTER TABLE entries ADD COLUMN description TEXT NOT NULL DEFAULT ''",
              );
              for (final row in await db.query('entries')) {
                final payload = jsonDecode(row['payload'] as String);
                await db.update(
                  'entries',
                  {'description': payload['description']},
                  where: 'user=? AND id=?',
                  whereArgs: [row['user'], row['id']],
                );
              }
            }
          },
          onCreate: (db, v) async {
            await db.execute(
              'CREATE TABLE users(id TEXT PRIMARY KEY,name TEXT NOT NULL,email TEXT UNIQUE NOT NULL,salt TEXT NOT NULL,hash TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE plans(user TEXT NOT NULL,id TEXT NOT NULL,payload TEXT NOT NULL,recurring INTEGER NOT NULL,PRIMARY KEY(user,id))',
            );
            await db.execute(
              'CREATE TABLE entries(user TEXT NOT NULL,id TEXT NOT NULL,plan TEXT NOT NULL,month TEXT NOT NULL,date TEXT NOT NULL,cents INTEGER NOT NULL,category TEXT NOT NULL,account TEXT,card TEXT,payment TEXT NOT NULL,advanced INTEGER NOT NULL,description TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(user,id))',
            );
            await db.execute(
              'CREATE INDEX entries_month ON entries(user,month,date)',
            );
            await db.execute(
              'CREATE INDEX entries_account ON entries(user,account)',
            );
            await db.execute(
              'CREATE TABLE entities(user TEXT NOT NULL,type TEXT NOT NULL,id TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(user,type,id))',
            );
          },
        ),
      ),
    );
  }

  Future<void> close() => db.close();
  Future<String> _derive(String password, List<int> salt) async {
    return compute(derivePassword, {'password': password, 'salt': salt});
  }

  Future<LocalUser> register(String name, String email, String password) async {
    email = email.trim().toLowerCase();
    name = name.trim();
    if (name.isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        password.length < 8) {
      throw const FormatException(
        'Informe nome, e-mail válido e senha com pelo menos 8 caracteres.',
      );
    }
    final salt = List.generate(24, (_) => Random.secure().nextInt(256));
    final hash = await _derive(password, salt), id = newId();
    try {
      await db.insert('users', {
        'id': id,
        'name': name,
        'email': email,
        'salt': base64Encode(salt),
        'hash': hash,
      });
    } on DatabaseException {
      throw const FormatException('E-mail já cadastrado neste aparelho.');
    }
    return LocalUser(id, name, email);
  }

  Future<LocalUser> login(String email, String password) async {
    final rows = await db.query(
      'users',
      where: 'email=?',
      whereArgs: [email.trim().toLowerCase()],
    );
    if (rows.isEmpty) {
      throw const FormatException('E-mail ou senha incorretos.');
    }
    final r = rows.first,
        actual = base64Decode(
          await _derive(password, base64Decode(r['salt'] as String)),
        ),
        expected = base64Decode(r['hash'] as String);
    var diff = actual.length ^ expected.length;
    for (var i = 0; i < actual.length && i < expected.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    if (diff != 0) throw const FormatException('E-mail ou senha incorretos.');
    return LocalUser.row(r);
  }

  Future<void> remember(LocalUser? u) async {
    if (u == null) {
      await db.delete('settings', where: 'key=?', whereArgs: ['session']);
    } else {
      await db.insert('settings', {
        'key': 'session',
        'value': u.id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<LocalUser?> session() async {
    final rows = await db.rawQuery(
      "SELECT users.* FROM users JOIN settings ON settings.value=users.id WHERE settings.key='session'",
    );
    return rows.isEmpty ? null : LocalUser.row(rows.first);
  }

  Future<void> changePassword(LocalUser u, String old, String next) async {
    if (next.length < 8) {
      throw const FormatException('Use pelo menos 8 caracteres.');
    }
    await login(u.email, old);
    final salt = List.generate(24, (_) => Random.secure().nextInt(256));
    await db.update(
      'users',
      {'salt': base64Encode(salt), 'hash': await _derive(next, salt)},
      where: 'id=?',
      whereArgs: [u.id],
    );
  }

  Future<String?> profilePhoto(String userId) async {
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key=?',
      whereArgs: ['profile-photo:$userId'],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<LocalUser> updateProfile(
    LocalUser user, {
    required String name,
    String? avatarBase64,
  }) async {
    name = name.trim();
    if (name.length < 2 || name.length > 50) {
      throw const FormatException('Use um nome entre 2 e 50 caracteres.');
    }
    if (avatarBase64 != null && avatarBase64.length > 1400000) {
      throw const FormatException('Escolha uma foto menor que 1 MB.');
    }
    await db.transaction((tx) async {
      await tx.update(
        'users',
        {'name': name},
        where: 'id=?',
        whereArgs: [user.id],
      );
      if (avatarBase64 == null) {
        await tx.delete(
          'settings',
          where: 'key=?',
          whereArgs: ['profile-photo:${user.id}'],
        );
      } else {
        await tx.insert('settings', {
          'key': 'profile-photo:${user.id}',
          'value': avatarBase64,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return LocalUser(user.id, name, user.email);
  }

  Future<void> _writePlan(DatabaseExecutor db, String user, Movement t) async {
    if (t.description.trim().isEmpty ||
        t.cents == 0 ||
        t.cents.abs() > 9000000000000 ||
        t.date.year < 1900 ||
        t.date.year > 2200 ||
        t.recurring && t.installments > 1) {
      throw const FormatException('Movimentação inválida.');
    }
    await db.insert('plans', {
      'user': user,
      'id': t.id,
      'payload': jsonEncode(t.toJson()),
      'recurring': t.recurring ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.delete(
      'entries',
      where: 'user=? AND plan=?',
      whereArgs: [user, t.id],
    );
    final parts = t.parts();
    if (t.recurring) {
      final now = DateTime.now(),
          first = t.recurringFrom ?? addMonths(t.date, 1),
          currentMonth = DateTime(now.year, now.month);
      if (!first.isAfter(currentMonth)) {
        final count = max(
          0,
          (now.year - first.year) * 12 + now.month - first.month,
        );
        for (var i = 0; i <= min(count, 3600); i++) {
          final occurrence = addMonths(first, i);
          parts.add(
            Movement(
              id: '${t.id}:r${isoDate(occurrence)}',
              description: t.description,
              cents: t.cents,
              date: occurrence,
              category: t.category,
              payment: t.payment,
              accountId: t.accountId,
              cardId: t.cardId,
            ),
          );
        }
      }
    }
    for (final p in parts) {
      await db.insert('entries', {
        'user': user,
        'id': p.id,
        'plan': t.id,
        'month': monthKey(p.date),
        'date': isoDate(p.date),
        'cents': p.cents,
        'category': p.category,
        'account': p.accountId,
        'card': p.cardId,
        'payment': p.payment,
        'advanced': p.advanced.isNotEmpty ? 1 : 0,
        'payload': jsonEncode(p.toJson()),
        'description': p.description,
      });
    }
  }

  Future<void> saveMovement(String user, Movement t) =>
      db.transaction((tx) => _writePlan(tx, user, t));
  Future<void> refreshRecurring(String user) async {
    final rows = await db.query(
      'plans',
      where: 'user=? AND recurring=1',
      whereArgs: [user],
    );
    if (rows.isEmpty) return;
    await db.transaction((tx) async {
      for (final row in rows) {
        await _writePlan(
          tx,
          user,
          Movement.fromJson(jsonDecode(row['payload'] as String)),
        );
      }
    });
  }

  Future<void> refreshReserve(String user) async {
    final reserves = await entities(user, 'reserve');
    if (reserves.isEmpty) return;
    final before = reserves.first,
        after = accrueReserve(before, DateTime.now());
    if (before['lastYieldAt'] != after['lastYieldAt']) {
      await putEntity(user, 'reserve', after);
    }
  }

  Future<void> deleteMovement(String user, String id) => db.transaction((
    tx,
  ) async {
    await tx.delete(
      'entries',
      where: 'user=? AND plan=?',
      whereArgs: [user, id],
    );
    await tx.delete('plans', where: 'user=? AND id=?', whereArgs: [user, id]);
  });
  Future<Movement> plan(String user, String id) async {
    final rows = await db.query(
      'plans',
      where: 'user=? AND id=?',
      whereArgs: [user, id],
    );
    return Movement.fromJson(jsonDecode(rows.single['payload'] as String));
  }

  Future<List<Map<String, dynamic>>> movements(
    String user,
    DateTime month, {
    int offset = 0,
    int limit = 50,
    String query = '',
  }) async {
    final rows = await db.query(
      'entries',
      where:
          'user=? AND month=? AND (instr(lower(description),lower(?))>0 OR instr(lower(category),lower(?))>0)',
      whereArgs: [user, monthKey(month), query, query],
      orderBy: 'date DESC,id DESC',
      limit: limit,
      offset: offset,
    );
    return rows
        .map(
          (r) => {
            ...jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            'planId': r['plan'],
          },
        )
        .toList();
  }

  Future<MonthSummary> summary(String user, DateTime month) async {
    final r = (await db.rawQuery(
      'SELECT COALESCE(SUM(CASE WHEN cents>0 THEN cents ELSE 0 END),0) income,COALESCE(SUM(CASE WHEN cents<0 THEN -cents ELSE 0 END),0) expense FROM entries WHERE user=? AND month=?',
      [user, monthKey(month)],
    )).single;
    var income = r['income'] as int;
    for (final item in await entities(user, 'investments')) {
      final start = DateTime.parse(item['start'] as String),
          elapsed = (month.year - start.year) * 12 + month.month - start.month;
      if (elapsed >= 0 && elapsed < (item['months'] as int? ?? 12)) {
        income += item['value'] as int;
      }
    }
    return MonthSummary(income, r['expense'] as int);
  }

  Future<int> balance(String user, DateTime month) async {
    final r = (await db.rawQuery(
      'SELECT COALESCE(SUM(cents),0) total FROM entries WHERE user=? AND month<=?',
      [user, monthKey(month)],
    )).single;
    var total = r['total'] as int;
    for (final item in await entities(user, 'investments')) {
      final start = DateTime.parse(item['start'] as String),
          count = max(
            0,
            min(
              item['months'] as int? ?? 12,
              (month.year - start.year) * 12 + month.month - start.month + 1,
            ),
          );
      total += count * (item['value'] as int);
    }
    final reserve = await entities(user, 'reserve');
    return total + (reserve.isEmpty ? 0 : reserve.first['balance'] as int);
  }

  Future<List<Map<String, dynamic>>> entities(String user, String type) async =>
      (await db.query(
            'entities',
            where: 'user=? AND type=?',
            whereArgs: [user, type],
            orderBy: 'id',
          ))
          .map(
            (r) =>
                Map<String, dynamic>.from(jsonDecode(r['payload'] as String)),
          )
          .toList();
  Future<void> putEntity(
    String user,
    String type,
    Map<String, dynamic> value,
  ) => db
      .insert('entities', {
        'user': user,
        'type': type,
        'id': value['id'].toString(),
        'payload': jsonEncode(value),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<void> deleteEntity(String user, String type, String id) async {
    if (type == 'accounts') {
      final refs = await db.rawQuery(
        'SELECT COUNT(*) n FROM entries WHERE user=? AND account=?',
        [user, id],
      );
      final transfers = await entities(user, 'transfers');
      if ((refs.single['n'] as int) > 0 ||
          transfers.any((t) => t['from'] == id || t['to'] == id)) {
        throw const FormatException(
          'Conta possui movimentações ou transferências.',
        );
      }
    }
    if (type == 'cards') {
      final refs = await db.rawQuery(
        'SELECT COUNT(*) n FROM entries WHERE user=? AND card=?',
        [user, id],
      );
      if ((refs.single['n'] as int) > 0) {
        throw const FormatException('Cartão possui compras vinculadas.');
      }
    }
    await db.delete(
      'entities',
      where: 'user=? AND type=? AND id=?',
      whereArgs: [user, type, id],
    );
  }

  Future<int> accountBalance(String user, String id, {DateTime? month}) async {
    final cutoff = monthKey(month ?? DateTime.now());
    final account = (await entities(
      user,
      'accounts',
    )).where((a) => a['id'].toString() == id).first;
    final r = (await db.rawQuery(
      'SELECT COALESCE(SUM(cents),0) total FROM entries WHERE user=? AND account=? AND month<=?',
      [user, id, cutoff],
    )).single;
    var total = (account['initial'] as int? ?? 0) + (r['total'] as int);
    for (final t in await entities(user, 'transfers')) {
      if ((t['date'] as String).substring(0, 7).compareTo(cutoff) > 0) continue;
      if (t['from'] == id) total -= t['value'] as int;
      if (t['to'] == id) total += t['value'] as int;
    }
    return total;
  }

  Future<void> transfer(
    String user,
    String from,
    String to,
    int cents,
    DateTime date,
  ) async {
    final ids = (await entities(
      user,
      'accounts',
    )).map((e) => e['id'].toString()).toSet();
    if (from == to || !ids.contains(from) || !ids.contains(to) || cents <= 0) {
      throw const FormatException(
        'Selecione contas diferentes e um valor positivo.',
      );
    }
    await putEntity(user, 'transfers', {
      'id': newId(),
      'from': from,
      'to': to,
      'value': cents,
      'date': isoDate(date),
    });
  }

  Future<int> invoice(String user, String card, DateTime month) =>
      _invoice(db, user, card, month);
  Future<int> _invoice(
    DatabaseExecutor executor,
    String user,
    String card,
    DateTime month,
  ) async {
    final r = (await executor.rawQuery(
      "SELECT COALESCE(SUM(-cents),0) total FROM entries WHERE user=? AND card=? AND month=? AND payment='credito' AND cents<0 AND advanced=0",
      [user, card, monthKey(month)],
    )).single;
    var total = r['total'] as int;
    final cards =
        (await executor.query(
              'entities',
              where: 'user=? AND type=?',
              whereArgs: [user, 'cards'],
            ))
            .map(
              (e) =>
                  Map<String, dynamic>.from(jsonDecode(e['payload'] as String)),
            )
            .where((e) => e['id'].toString() == card);
    if (cards.isNotEmpty) {
      final c = cards.first;
      if ((c['openingMonth'] ?? monthKey(DateTime.now())) == monthKey(month)) {
        total = max(total, c['fatura'] as int? ?? 0);
      }
    }
    final payments =
        (await executor.query(
              'entities',
              where: 'user=? AND type=?',
              whereArgs: [user, 'payments'],
            ))
            .map(
              (e) =>
                  Map<String, dynamic>.from(jsonDecode(e['payload'] as String)),
            )
            .where((e) => e['cardId'] == card && e['month'] == monthKey(month))
            .fold<int>(0, (s, e) => s + (e['cents'] as int));
    return max(0, total - payments);
  }

  Future<void> payInvoice(String user, String card, DateTime month) =>
      db.transaction((tx) async {
        final due = await _invoice(tx, user, card, month);
        if (due == 0) return;
        final data = {
          'id': newId(),
          'cardId': card,
          'month': monthKey(month),
          'cents': due,
          'date': isoDate(DateTime.now()),
        };
        await tx.insert('entities', {
          'user': user,
          'type': 'payments',
          'id': data['id'],
          'payload': jsonEncode(data),
        });
      });

  Future<Map<String, int>> categories(String user, DateTime month) async {
    final rows = await db.rawQuery(
      'SELECT category,SUM(-cents) total FROM entries WHERE user=? AND month=? AND cents<0 GROUP BY category ORDER BY total DESC',
      [user, monthKey(month)],
    );
    return {for (final r in rows) r['category'] as String: r['total'] as int};
  }

  Future<String> exportBackup(String user) async {
    final plans = await db.query('plans', where: 'user=?', whereArgs: [user]);
    final rows = await db.query('entities', where: 'user=?', whereArgs: [user]);
    final groups = <String, List<dynamic>>{};
    for (final r in rows) {
      (groups[r['type'] as String] ??= []).add(
        jsonDecode(r['payload'] as String),
      );
    }
    return jsonEncode({
      'app': 'Centavus',
      'version': 4,
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': plans
          .map((r) => jsonDecode(r['payload'] as String))
          .toList(),
      'entities': groups,
    });
  }

  Future<void> restoreBackup(String user, String source) async =>
      restoreDecoded(user, decodeBackup(source));
  Future<void> restoreDecoded(String user, Map<String, dynamic> data) =>
      db.transaction((tx) async {
        for (final table in ['entries', 'plans', 'entities']) {
          await tx.delete(table, where: 'user=?', whereArgs: [user]);
        }
        for (final j in data['transactions'] as List) {
          await _writePlan(
            tx,
            user,
            Movement.fromJson(Map<String, dynamic>.from(j)),
          );
        }
        for (final group in (data['entities'] as Map).entries) {
          for (final j in group.value as List) {
            await tx.insert('entities', {
              'user': user,
              'type': group.key,
              'id': j['id'].toString(),
              'payload': jsonEncode(j),
            });
          }
        }
      });
}
