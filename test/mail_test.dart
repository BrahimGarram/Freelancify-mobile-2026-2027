import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/candidature.dart';
import 'package:sae2_brahim/models/post.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/services/candidature_service.dart';
import 'package:sae2_brahim/services/mail/mail_service.dart';
import 'package:sae2_brahim/services/mail/modeles_email.dart';
import 'package:sae2_brahim/services/post_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Faux envoyeur : enregistre les emails au lieu de les envoyer
class FauxEnvoyeur implements EnvoyeurEmail {
  final List<EmailSortant> envoyes = [];
  EnvoiException? erreur; // si non null : l'envoi échoue
  @override
  bool estConfigure = true;

  @override
  Future<void> envoyer(EmailSortant email) async {
    if (erreur != null) throw erreur!;
    envoyes.add(email);
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  final users = UserService();
  final now = DateTime.now().toIso8601String();
  late FauxEnvoyeur faux;
  late MailService mails;
  late int clientId, freelancerId, postId;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
    faux = FauxEnvoyeur();
    mails = MailService(envoyeur: faux);
    MailService.instance = mails;

    clientId = await users.insertUser(
      User(
        username: 'lina',
        email: 'lina.client@gmail.com',
        password: 'pass1234',
        role: 'client',
      ),
    );
    freelancerId = await users.insertUser(
      User(
        username: 'sami',
        email: 'sami@test.com',
        password: 'pass1234',
        role: 'freelancer',
      ),
    );
    await users.updateProfil(
      id: freelancerId,
      username: 'sami',
      email: 'sami@test.com',
      metier: 'Graphiste',
    );
    postId = await PostService().insertPost(
      Post(
        clientId: clientId,
        titre: 'Logo pour ma pâtisserie',
        description: 'Création du logo de ma pâtisserie à Sousse.',
        budget: 300,
        dateCreation: now,
      ),
    );
  });

  tearDown(() async {
    MailService.instance = MailService();
    await DatabaseHelper.instance.close();
  });

  Future<int> postuler([String message = 'Bonjour, je suis graphiste.']) =>
      CandidatureService().postuler(
        Candidature(
          postId: postId,
          freelancerId: freelancerId,
          message: message,
          dateCandidature: now,
        ),
      );

  /// L'email part en arrière-plan : on attend qu'il soit traité
  Future<void> attendreEnvoi() async {
    for (var i = 0; i < 50 && faux.envoyes.isEmpty; i++) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    await mails.envoyerEnAttente();
  }

  test('postuler envoie un email au client', () async {
    await postuler();
    await attendreEnvoi();

    final email = faux.envoyes.single;
    expect(email.destinataire, 'lina.client@gmail.com');
    expect(
      email.sujet,
      'Nouvelle candidature pour « Logo pour ma pâtisserie »',
    );
    expect(email.texte, contains('Bonjour lina'));
    expect(email.texte, contains('@sami vient de postuler'));
    expect(email.texte, contains('300 DT'));
    expect(email.texte, contains('Graphiste'));
    expect(email.texte, contains('Bonjour, je suis graphiste.'));
    expect(email.html, contains('@sami a postulé'));
    expect(await mails.nbEnAttente(), 0); // parti : retiré de la file
  });

  test('le texte des utilisateurs est échappé dans le HTML', () {
    final e = ModelesEmail.nouvelleCandidature(
      const InfosCandidature(
        clientNom: 'lina',
        clientEmail: 'l@t.tn',
        freelancerNom: 'sami',
        postTitre: 'Titre\r\nBcc: pirate@x.com',
        postBudget: 25,
        horaire: true,
        message: '<script>alert(1)</script>\nligne 2',
      ),
    );
    expect(e.sujet, isNot(contains('\n'))); // pas d'injection d'en-tête
    expect(e.html, isNot(contains('<script>')));
    expect(e.html, contains('&lt;script&gt;'));
    expect(e.html, contains('ligne 2'));
    expect(e.texte, contains('25 DT/h'));
  });

  test(
    'sans réseau : la candidature est enregistrée, l\'email attend',
    () async {
      faux.erreur = const EnvoiException('Pas de connexion', reseau: true);
      final id = await postuler();
      expect(id, greaterThan(0)); // la candidature n'échoue pas
      await mails.envoyerEnAttente();
      expect(faux.envoyes, isEmpty);
      expect(await mails.nbEnAttente(), 1);

      // le réseau revient (ex : au prochain démarrage)
      faux.erreur = null;
      await mails.envoyerEnAttente();
      expect(faux.envoyes, hasLength(1));
      expect(await mails.nbEnAttente(), 0);
    },
  );

  test('mot de passe refusé : abandon après 5 tentatives', () async {
    faux.erreur = const EnvoiException('Gmail refuse la connexion');
    await postuler();
    for (var i = 0; i < 7; i++) {
      await mails.envoyerEnAttente();
    }
    expect(await mails.nbEnAttente(), 0); // abandonné, plus retenté
    final db = await DatabaseHelper.instance.database;
    final ligne = (await db.query('emails_sortants')).single;
    expect(ligne['tentatives'], MailService.tentativesMax);
    expect(ligne['derniere_erreur'], 'Gmail refuse la connexion');
  });

  test('emails désactivés sans mot de passe : rien en file', () async {
    faux.estConfigure = false;
    await postuler();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(await mails.nbEnAttente(), 0);
    expect(faux.envoyes, isEmpty);
  });

  test('adresse du client invalide : pas d\'email', () async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'users',
      {'email': 'pas-un-email'},
      where: 'id = ?',
      whereArgs: [clientId],
    );
    final id = await postuler();
    await mails.notifierNouvelleCandidature(id);
    expect(faux.envoyes, isEmpty);
  });

  test('migration v6 → v7 : la boîte d\'envoi est créée', () async {
    await DatabaseHelper.instance.close();
    final dir = await Directory.systemTemp.createTemp('sae2_mail');
    addTearDown(() async {
      await DatabaseHelper.instance.close();
      await dir.delete(recursive: true);
    });
    final path = p.join(dir.path, 'v6.db');
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, '
          'email TEXT, password TEXT, role TEXT, metier TEXT, bio TEXT)',
        ),
      ),
    );
    await old.close();

    DatabaseHelper.overridePath = path;
    expect(await mails.nbEnAttente(), 0); // la table existe
  });
}
