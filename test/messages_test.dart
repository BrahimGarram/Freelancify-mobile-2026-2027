import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/candidature.dart';
import 'package:sae2_brahim/models/post.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/messages/chat_screen.dart';
import 'package:sae2_brahim/services/candidature_service.dart';
import 'package:sae2_brahim/services/message_service.dart';
import 'package:sae2_brahim/services/post_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sae2_brahim/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  // version sans isolate : fonctionne aussi dans les tests d'écran
  databaseFactory = databaseFactoryFfiNoIsolate;

  final users = UserService();
  final posts = PostService();
  final candidatures = CandidatureService();
  final messages = MessageService();
  final now = DateTime.now().toIso8601String();
  const texteCandidature = 'Bonjour, je suis graphiste depuis 5 ans.';

  late int client, freelancer, autre, candidatureId;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;

    Future<int> creer(String nom, String role) => users.insertUser(
      User(
        username: nom,
        email: '$nom@test.com',
        password: 'pass1234',
        role: role,
      ),
    );
    client = await creer('client', 'client');
    freelancer = await creer('free', 'freelancer');
    autre = await creer('autre', 'freelancer');
    final postId = await posts.insertPost(
      Post(
        clientId: client,
        titre: 'Logo boulangerie',
        description: 'Un logo moderne',
        budget: 150,
        dateCreation: now,
      ),
    );
    candidatureId = await candidatures.postuler(
      Candidature(
        postId: postId,
        freelancerId: freelancer,
        message: texteCandidature,
        dateCandidature: now,
      ),
    );
  });

  tearDown(() => DatabaseHelper.instance.close());

  test(
    'le message de candidature est le 1er message, non lu par le client',
    () async {
      final liste = await messages.getMessages(candidatureId);
      expect(liste.single.contenu, texteCandidature);
      expect(liste.single.expediteurId, freelancer);

      expect(await messages.nbNonLus(client), 1);
      expect(await messages.nbNonLus(freelancer), 0);

      final convClient = (await messages.getConversations(client)).single;
      expect(convClient.interlocuteur(client), 'free');
      expect(convClient.nbNonLus, 1);
      expect(convClient.dernierMessage, texteCandidature);

      final convFree = (await messages.getConversations(freelancer)).single;
      expect(convFree.interlocuteur(freelancer), 'client');
      expect(await messages.getConversations(autre), isEmpty);
    },
  );

  test('le client répond, le freelancer lit', () async {
    await messages.marquerLus(candidatureId, client);
    expect(await messages.nbNonLus(client), 0);

    await messages.envoyer(
      candidatureId: candidatureId,
      expediteurId: client,
      contenu: '  Merci ! Quel délai ?  ',
    );
    final liste = await messages.getMessages(candidatureId);
    expect(liste.map((m) => m.contenu), [
      texteCandidature,
      'Merci ! Quel délai ?', // espaces retirés
    ]);
    expect(await messages.nbNonLus(freelancer), 1);

    await messages.marquerLus(candidatureId, freelancer);
    expect(await messages.nbNonLus(freelancer), 0);
    expect(
      (await messages.getMessages(candidatureId)).every((m) => m.lu),
      isTrue,
    );
  });

  test(
    'contrôles : message vide, trop long, intrus, discussion fermée',
    () async {
      Future<void> envoyer(int qui, String texte) => messages.envoyer(
        candidatureId: candidatureId,
        expediteurId: qui,
        contenu: texte,
      );

      expect(() => envoyer(client, '   '), throwsA(isA<MessageException>()));
      expect(
        () => envoyer(client, 'a' * 1001),
        throwsA(isA<MessageException>()),
      );
      // un utilisateur qui ne participe pas à la discussion
      expect(() => envoyer(autre, 'Salut'), throwsA(isA<MessageException>()));

      await candidatures.refuserCandidature(candidatureId);
      expect(
        () => envoyer(freelancer, 'Et alors ?'),
        throwsA(isA<MessageException>()),
      );
      // la discussion reste lisible
      expect(await messages.getMessages(candidatureId), hasLength(1));
    },
  );

  test('candidatures reçues par le client', () async {
    final liste = await candidatures.getCandidaturesByClient(client);
    expect(liste.single.freelancerUsername, 'free');
    expect(liste.single.postTitre, 'Logo boulangerie');
    expect(liste.single.message, texteCandidature);
    expect(await candidatures.getCandidaturesByClient(freelancer), isEmpty);
  });

  test(
    'migration v4 → v5 : les anciennes candidatures deviennent un message',
    () async {
      await DatabaseHelper.instance.close();
      final dir = await Directory.systemTemp.createTemp('sae2_test');
      final path = p.join(dir.path, 'v4.db');
      final old = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE users (id INTEGER PRIMARY KEY,
            username TEXT, email TEXT, password TEXT, role TEXT)''');
            await db.execute('''CREATE TABLE posts (id INTEGER PRIMARY KEY,
            client_id INTEGER, titre TEXT, description TEXT, budget REAL,
            statut TEXT, date_creation TEXT)''');
            await db.execute('''CREATE TABLE candidatures (
            id INTEGER PRIMARY KEY, post_id INTEGER, freelancer_id INTEGER,
            message TEXT, statut TEXT, date_candidature TEXT)''');
            await db.insert('users', {
              'id': 1,
              'username': 'c',
              'email': 'c@t.com',
              'password': 'x',
              'role': 'client',
            });
            await db.insert('users', {
              'id': 2,
              'username': 'f',
              'email': 'f@t.com',
              'password': 'x',
              'role': 'freelancer',
            });
            await db.insert('posts', {
              'id': 1,
              'client_id': 1,
              'titre': 'Ancien post',
              'description': 'Description',
              'budget': 100,
              'statut': 'ouvert',
              'date_creation': now,
            });
            await db.insert('candidatures', {
              'id': 7,
              'post_id': 1,
              'freelancer_id': 2,
              'message': 'Ancienne candidature',
              'statut': 'en_attente',
              'date_candidature': now,
            });
          },
        ),
      );
      await old.close();

      DatabaseHelper.overridePath = path;
      final liste = await messages.getMessages(7);
      expect(liste.single.contenu, 'Ancienne candidature');
      expect(liste.single.expediteurId, 2);
      expect(liste.single.lu, isFalse);

      await DatabaseHelper.instance.close();
      await dir.delete(recursive: true);
    },
  );

  testWidgets('écran de discussion : voir le message et répondre', (
    tester,
  ) async {
    final moi = (await tester.runAsync(() => users.getUserById(client)))!;
    final conv = (await tester.runAsync(
      () => messages.getConversation(candidatureId, client),
    ))!;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ChatScreen(user: moi, conversation: conv),
      ),
    );
    // chargement (vraie base) puis affichage
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(find.text(texteCandidature), findsOneWidget);
    expect(find.text('Message de candidature'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget); // client, en attente

    // bouton Envoyer désactivé tant que le champ est vide
    final envoyer = find.widgetWithIcon(IconButton, Icons.send_rounded);
    expect(tester.widget<IconButton>(envoyer).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Super, on en parle ?');
    await tester.pump();
    expect(tester.widget<IconButton>(envoyer).onPressed, isNotNull);

    await tester.tap(envoyer);
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(find.text('Super, on en parle ?'), findsOneWidget);
    final enBase = await tester.runAsync(
      () => messages.getMessages(candidatureId),
    );
    expect(enBase!.last.contenu, 'Super, on en parle ?');
  });
}
