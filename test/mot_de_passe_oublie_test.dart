import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/mot_de_passe_oublie.dart';
import 'package:sae2_brahim/services/mail/mail_service.dart';
import 'package:sae2_brahim/services/mail/modeles_email.dart';
import 'package:sae2_brahim/services/mot_de_passe_oublie_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sae2_brahim/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FauxEnvoyeur implements EnvoyeurEmail {
  final List<EmailSortant> envoyes = [];
  EnvoiException? erreur;
  @override
  bool get estConfigure => true;
  @override
  Future<void> envoyer(EmailSortant email) async {
    if (erreur != null) throw erreur!;
    envoyes.add(email);
  }

  /// Le code à 6 chiffres du dernier email
  String get dernierCode =>
      RegExp(r'Ton code : (\d{6})').firstMatch(envoyes.last.texte)!.group(1)!;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  final users = UserService();
  late FauxEnvoyeur faux;
  late DateTime maintenant;
  late MotDePasseOublieService service;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
    faux = FauxEnvoyeur();
    maintenant = DateTime(2026, 11, 7, 10);
    service = MotDePasseOublieService(
      mails: MailService(envoyeur: faux),
      maintenant: () => maintenant,
    );
    await users.insertUser(
      User(
        username: 'imed',
        email: 'imed@gmail.com',
        password: 'ancien123',
        role: 'client',
      ),
    );
  });
  tearDown(() => DatabaseHelper.instance.close());

  test('parcours complet : code par email puis nouveau mot de passe', () async {
    await service.demanderCode('  IMED@gmail.com '); // casse et espaces ignorés
    final email = faux.envoyes.single;
    expect(email.destinataire, 'imed@gmail.com');
    expect(email.sujet, startsWith('Ton code freelance'));
    expect(email.texte, contains('Bonjour imed'));
    expect(email.texte, contains('valable 15 minutes'));

    await service.reinitialiser(
      email: 'imed@gmail.com',
      code: faux.dernierCode,
      nouveauMotDePasse: 'nouveau456',
    );
    expect(await users.login('imed@gmail.com', 'nouveau456'), isNotNull);
    expect(await users.login('imed@gmail.com', 'ancien123'), isNull);

    // le code ne sert qu'une fois
    expect(
      () => service.reinitialiser(
        email: 'imed@gmail.com',
        code: faux.dernierCode,
        nouveauMotDePasse: 'autre7890',
      ),
      throwsA(isA<ReinitialisationException>()),
    );
  });

  test('le code n\'est pas stocké en clair', () async {
    await service.demanderCode('imed@gmail.com');
    final db = await DatabaseHelper.instance.database;
    final ligne = (await db.query('codes_reinitialisation')).single;
    expect(ligne['code_hash'], isNot(faux.dernierCode));
    expect(ligne['code_hash'] as String, startsWith('sha256\$'));
  });

  test("email inconnu : erreur « n'existe pas », aucun email envoyé", () async {
    await expectLater(
      service.demanderCode('personne@gmail.com'),
      throwsA(isA<EmailInconnuException>()),
    );
    expect(faux.envoyes, isEmpty);
  });

  test('5 essais maximum, puis même le bon code est refusé', () async {
    await service.demanderCode('imed@gmail.com');
    final bon = faux.dernierCode;
    final faux1 = bon == '000000' ? '111111' : '000000';
    for (var i = 0; i < MotDePasseOublieService.essaisMax; i++) {
      await expectLater(
        service.reinitialiser(
          email: 'imed@gmail.com',
          code: faux1,
          nouveauMotDePasse: 'nouveau456',
        ),
        throwsA(isA<ReinitialisationException>()),
      );
    }
    await expectLater(
      service.reinitialiser(
        email: 'imed@gmail.com',
        code: bon,
        nouveauMotDePasse: 'nouveau456',
      ),
      throwsA(predicate((e) => e.toString().contains('Trop d\'essais'))),
    );
  });

  test('code expiré après 15 minutes', () async {
    await service.demanderCode('imed@gmail.com');
    maintenant = maintenant.add(const Duration(minutes: 16));
    await expectLater(
      service.reinitialiser(
        email: 'imed@gmail.com',
        code: faux.dernierCode,
        nouveauMotDePasse: 'nouveau456',
      ),
      throwsA(predicate((e) => e.toString().contains('expiré'))),
    );
  });

  test('60 s entre deux envois ; le nouveau code remplace l\'ancien', () async {
    await service.demanderCode('imed@gmail.com');
    final ancien = faux.dernierCode;
    await expectLater(
      service.demanderCode('imed@gmail.com'),
      throwsA(predicate((e) => e.toString().contains('Attends'))),
    );
    maintenant = maintenant.add(const Duration(seconds: 61));
    await service.demanderCode('imed@gmail.com');
    expect(faux.envoyes, hasLength(2));
    if (ancien != faux.dernierCode) {
      await expectLater(
        service.reinitialiser(
          email: 'imed@gmail.com',
          code: ancien,
          nouveauMotDePasse: 'nouveau456',
        ),
        throwsA(isA<ReinitialisationException>()),
      );
    }
  });

  test(
    'sans réseau : message clair, et on peut réessayer tout de suite',
    () async {
      faux.erreur = const EnvoiException('Pas de connexion', reseau: true);
      await expectLater(
        service.demanderCode('imed@gmail.com'),
        throwsA(predicate((e) => e.toString().contains('connexion Internet'))),
      );
      faux.erreur = null;
      await service.demanderCode('imed@gmail.com'); // pas de délai de 60 s
      expect(faux.envoyes, hasLength(1));
    },
  );

  test('contrôle de saisie', () {
    expect(MotDePasseOublieService.validerCode(''), isNotNull);
    expect(MotDePasseOublieService.validerCode('12345'), isNotNull);
    expect(MotDePasseOublieService.validerCode('12a456'), isNotNull);
    expect(MotDePasseOublieService.validerCode('123456'), isNull);
    expect(MotDePasseOublieService.genererCode(), matches(RegExp(r'^\d{6}$')));
  });

  testWidgets('écran : email → code → nouveau mot de passe', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final s = MotDePasseOublieService(mails: MailService(envoyeur: faux));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: MotDePasseOublieScreen(service: s),
      ),
    );
    expect(find.text('Étape 1 / 2'), findsOneWidget);

    // email invalide : contrôle de saisie
    await tester.tap(find.text('Envoyer le code'));
    await tester.pump();
    expect(find.text('Entre ton email'), findsOneWidget);

    // adresse sans compte : erreur, on reste à l'étape 1
    await tester.enterText(find.byType(TextField), 'personne@gmail.com');
    await tester.tap(find.text('Envoyer le code'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(find.text("Aucun compte n'utilise cette adresse"), findsOneWidget);
    expect(find.text('Étape 1 / 2'), findsOneWidget);
    expect(faux.envoyes, isEmpty);
    await tester.pump(const Duration(seconds: 5)); // ferme le message

    await tester.enterText(find.byType(TextField), 'imed@gmail.com');
    await tester.tap(find.text('Envoyer le code'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(find.text('Étape 2 / 2'), findsOneWidget);
    expect(find.textContaining('Renvoyer le code ('), findsOneWidget);

    final champs = find.byType(TextField);
    await tester.enterText(champs.at(0), faux.dernierCode);
    await tester.enterText(champs.at(1), 'nouveau456');
    await tester.enterText(champs.at(2), 'autre');
    await tester.tap(find.text('Changer le mot de passe'));
    await tester.pump();
    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);

    await tester.enterText(champs.at(2), 'nouveau456');
    await tester.tap(find.text('Changer le mot de passe'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(
      await tester.runAsync(() => users.login('imed@gmail.com', 'nouveau456')),
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox()); // arrête le minuteur
  });
}
