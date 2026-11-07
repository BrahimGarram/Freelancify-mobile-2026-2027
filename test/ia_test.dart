import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/assistant/assistant_screen.dart';
import 'package:sae2_brahim/screens/client/publier_post.dart';
import 'package:sae2_brahim/services/ai/assistant_service.dart';
import 'package:sae2_brahim/services/ai/gemini_client.dart';
import 'package:sae2_brahim/services/ai/post_ia_service.dart';
import 'package:sae2_brahim/theme/app_theme.dart';

/// Réponse Gemini simulée contenant [texte]
http.Response reponseGemini(String texte, {String fin = 'STOP'}) =>
    http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'réflexion', 'thought': true},
                  {'text': texte},
                ],
              },
              'finishReason': fin,
            },
          ],
        }),
      ),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

GeminiClient client(MockClient mock, {String cle = 'cle-test'}) =>
    GeminiClient(apiKey: cle, modele: 'modele-test', client: mock);

final client1 = User(
  id: 1,
  username: 'lina',
  email: 'l@t.com',
  password: '',
  role: 'client',
);

Widget app(Widget home) => MaterialApp(
  theme: AppTheme.dark,
  locale: const Locale('fr'),
  supportedLocales: const [Locale('fr')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

/// Le JSON que renverrait Gemini pour une demande complète
Map<String, dynamic> jsonComplet({Map<String, dynamic> change = const {}}) => {
  'estUneMission': true,
  'titre': 'Logo et carte de visite pour une pâtisserie',
  'description':
      "J'ouvre une pâtisserie à Sousse et je cherche un designer pour créer "
      'mon logo et ma carte de visite.\n\nLe travail doit être prêt avant '
      "l'ouverture.",
  'categories': ['design', 'marketing'],
  'competences': ['Logo', 'Illustrator'],
  'typeBudget': 'fixe',
  'budget': 300,
  'dateLimite': '2026-11-30',
  'modeTravail': 'distance',
  'ville': 'Sousse',
  'urgent': false,
  ...change,
};

void main() {
  final today = DateTime(2026, 11, 7);

  group('client Gemini', () {
    test('requête : clé dans l\'en-tête, rôles, schéma JSON', () async {
      late http.Request envoyee;
      final ia = client(
        MockClient((r) async {
          envoyee = r;
          return reponseGemini('Bonjour');
        }),
      );
      final texte = await ia.generer(
        instructions: 'Sois bref',
        messages: const [
          GeminiMessage.utilisateur('Q1'),
          GeminiMessage.assistant('R1'),
          GeminiMessage.utilisateur('Q2'),
        ],
        schemaJson: const {'type': 'object'},
      );

      expect(texte, 'Bonjour'); // la réflexion interne est ignorée
      expect(envoyee.url.path, endsWith('/models/modele-test:generateContent'));
      expect(envoyee.headers['x-goog-api-key'], 'cle-test');
      expect(envoyee.url.query, isEmpty); // la clé n'est pas dans l'URL
      final corps = jsonDecode(envoyee.body);
      expect(corps['systemInstruction']['parts'][0]['text'], 'Sois bref');
      expect((corps['contents'] as List).map((c) => c['role']), [
        'user',
        'model',
        'user',
      ]);
      expect(corps['generationConfig']['responseMimeType'], 'application/json');
      expect(corps['generationConfig']['responseJsonSchema'], {
        'type': 'object',
      });
    });

    Future<GeminiErreur> erreurPour(MockClient mock, {String cle = 'k'}) async {
      try {
        await client(mock, cle: cle).generer(
          instructions: 'x',
          messages: const [GeminiMessage.utilisateur('q')],
        );
      } on GeminiException catch (e) {
        return e.type;
      }
      fail('aucune erreur');
    }

    test('erreurs traduites en messages clairs', () async {
      expect(
        await erreurPour(MockClient((_) async => reponseGemini('x')), cle: ''),
        GeminiErreur.cleManquante,
      );
      expect(
        await erreurPour(
          MockClient((_) async => throw const SocketException('pas de réseau')),
        ),
        GeminiErreur.horsLigne,
      );
      expect(
        await erreurPour(
          MockClient(
            (_) async => http.Response(
              '{"error":{"code":400,"message":"API key not valid."}}',
              400,
            ),
          ),
        ),
        GeminiErreur.cleInvalide,
      );
      expect(
        await erreurPour(MockClient((_) async => http.Response('{}', 429))),
        GeminiErreur.quota,
      );
      expect(
        await erreurPour(MockClient((_) async => http.Response('{}', 503))),
        GeminiErreur.surcharge,
      );
      expect(
        await erreurPour(
          MockClient(
            (_) async => http.Response(
              '{"promptFeedback":{"blockReason":"SAFETY"}}',
              200,
            ),
          ),
        ),
        GeminiErreur.bloque,
      );
      expect(
        await erreurPour(
          MockClient((_) async => reponseGemini('x', fin: 'SAFETY')),
        ),
        GeminiErreur.bloque,
      );
    });
  });

  group('chatbot', () {
    test('le prompt contient le guide et le rôle de l\'utilisateur', () {
      final s = AssistantService(
        user: client1,
        client: client(MockClient((_) async => reponseGemini(''))),
      );
      expect(s.instructions, contains('CLIENT'));
      expect(s.instructions, contains('lina'));
      expect(s.instructions, contains('Publier un post'));
      expect(s.suggestions, contains('Comment publier un post ?'));
      final visiteur = AssistantService(
        client: client(MockClient((_) async => reponseGemini(''))),
      );
      expect(visiteur.instructions, contains('VISITEUR'));
    });

    test('historique limité et Markdown retiré', () async {
      late Map corps;
      final s = AssistantService(
        user: client1,
        client: client(
          MockClient((r) async {
            corps = jsonDecode(r.body);
            return reponseGemini('**Va** dans :\n- Profil\n- Modifier');
          }),
        ),
      );
      final historique = [
        for (var i = 0; i < 10; i++) ...[
          GeminiMessage.utilisateur('q$i'),
          GeminiMessage.assistant('r$i'),
        ],
        const GeminiMessage.utilisateur('dernière'),
      ];
      final r = await s.repondre(historique);
      expect(r, 'Va dans :\n• Profil\n• Modifier');
      final contents = corps['contents'] as List;
      expect(
        contents.length,
        lessThanOrEqualTo(AssistantService.historiqueMax),
      );
      expect(contents.first['role'], 'user'); // commence par l'utilisateur
      expect(contents.last['parts'][0]['text'], 'dernière');
    });

    testWidgets('conversation : suggestion, réponse, erreur puis Réessayer', (
      tester,
    ) async {
      var appels = 0;
      final service = AssistantService(
        user: client1,
        client: client(
          MockClient((r) async {
            appels++;
            if (appels == 2) return http.Response('{}', 429);
            return reponseGemini('Touche le bouton « + ».');
          }),
        ),
      );
      await tester.pumpWidget(
        app(AssistantScreen(user: client1, service: service)),
      );
      expect(find.textContaining('Salut lina'), findsOneWidget);

      await tester.tap(find.text('Comment publier un post ?'));
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Touche le bouton « + ».'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Et ensuite ?');
      await tester.tap(find.byTooltip('Envoyer').last);
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Limite gratuite'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Limite gratuite'), findsNothing);
      expect(find.text('Et ensuite ?'), findsOneWidget);
      expect(find.text('Touche le bouton « + ».'), findsNWidgets(2));
    });
  });

  group('remplissage du post', () {
    test('le prompt donne la date du jour et le schéma impose nos listes', () {
      final p = PostIaService.instructions(today);
      expect(p, contains('samedi 2026-11-07'));
      final props = PostIaService.schema['properties'] as Map;
      expect(props['categories']['maxItems'], 3);
      expect(props['ville']['enum'], contains('Sousse'));
      expect(props['modeTravail']['enum'], contains('non_precise'));
    });

    test('demande complète : tous les champs sont remplis', () {
      final b = PostIaService.convertir(jsonComplet(), aujourdHui: today);
      expect(b.titre, 'Logo et carte de visite pour une pâtisserie');
      expect(b.categories, ['design', 'marketing']);
      expect(b.budget, 300);
      expect(b.typeBudget, 'fixe');
      expect(b.dateLimite, DateTime(2026, 11, 30));
      expect(b.modeTravail, 'distance');
      expect(b.ville, isNull); // inutile à distance
      expect(b.competences, ['Logo', 'Illustrator']);
      expect(b.manquants, isEmpty);
    });

    test('information absente → champ non rempli et signalé', () {
      final b = PostIaService.convertir(
        jsonComplet(
          change: {
            'budget': null,
            'typeBudget': 'non_precise',
            'dateLimite': null,
            'modeTravail': 'non_precise',
            'ville': 'non_precise',
          },
        ),
        aujourdHui: today,
      );
      expect(b.budget, isNull);
      expect(b.typeBudget, isNull);
      expect(b.dateLimite, isNull);
      expect(b.modeTravail, isNull);
      expect(b.manquants, ['budget', 'date limite', 'mode de travail']);
    });

    test('valeurs invalides de l\'IA rejetées par nos validateurs', () {
      final b = PostIaService.convertir(
        jsonComplet(
          change: {
            'titre': 'Lo', // trop court
            'categories': [
              'design',
              'inconnue',
              'design',
              'dev',
              'video',
              'photo',
            ],
            'budget': 900,
            'typeBudget': 'horaire', // > 500 DT/h
            'dateLimite': '2026-11-01', // passée
            'modeTravail': 'sur_place',
            'ville': 'Paris',
            'competences': ['Logo', 'logo', 'x', 'C#', 'a' * 30],
          },
        ),
        aujourdHui: today,
      );
      expect(b.titre, isNull);
      expect(b.categories, ['design', 'dev', 'video']);
      expect(b.budget, isNull);
      expect(b.dateLimite, isNull);
      expect(b.ville, isNull);
      expect(b.competences, ['Logo', 'C#']);
      expect(b.manquants, containsAll(['titre', 'budget', 'ville']));
    });

    test('description trop longue coupée à une fin de phrase', () {
      final longue = '${'Une phrase complète. ' * 60}fin';
      final b = PostIaService.convertir(
        jsonComplet(change: {'description': longue}),
        aujourdHui: today,
      );
      expect(b.description!.length, lessThanOrEqualTo(1000));
      expect(b.description, endsWith('.'));
    });

    test('demande sans rapport → message clair', () async {
      final s = PostIaService(
        client: client(
          MockClient(
            (_) async => reponseGemini(jsonEncode({'estUneMission': false})),
          ),
        ),
      );
      expect(
        () => s.analyser('bonjour comment ça va ?', aujourdHui: today),
        throwsA(isA<PostIaException>()),
      );
      expect(() => s.analyser('trop court'), throwsA(isA<PostIaException>()));
    });

    testWidgets('le formulaire se remplit et signale ce qui manque', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final demain = DateTime.now().add(const Duration(days: 10));
      final iso =
          '${demain.year}-${demain.month.toString().padLeft(2, '0')}-'
          '${demain.day.toString().padLeft(2, '0')}';
      final ia = PostIaService(
        client: client(
          MockClient(
            (_) async => reponseGemini(
              jsonEncode(
                jsonComplet(
                  change: {
                    'budget': null,
                    'typeBudget': 'non_precise',
                    'dateLimite': iso,
                    'modeTravail': 'sur_place',
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(PublierPostScreen(user: client1, ia: ia)));

      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.hintText ?? '').startsWith("Ex : j'ouvre"),
        ),
        "J'ouvre une pâtisserie à Sousse, je veux un logo",
      );
      await tester.tap(find.text('Remplir le formulaire'));
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Logo et carte de visite pour une pâtisserie'),
        findsOneWidget,
      );
      expect(find.text('2/3'), findsOneWidget); // 2 catégories choisies
      expect(find.text('Sousse'), findsOneWidget); // ville sur place
      expect(find.text('Illustrator'), findsOneWidget);
      expect(find.textContaining('à compléter : budget'), findsOneWidget);
      expect(find.text('Entre un budget'), findsOneWidget); // champ en rouge
    });
  });
}
