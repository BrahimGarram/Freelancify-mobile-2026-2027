import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/test_competences.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/services/certificat_pdf.dart';
import 'package:sae2_brahim/services/test_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // polices du PDF
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  final users = UserService();
  late TestService service;
  late int freelancer;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
    service = TestService(random: Random(42));
    freelancer = await users.insertUser(
      User(
        username: 'sami',
        email: 's@t.tn',
        password: 'p',
        role: 'freelancer',
      ),
    );
    await users.updateProfil(
      id: freelancer,
      username: 'sami',
      email: 's@t.tn',
      metier: 'Développeur web',
    );
  });
  tearDown(() => DatabaseHelper.instance.close());

  /// Les positions affichées des bonnes / mauvaises réponses
  Future<Map<int, int>> reponses(Quiz quiz, int nbBonnes) async {
    final db = await DatabaseHelper.instance.database;
    final r = <int, int>{};
    for (var i = 0; i < quiz.questions.length; i++) {
      final q = quiz.questions[i];
      final bonne =
          (await db.query(
                'test',
                where: 'id = ?',
                whereArgs: [q.id],
              )).first['bonne_reponse']
              as int;
      final posBonne = q.ordre.indexOf(bonne);
      r[q.id] = i < nbBonnes ? posBonne : (posBonne + 1) % 4;
    }
    return r;
  }

  test('table test : 20 questions par domaine, bien formées', () async {
    final dispo = await service.domainesDisponibles();
    expect(dispo.keys, [
      'design',
      'dev',
      'video',
      'photo',
      'redaction',
      'marketing',
      'traduction',
    ]);
    expect(dispo.values.every((n) => n == 20), isTrue);

    final db = await DatabaseHelper.instance.database;
    final lignes = await db.query('test');
    expect(lignes, hasLength(140));
    for (final l in lignes) {
      final choix = {l['choix_a'], l['choix_b'], l['choix_c'], l['choix_d']};
      expect(choix, hasLength(4), reason: '${l['question']}'); // distincts
    }
    // la bonne réponse n'est pas toujours au même endroit
    expect(lignes.map((l) => l['bonne_reponse']).toSet(), {0, 1, 2, 3});
  });

  test('10 questions réparties entre les domaines choisis', () async {
    final quiz = await service.genererQuiz(freelancer, [
      'design',
      'dev',
      'video',
    ]);
    expect(quiz.questions, hasLength(10));
    expect(quiz.questions.map((q) => q.id).toSet(), hasLength(10));
    final parDomaine = <String, int>{};
    for (final q in quiz.questions) {
      parDomaine[q.domaine] = (parDomaine[q.domaine] ?? 0) + 1;
      expect(q.choix, hasLength(4));
    }
    expect(parDomaine.keys.toSet(), {'design', 'dev', 'video'});
    expect(parDomaine.values.toList()..sort(), [3, 3, 4]);
  });

  test('après un échec, le nouveau test a d\'autres questions', () async {
    final q1 = await service.genererQuiz(freelancer, ['design']);
    final r1 = await service.corriger(
      freelancerId: freelancer,
      quiz: q1,
      reponses: await reponses(q1, 2),
    );
    expect(r1.reussi, isFalse);
    expect(r1.certification, isNull);

    final q2 = await service.genererQuiz(freelancer, ['design']);
    final ids1 = q1.questions.map((q) => q.id).toSet();
    final ids2 = q2.questions.map((q) => q.id).toSet();
    expect(ids1.intersection(ids2), isEmpty); // aucune question répétée
  });

  test('score < 50 % : échec, pas de certification', () async {
    final quiz = await service.genererQuiz(freelancer, ['dev']);
    final r = await service.corriger(
      freelancerId: freelancer,
      quiz: quiz,
      reponses: await reponses(quiz, 4),
    );
    expect(r.score, 4);
    expect(r.pourcentage, 40);
    expect(r.reussi, isFalse);
    expect(await service.getCertifications(freelancer), isEmpty);
    expect((await service.getTentatives(freelancer)).single.reussi, isFalse);
    expect(r.corrections.where((c) => !c.correcte), hasLength(6));
  });

  test('score de 50 % : réussi et certification délivrée', () async {
    final quiz = await service.genererQuiz(freelancer, ['dev', 'design']);
    final r = await service.corriger(
      freelancerId: freelancer,
      quiz: quiz,
      reponses: await reponses(quiz, 5),
    );
    expect(r.pourcentage, 50);
    expect(r.reussi, isTrue);

    final c = (await service.getCertifications(freelancer)).single;
    expect(c.nomFreelancer, 'sami');
    expect(c.metier, 'Développeur web');
    expect(c.domaines, ['dev', 'design']);
    expect(c.domainesLisibles, 'Développement, Design');
    expect(c.competences, contains('Développement'));
    expect(c.competences, contains('Design'));
    expect(c.score, 5);
    expect(c.mention, 'Passable');
    expect(c.numero, matches(RegExp(r'^FRL-\d{4}-[A-Z2-9]{6}$')));
    expect(await service.domainesCertifies(freelancer), {
      'dev': 50,
      'design': 50,
    });
  });

  test('10/10 : mention Excellent', () async {
    final quiz = await service.genererQuiz(freelancer, ['photo']);
    final r = await service.corriger(
      freelancerId: freelancer,
      quiz: quiz,
      reponses: await reponses(quiz, 10),
    );
    expect(r.pourcentage, 100);
    expect(r.certification!.mention, 'Excellent');
    expect(r.parDomaine['photo'], (bonnes: 10, total: 10));
  });

  test('contrôle de saisie', () async {
    expect(TestService.validerDomaines([]), isNotNull);
    expect(TestService.validerDomaines(['inconnu']), isNotNull);
    expect(TestService.validerDomaines(['dev', 'dev']), isNotNull);
    expect(TestService.validerDomaines(['dev']), isNull);

    // temps écoulé : une question sans réponse compte comme fausse
    final quiz = await service.genererQuiz(freelancer, ['video']);
    final incomplet = await reponses(quiz, 10)
      ..remove(quiz.questions.first.id);
    final r = await service.corriger(
      freelancerId: freelancer,
      quiz: quiz,
      reponses: incomplet,
    );
    expect(r.score, 9);
    expect(r.corrections.first.sansReponse, isTrue);
    expect(r.corrections.first.correcte, isFalse);
    await expectLater(
      service.corriger(
        freelancerId: freelancer,
        quiz: quiz,
        reponses: {quiz.questions.first.id: 7},
      ),
      throwsA(isA<TestException>()),
    );

    // réservé aux freelancers
    final client = await users.insertUser(
      User(username: 'imed', email: 'i@t.tn', password: 'p', role: 'client'),
    );
    await expectLater(
      service.genererQuiz(client, ['dev']),
      throwsA(isA<TestException>()),
    );
  });

  test('les domaines du 1er test sont fixés sur le profil', () async {
    expect(await service.domainesProfil(freelancer), isEmpty);
    await service.genererQuiz(freelancer, ['dev', 'design']);
    expect(await service.domainesProfil(freelancer), ['dev', 'design']);
    expect((await users.getUserById(freelancer))!.domaines, ['dev', 'design']);

    // même domaines (ordre libre) : OK ; autres domaines : refusé
    await service.genererQuiz(freelancer, ['design', 'dev']);
    for (final autres in [
      ['dev'],
      ['photo'],
      ['dev', 'design', 'video'],
    ]) {
      await expectLater(
        service.genererQuiz(freelancer, autres),
        throwsA(isA<TestException>()),
        reason: '$autres',
      );
    }
    // modifier le profil ne touche pas aux domaines
    await users.updateProfil(
      id: freelancer,
      username: 'sami2',
      email: 's@t.tn',
      bio: 'Bonjour',
    );
    expect(await service.domainesProfil(freelancer), ['dev', 'design']);
  });

  test('chaque question a une durée (20 à 60 s)', () async {
    final quiz = await service.genererQuiz(freelancer, ['marketing']);
    for (final q in quiz.questions) {
      expect(q.duree, inInclusiveRange(20, 60));
      expect(q.duree % 5, 0);
    }
    expect(DatabaseHelper.dureeQuestion('Court ?', ['a', 'b', 'c', 'd']), 20);
    expect(DatabaseHelper.dureeQuestion('x' * 900, ['a', 'b', 'c', 'd']), 60);
  });

  test('certifié seulement après un test réussi (pour postuler)', () async {
    expect(await service.estCertifie(freelancer), isFalse);
    final q1 = await service.genererQuiz(freelancer, ['dev']);
    await service.corriger(
      freelancerId: freelancer,
      quiz: q1,
      reponses: await reponses(q1, 3),
    );
    expect(await service.estCertifie(freelancer), isFalse);
    final q2 = await service.genererQuiz(freelancer, ['dev']);
    await service.corriger(
      freelancerId: freelancer,
      quiz: q2,
      reponses: await reponses(q2, 8),
    );
    expect(await service.estCertifie(freelancer), isTrue);
  });

  test('certificat PDF : généré et téléchargé', () async {
    final quiz = await service.genererQuiz(freelancer, ['traduction']);
    final c = (await service.corriger(
      freelancerId: freelancer,
      quiz: quiz,
      reponses: await reponses(quiz, 9),
    )).certification!;
    final octets = await CertificatPdf.generer(c);
    expect(String.fromCharCodes(octets.take(5)), '%PDF-');
    expect(octets.length, greaterThan(1000));

    final dossier = await Directory.systemTemp.createTemp('certif');
    addTearDown(() => dossier.delete(recursive: true));
    final chemin = await CertificatPdf.telecharger(c, dossier: dossier);
    expect(chemin, endsWith('certificat-${c.numero}.pdf'));
    expect(await File(chemin).length(), octets.length);
  });
}
