import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/post.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/freelancer/freelancer_home.dart';
import 'package:sae2_brahim/screens/tests/certificat_screen.dart';
import 'package:sae2_brahim/screens/tests/choix_domaines_screen.dart';
import 'package:sae2_brahim/services/post_service.dart';
import 'package:sae2_brahim/services/test_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sae2_brahim/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget app(Widget home) => MaterialApp(
  theme: AppTheme.dark,
  locale: const Locale('fr'),
  supportedLocales: const [Locale('fr')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late User moi;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
  });
  tearDown(() => DatabaseHelper.instance.close());

  Future<void> attendre(WidgetTester t) async {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await t.pumpAndSettle();
  }

  for (final taille in [const Size(1080, 2400), const Size(640, 1136)]) {
    testWidgets(
      'parcours complet du test (${taille.width ~/ (taille.width > 700 ? 2.5 : 2)} dp)',
      (tester) async {
        tester.view.physicalSize = taille;
        tester.view.devicePixelRatio = taille.width > 700 ? 2.5 : 2;
        addTearDown(tester.view.reset);
        moi = (await tester.runAsync<User?>(() async {
          final id = await UserService().insertUser(
            User(
              username: 'sami',
              email: 's@t.tn',
              password: 'p',
              role: 'freelancer',
            ),
          );
          return UserService().getUserById(id);
        }))!;

        await tester.pumpWidget(app(ChoixDomainesScreen(user: moi)));
        await attendre(tester);

        // contrôle de saisie : aucun domaine choisi
        await tester.ensureVisible(find.text('Commencer le test'));
        await tester.tap(find.text('Commencer le test'));
        await tester.pump();
        expect(find.text('Choisis au moins un domaine'), findsOneWidget);

        await tester.ensureVisible(find.text('Design'));
        await tester.tap(find.text('Design'));
        await tester.ensureVisible(find.text('Commencer le test'));
        await tester.tap(find.text('Commencer le test'));
        await tester.pumpAndSettle();
        // le choix est définitif : confirmation
        expect(find.text('Choix définitif'), findsOneWidget);
        await tester.tap(find.text('Confirmer'));
        await attendre(tester);
        expect(find.text('Question 1 / 10'), findsOneWidget);
        expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
        expect(find.text('Précédente'), findsNothing); // pas de retour

        // « Suivante » sans réponse : bloqué
        await tester.tap(find.text('Suivante'));
        await tester.pump();
        expect(find.text('Choisis une réponse'), findsOneWidget);
        expect(find.text('Question 1 / 10'), findsOneWidget);

        // le chronomètre tourne…
        final chrono = RegExp(r'^(\d+) s$');
        int secondes() => int.parse(
          chrono
              .firstMatch(
                tester
                    .widgetList<Text>(find.textContaining(chrono))
                    .first
                    .data!,
              )!
              .group(1)!,
        );
        final debut = secondes();
        expect(debut, inInclusiveRange(20, 60));
        await tester.pump(const Duration(seconds: 3));
        expect(secondes(), debut - 3);
        // … et à zéro, on passe tout seul à la question 2
        await tester.pump(Duration(seconds: debut));
        await tester.pump(const Duration(milliseconds: 500)); // snackbar
        expect(find.text('Question 2 / 10'), findsOneWidget);
        expect(find.textContaining('Temps écoulé'), findsOneWidget);
        expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);

        // répondre « A » aux 9 autres puis terminer
        for (var i = 1; i < 10; i++) {
          await tester.ensureVisible(find.text('A'));
          await tester.tap(find.text('A'));
          await tester.pump();
          await tester.tap(find.text(i < 9 ? 'Suivante' : 'Terminer le test'));
          await tester.pump();
        }
        await attendre(tester);

        expect(find.text('Résultat'), findsOneWidget);
        expect(find.textContaining(' / 10'), findsWidgets);
        await tester.scrollUntilVisible(
          find.text('Temps écoulé : pas de réponse'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Temps écoulé : pas de réponse'), findsOneWidget);

        // 2e test : les domaines sont fixés sur le profil
        final domaines = await tester.runAsync(
          () => TestService().domainesProfil(moi.id!),
        );
        expect(domaines, ['design']);
        await tester.pumpWidget(
          KeyedSubtree(
            key: UniqueKey(), // nouvelle app (nouvelle pile d'écrans)
            child: app(ChoixDomainesScreen(user: moi)),
          ),
        );
        await attendre(tester);
        expect(find.text('Tes domaines'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
        expect(find.text('Domaines du test'), findsNothing); // non modifiables
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('certificat : nom, score, compétences, numéro', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final cert = (await tester.runAsync(() async {
      final id = await UserService().insertUser(
        User(
          username: 'sami',
          email: 's@t.tn',
          password: 'p',
          role: 'freelancer',
        ),
      );
      final service = TestService();
      final quiz = await service.genererQuiz(id, ['dev']);
      final db = await DatabaseHelper.instance.database;
      final reponses = <int, int>{};
      for (final q in quiz.questions) {
        final bonne =
            (await db.query(
                  'test',
                  where: 'id = ?',
                  whereArgs: [q.id],
                )).first['bonne_reponse']
                as int;
        reponses[q.id] = q.ordre.indexOf(bonne);
      }
      return (await service.corriger(
        freelancerId: id,
        quiz: quiz,
        reponses: reponses,
      )).certification!;
    }))!;

    await tester.pumpWidget(app(CertificatScreen(certification: cert)));
    await tester.pump();
    expect(find.text('CERTIFICAT DE COMPÉTENCES'), findsOneWidget);
    expect(find.text('@sami'), findsOneWidget);
    expect(find.text('10/10'), findsOneWidget);
    expect(find.text('Excellent'), findsOneWidget);
    expect(find.text('Développement 10/10'), findsOneWidget);
    expect(find.textContaining(cert.numero), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('postuler sans certification : on propose le test', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final ids = (await tester.runAsync(() async {
      final f = await UserService().insertUser(
        User(
          username: 'sami',
          email: 's@t.tn',
          password: 'p',
          role: 'freelancer',
        ),
      );
      final c = await UserService().insertUser(
        User(username: 'imed', email: 'i@t.tn', password: 'p', role: 'client'),
      );
      final p = await PostService().insertPost(
        Post(
          clientId: c,
          titre: 'Logo pour une boulangerie',
          description: 'Un logo moderne et simple pour ma boulangerie.',
          budget: 200,
          dateCreation: DateTime.now().toIso8601String(),
        ),
      );
      return (freelancer: f, post: p);
    }))!;
    final post = (await tester.runAsync(
      () => PostService().getPostById(ids.post),
    ))!;

    late BuildContext ctx;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold();
          },
        ),
      ),
    );
    final resultat = ouvrirPostuler(
      ctx,
      post: post,
      freelancerId: ids.freelancer,
    );
    await attendre(tester);
    expect(find.text('Certification requise'), findsOneWidget);
    expect(find.text('Passer le test'), findsOneWidget);
    expect(find.byType(PostulerSheet), findsNothing);

    await tester.ensureVisible(find.text('Plus tard'));
    await tester.tap(find.text('Plus tard'));
    await attendre(tester);
    expect(await resultat, isFalse);
    expect(find.text('Certification requise'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
