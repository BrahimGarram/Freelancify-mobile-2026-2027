import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/candidature.dart';
import 'package:sae2_brahim/models/post.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/services/candidature_service.dart';
import 'package:sae2_brahim/services/password_hasher.dart';
import 'package:sae2_brahim/services/post_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final users = UserService();
  final posts = PostService();
  final candidatures = CandidatureService();
  final now = DateTime(2026, 1, 1).toIso8601String();

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
  });

  tearDown(() => DatabaseHelper.instance.close());

  Future<int> creerUser(String email, String role) => users.insertUser(
    User(
      username: email.split('@').first,
      email: email,
      password: 'pass1234',
      role: role,
    ),
  );

  test('le mot de passe est stocké haché et la connexion fonctionne', () async {
    await creerUser('a@test.com', 'client');
    final db = await DatabaseHelper.instance.database;
    final stored = (await db.query('users')).first['password'] as String;

    expect(stored, isNot('pass1234'));
    expect(PasswordHasher.isHashed(stored), isTrue);
    expect(await users.login('a@test.com', 'pass1234'), isNotNull);
    expect(await users.login('a@test.com', 'mauvais'), isNull);
    expect(await users.login('inconnu@test.com', 'pass1234'), isNull);
  });

  test(
    'accepter une candidature refuse les autres et passe le post en cours',
    () async {
      final client = await creerUser('c@test.com', 'client');
      final f1 = await creerUser('f1@test.com', 'freelancer');
      final f2 = await creerUser('f2@test.com', 'freelancer');
      final postId = await posts.insertPost(
        Post(
          clientId: client,
          titre: 'Logo',
          description: 'Un logo',
          budget: 100,
          dateCreation: now,
        ),
      );
      final c1 = await candidatures.postuler(
        Candidature(
          postId: postId,
          freelancerId: f1,
          message: 'Moi',
          dateCandidature: now,
        ),
      );
      await candidatures.postuler(
        Candidature(
          postId: postId,
          freelancerId: f2,
          message: 'Moi aussi',
          dateCandidature: now,
        ),
      );

      await candidatures.accepterCandidature(c1);

      final liste = await candidatures.getCandidaturesByPost(postId);
      expect(
        {for (final c in liste) c.id: c.statut},
        {c1: 'acceptee', liste.firstWhere((c) => c.id != c1).id: 'refusee'},
      );
      expect((await posts.getPostsByClient(client)).single.statut, 'en_cours');
      expect(await posts.getPostsOuverts(), isEmpty);
    },
  );

  test(
    'migration v2 → v3 : les anciens mots de passe en clair sont hachés',
    () async {
      final dir = await Directory.systemTemp.createTemp('sae2_test');
      final path = p.join(dir.path, 'old.db');

      // Base "ancienne version" avec un mot de passe en clair
      final old = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL,
                email TEXT NOT NULL UNIQUE, password TEXT NOT NULL,
                role TEXT NOT NULL)''');
            await db.insert('users', {
              'username': 'old',
              'email': 'old@test.com',
              'password': 'ancien123',
              'role': 'client',
            });
          },
        ),
      );
      await old.close();

      DatabaseHelper.overridePath = path;
      final db = await DatabaseHelper.instance.database;
      final stored = (await db.query('users')).first['password'] as String;

      expect(PasswordHasher.isHashed(stored), isTrue);
      expect(await users.login('old@test.com', 'ancien123'), isNotNull);

      await DatabaseHelper.instance.close();
      await dir.delete(recursive: true);
    },
  );

  test('modifier le profil : nom, email et mot de passe', () async {
    final id = await creerUser('a@test.com', 'client');
    await creerUser('b@test.com', 'freelancer');

    // email déjà pris par un autre compte → refusé
    expect(
      () => users.updateProfil(id: id, username: 'a', email: 'b@test.com'),
      throwsA(isA<ProfilException>()),
    );

    // mauvais mot de passe actuel → refusé, rien n'est modifié
    await expectLater(
      users.updateProfil(
        id: id,
        username: 'nouveau',
        email: 'a@test.com',
        motDePasseActuel: 'faux',
        nouveauMotDePasse: 'nouveau123',
      ),
      throwsA(isA<ProfilException>()),
    );
    expect((await users.getUserById(id))!.username, 'a');

    // modification valide
    final u = await users.updateProfil(
      id: id,
      username: 'nouveau',
      email: 'NEW@Test.com',
      motDePasseActuel: 'pass1234',
      nouveauMotDePasse: 'nouveau123',
    );
    expect(u.username, 'nouveau');
    expect(u.email, 'new@test.com');
    expect(await users.login('new@test.com', 'pass1234'), isNull);
    expect(await users.login('new@test.com', 'nouveau123'), isNotNull);

    // garder le même email (le sien) est autorisé
    final u2 = await users.updateProfil(
      id: id,
      username: 'x_y',
      email: 'new@test.com',
    );
    expect(u2.username, 'x_y');
    expect(await users.login('new@test.com', 'nouveau123'), isNotNull);
  });
}
