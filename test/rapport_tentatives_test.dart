import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/test_competences.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/tests/rapport_ia_carte.dart';
import 'package:sae2_brahim/services/ai/gemini_client.dart';
import 'package:sae2_brahim/services/ai/rapport_test_service.dart';
import 'package:sae2_brahim/services/test_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sae2_brahim/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

http.Response reponseGemini(String texte) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': texte},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    }),
  ),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const rapportJson = {
  'synthese':
      'Tu montres de bonnes bases en design, avec un point à consolider sur '
      'les couleurs.',
  'pointsForts': [
    '**Typographie** : tu choisis des polices lisibles, un atout pour tes logos.',
    'Tu maîtrises la hiérarchie visuelle.',
    'Tu maîtrises la hiérarchie visuelle.', // doublon : retiré
    'Troisième point.',
    'Quatrième point de trop.',
  ],
  'pointsFaibles': [
    '- Contraste : un texte clair sur fond clair reste peu lisible.',
  ],
  'conseils': [
    'Vérifie le contraste de chaque maquette avec un outil dédié.',
    'Refais trois affiches en noir et blanc avant d\'ajouter la couleur.',
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  final users = UserService();
  late TestService service;
  late int freelancer;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
    SharedPreferences.setMockInitialValues({});
    service = TestService(random: Random(7));
    freelancer = await users.insertUser(
      User(
        username: 'sami',
        email: 's@t.tn',
        password: 'p',
        role: 'freelancer',
      ),
    );
  });
  tearDown(() => DatabaseHelper.instance.close());

  /// Réponses : les [nbBonnes] premières justes, les autres fausses
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
      final pos = q.ordre.indexOf(bonne);
      r[q.id] = i < nbBonnes ? pos : (pos + 1) % 4;
    }
    return r;
  }

  Future<ResultatTest> passer(int nbBonnes) async {
    final quiz = await service.genererQuiz(freelancer, ['design']);
    return service.corriger(
      freelancerId: freelancer,
      quiz: quiz,
      reponses: await reponses(quiz, nbBonnes),
    );
  }

  group('tentatives', () {
    test('3 tentatives au maximum', () async {
      expect((await service.etat(freelancer)).restantes, 3);
      expect((await passer(2)).tentativesRestantes, 2);
      expect((await passer(3)).tentativesRestantes, 1);
      final r3 = await passer(4);
      expect(r3.reussi, isFalse);
      expect(r3.tentativesRestantes, 0);

      final e = await service.etat(freelancer);
      expect(e.peutPasser, isFalse);
      expect(e.certifie, isFalse);
      await expectLater(
        service.genererQuiz(freelancer, ['design']),
        throwsA(
          isA<TestException>().having((x) => x.message, 'm', contains('3')),
        ),
      );
    });

    test('un test réussi ne se repasse pas', () async {
      expect((await passer(7)).reussi, isTrue);
      final e = await service.etat(freelancer);
      expect(e.certifie, isTrue);
      expect(e.peutPasser, isFalse);
      await expectLater(
        service.genererQuiz(freelancer, ['design']),
        throwsA(
          isA<TestException>().having(
            (x) => x.message,
            'm',
            contains('déjà réussi'),
          ),
        ),
      );
    });

    test('un test abandonné compte comme une tentative', () async {
      await service.genererQuiz(freelancer, ['design']); // jamais corrigé
      final e = await service.etat(freelancer);
      expect(e.utilisees, 1);
      expect(e.restantes, 2);
      final t = (await service.getTentatives(freelancer)).single;
      expect(t.enCours, isTrue);
      expect(t.reussi, isFalse);
    });

    test('un test ne se corrige qu\'une fois', () async {
      final quiz = await service.genererQuiz(freelancer, ['design']);
      final rep = await reponses(quiz, 3);
      await service.corriger(
        freelancerId: freelancer,
        quiz: quiz,
        reponses: rep,
      );
      await expectLater(
        service.corriger(freelancerId: freelancer, quiz: quiz, reponses: rep),
        throwsA(isA<TestException>()),
      );
      expect((await service.getTentatives(freelancer)).single.score, 3);
    });
  });

  group('rapport de l\'IA', () {
    test('analyse les questions, nettoie et enregistre le rapport', () async {
      final resultat = await passer(6);
      final requetes = <Map<String, dynamic>>[];
      final ia = RapportTestService(
        client: GeminiClient(
          apiKey: 'k',
          modele: 'm',
          client: MockClient((req) async {
            requetes.add(jsonDecode(req.body) as Map<String, dynamic>);
            return reponseGemini(jsonEncode(rapportJson));
          }),
        ),
      );

      final r = await ia.obtenir(
        tentativeId: resultat.tentativeId,
        freelancerId: freelancer,
      );
      // ce qui est envoyé à l'IA : les questions, les réponses, le score
      final envoi =
          requetes.single['contents'][0]['parts'][0]['text'] as String;
      expect(envoi, contains('<resultats>'));
      expect(envoi, contains('Score : 6/10 (60 %)'));
      expect(RegExp('Résultat : CORRECT').allMatches(envoi), hasLength(6));
      expect(RegExp('Résultat : FAUX').allMatches(envoi), hasLength(4));
      expect(envoi, contains('Réponse du freelancer :'));
      expect(envoi, contains(resultat.corrections.first.question.enonce));
      expect(
        requetes.single['generationConfig']['responseMimeType'],
        'application/json',
      );

      // nettoyé : Markdown et puces retirés, doublon retiré, 3 points max
      expect(r.pointsForts, hasLength(3));
      expect(r.pointsForts.last, 'Troisième point.');
      expect(r.pointsForts.first, startsWith('Typographie : tu choisis'));
      expect(r.pointsFaibles.single, startsWith('Contraste'));
      expect(r.conseils, hasLength(2));

      // enregistré : relu sans rappeler l'IA
      final relu = await ia.lire(resultat.tentativeId);
      expect(relu!.synthese, r.synthese);
      await ia.obtenir(
        tentativeId: resultat.tentativeId,
        freelancerId: freelancer,
      );
      expect(requetes, hasLength(1));
    });

    test('réponses sans réponse signalées (temps écoulé)', () async {
      final quiz = await service.genererQuiz(freelancer, ['design']);
      final rep = await reponses(quiz, 10)
        ..remove(quiz.questions.last.id);
      final resultat = await service.corriger(
        freelancerId: freelancer,
        quiz: quiz,
        reponses: rep,
      );
      String? envoi;
      final ia = RapportTestService(
        client: GeminiClient(
          apiKey: 'k',
          modele: 'm',
          client: MockClient((req) async {
            envoi = (jsonDecode(
              req.body,
            ) as Map)['contents'][0]['parts'][0]['text'];
            return reponseGemini(jsonEncode(rapportJson));
          }),
        ),
      );
      await ia.obtenir(
        tentativeId: resultat.tentativeId,
        freelancerId: freelancer,
      );
      expect(envoi, contains('SANS RÉPONSE (temps écoulé)'));
    });

    test('refus : test d\'un autre, test non terminé, rapport vide', () async {
      final ia = RapportTestService(
        client: GeminiClient(
          apiKey: 'k',
          modele: 'm',
          client: MockClient(
            (_) async => reponseGemini(
              jsonEncode({
                'synthese': '',
                'pointsForts': [],
                'pointsFaibles': [],
                'conseils': [],
              }),
            ),
          ),
        ),
      );
      final enCours = await service.genererQuiz(freelancer, ['design']);
      await expectLater(
        ia.obtenir(tentativeId: enCours.tentativeId, freelancerId: freelancer),
        throwsA(isA<RapportException>()),
      );
      await service.corriger(
        freelancerId: freelancer,
        quiz: enCours,
        reponses: await reponses(enCours, 2),
      );
      await expectLater(
        ia.obtenir(tentativeId: enCours.tentativeId, freelancerId: 999),
        throwsA(isA<RapportException>()),
      );
      await expectLater(
        ia.obtenir(tentativeId: enCours.tentativeId, freelancerId: freelancer),
        throwsA(isA<RapportException>()), // incomplet
      );
      expect(await ia.lire(enCours.tentativeId), isNull);
    });

    test('surcharge : nouveaux essais puis modèle de secours', () async {
      final appels = <String>[];
      GeminiClient client(int surchargesAvantSucces) => GeminiClient(
        apiKey: 'k',
        modele: 'principal',
        modeleSecours: 'secours',
        attenteReessai: Duration.zero,
        client: MockClient((req) async {
          final m = req.url.path.contains('principal')
              ? 'principal'
              : 'secours';
          appels.add(m);
          if (m == 'principal' && appels.length <= surchargesAvantSucces) {
            return http.Response('{"error":{"message":"high demand"}}', 503);
          }
          return reponseGemini('ok');
        }),
      );
      Future<String> appeler(GeminiClient c) => c.generer(
        instructions: 'i',
        messages: [GeminiMessage.utilisateur('q')],
      );

      // surcharge passagère : le 2e essai passe
      expect(await appeler(client(1)), 'ok');
      expect(appels, ['principal', 'principal']);

      // toujours surchargé : 3 essais puis le modèle de secours
      appels.clear();
      expect(await appeler(client(99)), 'ok');
      expect(appels, ['principal', 'principal', 'principal', 'secours']);

      // une clé refusée n'est pas réessayée
      appels.clear();
      final refus = GeminiClient(
        apiKey: 'k',
        modele: 'principal',
        modeleSecours: 'secours',
        attenteReessai: Duration.zero,
        client: MockClient((_) async {
          appels.add('x');
          return http.Response('{}', 403);
        }),
      );
      await expectLater(appeler(refus), throwsA(isA<GeminiException>()));
      expect(appels, hasLength(1));
    });

    test('nettoyer : coupe proprement les textes trop longs', () {
      final long = '${'mot ' * 60}fin.';
      final n = RapportTestService.nettoyer(long, 100);
      expect(n.length, lessThanOrEqualTo(101));
      expect(n, endsWith('…'));
      expect(RapportTestService.nettoyer('1. **Bien** joué', 50), 'Bien joué');
    });
  });

  testWidgets('carte du rapport : générée, puis masquée / affichée', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final resultat = (await tester.runAsync(() => passer(4)))!;
    final ia = RapportTestService(
      client: GeminiClient(
        apiKey: 'k',
        modele: 'm',
        client: MockClient((_) async => reponseGemini(jsonEncode(rapportJson))),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RapportIaCarte(
              tentativeId: resultat.tentativeId,
              freelancerId: freelancer,
              service: ia,
            ),
          ),
        ),
      ),
    );
    Future<void> attendre() async {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
    }

    await attendre();
    // pas encore de rapport : bouton
    await tester.tap(find.text('Générer mon rapport'));
    await attendre();
    expect(find.text('POINTS FORTS'), findsOneWidget);
    expect(find.text('POINTS À AMÉLIORER'), findsOneWidget);
    expect(find.text('CONSEILS'), findsOneWidget);
    expect(find.textContaining('Contraste'), findsOneWidget);

    await tester.tap(find.text('Masquer'));
    await tester.pumpAndSettle();
    expect(find.text('POINTS FORTS'), findsNothing);
    expect(find.text('Afficher'), findsOneWidget);
    // le choix est mémorisé
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(prefs.getBool('rapport_ia_visible'), isFalse);

    await tester.tap(find.text('Afficher'));
    await tester.pumpAndSettle();
    expect(find.text('POINTS FORTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
