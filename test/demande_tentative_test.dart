import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/tests/demande_tentative_screen.dart';
import 'package:sae2_brahim/screens/tests/tests_screen.dart';
import 'package:sae2_brahim/services/test_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sae2_brahim/theme/app_theme.dart';
import 'package:sae2_brahim/utils/validators.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const explication = 'Je me suis trompé de rythme et le temps a manqué.';
const revisions = 'Les balises HTML et le langage SQL';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  final service = TestService();
  late int freelancer;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
    freelancer = await UserService().insertUser(
      User(
        username: 'sami',
        email: 's@t.tn',
        password: 'p',
        role: 'freelancer',
      ),
    );
  });
  tearDown(() => DatabaseHelper.instance.close());

  /// Passe un test sans répondre : 0/10
  Future<void> echouer() async {
    final quiz = await service.genererQuiz(freelancer, ['dev']);
    await service.corriger(freelancerId: freelancer, quiz: quiz, reponses: {});
  }

  Future<void> demander({
    String? motif = 'temps',
    String? precision = '',
    String? expl = explication,
    String? rev = revisions,
    String? heures = '6',
    bool engagement = true,
  }) => service.demanderTentative(
    freelancerId: freelancer,
    motif: motif,
    precision: precision,
    explication: expl,
    revisions: rev,
    heures: heures,
    engagement: engagement,
  );

  group('contrôles de saisie', () {
    test('précision : obligatoire seulement pour « Autre »', () {
      expect(Validators.precisionMotif('', 'temps'), isNull);
      expect(Validators.precisionMotif('', 'autre'), isNotNull);
      expect(Validators.precisionMotif('abc', 'autre'), isNotNull);
      expect(Validators.precisionMotif('Coupure de courant', 'autre'), isNull);
    });

    test('explication : longueur et vraie phrase', () {
      expect(Validators.explicationDemande(''), isNotNull);
      expect(Validators.explicationDemande('trop court'), isNotNull);
      expect(Validators.explicationDemande('a' * 40), isNotNull);
      expect(Validators.explicationDemande('1234 ' * 10), isNotNull);
      expect(Validators.explicationDemande('test ' * 10), isNotNull);
      expect(Validators.explicationDemande('x' * 301), isNotNull);
      expect(Validators.explicationDemande(explication), isNull);
    });

    test('révisions', () {
      expect(Validators.revisionsDemande(''), isNotNull);
      expect(Validators.revisionsDemande('SQL'), isNotNull);
      expect(Validators.revisionsDemande(revisions), isNull);
    });

    test('heures : entier de 1 à 200', () {
      for (final v in ['', 'abc', '0', '201', '2.5', '-3']) {
        expect(Validators.heuresRevision(v), isNotNull, reason: v);
      }
      expect(Validators.heuresRevision('1'), isNull);
      expect(Validators.heuresRevision('200'), isNull);
    });

    test('engagement obligatoire', () {
      expect(Validators.engagement(false), isNotNull);
      expect(Validators.engagement(null), isNotNull);
      expect(Validators.engagement(true), isNull);
    });

    test('le service refuse aussi un formulaire invalide', () async {
      for (var i = 0; i < 3; i++) {
        await echouer();
      }
      for (final envoi in <Future<void> Function()>[
        () => demander(motif: null),
        () => demander(motif: 'inconnu'),
        () => demander(motif: 'autre', precision: ''),
        () => demander(expl: 'court'),
        () => demander(rev: ''),
        () => demander(heures: '0'),
        () => demander(engagement: false),
      ]) {
        await expectLater(envoi(), throwsA(isA<TestException>()));
      }
      expect((await service.etat(freelancer)).demandeFaite, isFalse);
    });
  });

  group('règles', () {
    test('impossible avant les 3 échecs', () async {
      await echouer();
      expect((await service.etat(freelancer)).peutDemanderTentative, isFalse);
      await expectLater(demander(), throwsA(isA<TestException>()));
    });

    test('3 échecs : 1 tentative de plus, une seule fois', () async {
      for (var i = 0; i < 3; i++) {
        await echouer();
      }
      final e = await service.etat(freelancer);
      expect(e.peutPasser, isFalse);
      expect(e.peutDemanderTentative, isTrue);

      await demander();
      final apres = await service.etat(freelancer);
      expect(apres.max, 4);
      expect(apres.restantes, 1);
      expect(apres.peutPasser, isTrue);
      await expectLater(demander(), throwsA(isA<TestException>()));

      await echouer(); // la 4e échoue aussi : c'est terminé
      final fin = await service.etat(freelancer);
      expect(fin.restantes, 0);
      expect(fin.peutDemanderTentative, isFalse);
      await expectLater(
        service.genererQuiz(freelancer, ['dev']),
        throwsA(isA<TestException>()),
      );
      await expectLater(demander(), throwsA(isA<TestException>()));
    });

    test('la demande est enregistrée', () async {
      for (var i = 0; i < 3; i++) {
        await echouer();
      }
      await demander(motif: 'autre', precision: '  Coupure de courant ');
      final db = await DatabaseHelper.instance.database;
      final l = (await db.query('demandes_tentative')).single;
      expect(l['motif'], 'autre');
      expect(l['precision_motif'], 'Coupure de courant');
      expect(l['heures'], 6);
      expect(l['statut'], 'en_cours');
      final d = (await service.getDemande(freelancer))!;
      expect(d.statutLisible, 'En cours');
      expect(d.motifLisible, 'Autre');
      expect(d.precision, 'Coupure de courant');
    });
  });

  testWidgets('formulaire à 320 dp : erreurs, champ conditionnel, envoi', (
    t,
  ) async {
    t.view.physicalSize = const Size(640, 1136);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final moi = (await t.runAsync(() async {
      for (var i = 0; i < 3; i++) {
        await echouer();
      }
      return UserService().getUserById(freelancer);
    }))!;

    Future<void> attendre() async {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pumpAndSettle();
    }

    Object? resultat;
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold();
          },
        ),
      ),
    );
    Navigator.of(ctx)
        .push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                DemandeTentativeScreen(user: moi, domaines: const ['dev']),
          ),
        )
        .then((v) => resultat = v);
    await t.pumpAndSettle();

    Future<void> envoyer() async {
      await t.ensureVisible(find.text('Envoyer ma demande'));
      await t.pumpAndSettle();
      await t.tap(find.text('Envoyer ma demande'));
      await attendre();
    }

    // tout est vide : chaque contrôle s'affiche
    await envoyer();
    expect(find.text('Corrige les champs en rouge'), findsOneWidget);
    expect(find.text('Tu dois accepter cet engagement'), findsOneWidget);
    expect(find.text('Indique le nombre d\'heures'), findsOneWidget);
    expect(find.text('Indique ce que tu as révisé'), findsOneWidget);
    expect(find.text('Explique ce qui s\'est passé'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Choisis un motif'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Choisis un motif'), findsOneWidget);
    expect(resultat, isNull);

    // « Autre » fait apparaître un champ de plus
    expect(find.text('Précise le motif'), findsNothing);
    await Scrollable.ensureVisible(
      t.element(find.text('Autre')),
      alignment: 0.5,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Autre'));
    await t.pumpAndSettle();
    expect(find.text('Précise le motif'), findsOneWidget);

    final champs = find.byType(TextField);
    await t.enterText(champs.at(0), 'Coupure de courant');
    await t.enterText(champs.at(1), explication);
    await t.enterText(champs.at(2), revisions);
    await t.enterText(champs.at(3), '6');
    await t.pump();
    final engagement = find.byType(Checkbox);
    await t.ensureVisible(engagement);
    await t.pumpAndSettle();
    await t.tap(engagement);
    await t.pump();
    // le message d'erreur précédent recouvre le bas de l'écran
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    await envoyer();

    expect(resultat, isTrue);
    final e = (await t.runAsync(() => service.etat(freelancer)))!;
    expect(e.restantes, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('sous l\'historique : statut, afficher et masquer (320 dp)', (
    t,
  ) async {
    t.view.physicalSize = const Size(640, 1136);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final moi = (await t.runAsync(() async {
      for (var i = 0; i < 3; i++) {
        await echouer();
      }
      await demander();
      return UserService().getUserById(freelancer);
    }))!;

    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: TestsScreen(user: moi),
      ),
    );
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();

    final liste = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('Afficher'), 200, scrollable: liste);
    await t.pumpAndSettle();
    expect(find.text('Ma demande de tentative'), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text(explication), findsNothing); // masquée au départ

    await t.tap(find.text('Afficher'));
    await t.pumpAndSettle();
    expect(find.text(explication), findsOneWidget);
    expect(find.text('Manque de temps'), findsOneWidget);
    expect(find.text('6 h'), findsOneWidget);

    await t.tap(find.text('Masquer'));
    await t.pumpAndSettle();
    expect(find.text(explication), findsNothing);
    expect(find.text('Afficher'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
