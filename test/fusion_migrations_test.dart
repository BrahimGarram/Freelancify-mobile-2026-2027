import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Les numéros 13 à 18 ont servi à deux séries différentes (tests / projets).
/// On simule une base de chaque série, puis on l'ouvre avec la version réunie.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  const tablesTests = ['verifications_email', 'demandes_tentative'];
  const tablesProjets = [
    'project_rewards',
    'project_activity',
    'project_comments',
    'project_tasks',
    'projects',
  ];

  late Directory dossier;
  late String chemin;

  setUp(() async {
    await DatabaseHelper.instance.close();
    dossier = await Directory.systemTemp.createTemp('fusion');
    chemin = '${dossier.path}/app.db';
    DatabaseHelper.overridePath = chemin;
  });
  tearDown(() async {
    await DatabaseHelper.instance.close();
    await dossier.delete(recursive: true);
  });

  Future<Set<String>> tables(Database db) async => (await db.query(
    'sqlite_master',
    columns: ['name'],
    where: "type = 'table'",
  )).map((l) => l['name'] as String).toSet();

  Future<Set<String>> colonnes(Database db, String t) async =>
      (await db.rawQuery('PRAGMA table_info($t)'))
          .map((l) => l['name'] as String)
          .toSet();

  /// Un client, un freelancer, et une candidature acceptée
  Future<int> semer(Database db) async {
    final users = UserService();
    final f = await users.insertUser(
      User(
        username: 'sami',
        email: 'f@t.tn',
        password: 'p',
        role: 'freelancer',
      ),
    );
    final c = await users.insertUser(
      User(username: 'imed', email: 'c@t.tn', password: 'p', role: 'client'),
    );
    final p = await db.insert('posts', {
      'client_id': c,
      'titre': 'Un logo',
      'description': 'Un logo pour ma boulangerie',
      'budget': 100,
      'date_creation': '2026-11-01',
    });
    return db.insert('candidatures', {
      'post_id': p,
      'freelancer_id': f,
      'message': 'Bonjour, je suis disponible pour ce travail.',
      'statut': 'acceptee',
      'date_candidature': '2026-11-02',
    });
  }

  Future<Database> rouvrir(int version) async {
    final db = await DatabaseHelper.instance.database;
    await db.execute('PRAGMA user_version = $version');
    await DatabaseHelper.instance.close();
    return DatabaseHelper.instance.database;
  }

  test('nouvelle installation : les deux séries sont là', () async {
    final db = await DatabaseHelper.instance.database;
    expect(await db.getVersion(), 20);
    expect(await tables(db), containsAll([...tablesTests, ...tablesProjets]));
    expect(
      await colonnes(db, 'users'),
      containsAll(['domaines', 'cofeecoins', 'cofeecoins_donnes']),
    );
    expect(await colonnes(db, 'demandes_tentative'), contains('statut'));
    expect(await colonnes(db, 'project_tasks'), contains('review_note'));
  });

  test('base « tests » v15 : reçoit les projets, garde ses données', () async {
    final db = await DatabaseHelper.instance.database;
    final candidature = await semer(db);
    await db.execute('PRAGMA foreign_keys = OFF');
    for (final t in tablesProjets) {
      await db.execute('DROP TABLE $t');
    }
    await db.execute('ALTER TABLE users DROP COLUMN cofeecoins');
    await db.execute('ALTER TABLE users DROP COLUMN cofeecoins_donnes');
    await db.execute('ALTER TABLE demandes_tentative DROP COLUMN statut');

    final apres = await rouvrir(15);
    expect(await apres.getVersion(), 20);
    expect(await tables(apres), containsAll(tablesProjets));
    expect(await colonnes(apres, 'users'), contains('cofeecoins_donnes'));
    expect(await colonnes(apres, 'project_tasks'), contains('work_link'));
    expect(await colonnes(apres, 'demandes_tentative'), contains('statut'));
    expect(await apres.query('users'), hasLength(2));
    // la candidature déjà acceptée devient un projet
    final projets = await apres.query('projects');
    expect(projets.single['candidature_id'], candidature);
  });

  test('base « projets » v18 : reçoit les tests, garde ses données', () async {
    final db = await DatabaseHelper.instance.database;
    await semer(db);
    await db.execute('PRAGMA foreign_keys = OFF');
    for (final t in tablesTests) {
      await db.execute('DROP TABLE $t');
    }
    // aucun projet : le freelancer ou le client a pu le supprimer
    expect(await db.query('projects'), isEmpty);

    final apres = await rouvrir(18);
    expect(await apres.getVersion(), 20);
    expect(await tables(apres), containsAll(tablesTests));
    expect(await colonnes(apres, 'demandes_tentative'), contains('statut'));
    expect(await apres.query('users'), hasLength(2));
    expect(await apres.query('projects'), isEmpty); // rien de recréé
  });
}
