import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/post.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/services/password_hasher.dart';
import 'package:sae2_brahim/services/post_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final users = UserService();
  final posts = PostService();
  final now = DateTime(2026, 1, 1).toIso8601String();

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
  });

  tearDown(() => DatabaseHelper.instance.close());

  Future<int> creerClient() => users.insertUser(
    User(
      username: 'c',
      email: 'c@test.com',
      password: 'pass1234',
      role: 'client',
    ),
  );

  test('un post avec tous les nouveaux champs est bien enregistré', () async {
    final client = await creerClient();
    await posts.insertPost(
      Post(
        clientId: client,
        titre: 'Montage vidéo',
        description: "Montage d'une vidéo de 3 minutes",
        categories: ['video', 'design'],
        budget: 25,
        typeBudget: 'horaire',
        dateLimite: '2026-12-15',
        modeTravail: 'hybride',
        ville: 'Sousse',
        competences: ['Premiere Pro', 'After Effects'],
        urgent: true,
        dateCreation: now,
      ),
    );
    final post = (await posts.getPostsOuverts()).single;
    expect(post.categories, ['video', 'design']);
    expect(post.estHoraire, isTrue);
    expect(post.dateLimite, '2026-12-15');
    expect(post.modeTravail, 'hybride');
    expect(post.ville, 'Sousse');
    expect(post.competences, ['Premiere Pro', 'After Effects']);
    expect(post.urgent, isTrue);
    expect(post.clientUsername, 'c');
  });

  test('la base refuse une valeur hors liste (CHECK)', () async {
    final client = await creerClient();
    final map = Post(
      clientId: client,
      titre: 'Titre',
      description: 'Description',
      budget: 10,
      dateCreation: now,
    ).toMap()..['mode_travail'] = 'lune';
    final db = await DatabaseHelper.instance.database;
    expect(() => db.insert('posts', map), throwsA(isA<DatabaseException>()));
  });

  test('migration v3 → v4 : les anciens posts sont conservés', () async {
    final dir = await Directory.systemTemp.createTemp('sae2_test');
    final path = p.join(dir.path, 'v3.db');

    // Base "version 3" : posts sans les nouvelles colonnes
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE, password TEXT NOT NULL,
            role TEXT NOT NULL)''');
          await db.execute('''CREATE TABLE posts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL, titre TEXT NOT NULL,
            description TEXT NOT NULL, budget REAL NOT NULL,
            statut TEXT NOT NULL DEFAULT 'ouvert',
            date_creation TEXT NOT NULL)''');
          await db.execute('''CREATE TABLE candidatures (
            id INTEGER PRIMARY KEY AUTOINCREMENT, post_id INTEGER NOT NULL,
            freelancer_id INTEGER NOT NULL, message TEXT NOT NULL,
            statut TEXT NOT NULL DEFAULT 'en_attente',
            date_candidature TEXT NOT NULL)''');
          await db.insert('users', {
            'username': 'old',
            'email': 'old@test.com',
            'password': PasswordHasher.hash('x'),
            'role': 'client',
          });
          await db.insert('posts', {
            'client_id': 1,
            'titre': 'Ancien post',
            'description': 'Description',
            'budget': 100,
            'date_creation': now,
          });
        },
      ),
    );
    await old.close();

    DatabaseHelper.overridePath = path;
    final post = (await posts.getPostsOuverts()).single;
    expect(post.titre, 'Ancien post');
    expect(post.budget, 100);
    expect(post.categories, ['autre']);
    expect(post.typeBudget, 'fixe');
    expect(post.modeTravail, 'distance');
    expect(post.competences, isEmpty);
    expect(post.urgent, isFalse);
    expect(post.dateLimite, isNull);

    await DatabaseHelper.instance.close();
    await dir.delete(recursive: true);
  });
}
