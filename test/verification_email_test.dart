import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/inscription.dart';
import 'package:sae2_brahim/services/mail/mail_service.dart';
import 'package:sae2_brahim/services/mail/modeles_email.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sae2_brahim/services/verification_email_service.dart';
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

  String get dernierCode =>
      RegExp(r'Ton code : (\d{6})').firstMatch(envoyes.last.texte)!.group(1)!;
}

User brouillon({String role = 'freelancer', String email = 'sami@gmail.com'}) =>
    User(username: 'sami', email: email, password: 'secret123', role: role);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  final users = UserService();
  late FauxEnvoyeur faux;
  late DateTime maintenant;
  late VerificationEmailService service;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
    faux = FauxEnvoyeur();
    maintenant = DateTime(2026, 11, 8, 10);
    service = VerificationEmailService(
      mails: MailService(envoyeur: faux),
      maintenant: () => maintenant,
    );
  });
  tearDown(() => DatabaseHelper.instance.close());

  Future<int> nbVerifications() async {
    final db = await DatabaseHelper.instance.database;
    return (await db.query('verifications_email')).length;
  }

  String mauvaisCode() => faux.dernierCode == '000000' ? '111111' : '000000';

  for (final role in ['freelancer', 'client']) {
    test('$role : aucun compte avant le code, créé après', () async {
      await service.demanderCode(nom: 'sami', email: '  SAMI@gmail.com ');
      final mail = faux.envoyes.single;
      expect(mail.destinataire, 'sami@gmail.com');
      expect(mail.sujet, startsWith('Vérifie ton email freelance'));
      expect(mail.texte, contains('Bonjour sami'));
      expect(mail.html, contains(faux.dernierCode));
      expect(await users.emailExists('sami@gmail.com'), isFalse);

      final id = await service.verifierEtCreer(
        user: brouillon(role: role, email: 'SAMI@gmail.com'),
        code: faux.dernierCode,
      );
      final u = (await users.getUserById(id))!;
      expect(u.email, 'sami@gmail.com');
      expect(u.role, role);
      expect(u.password, isNot('secret123')); // haché
      expect(await users.login('sami@gmail.com', 'secret123'), isNotNull);
      expect(await nbVerifications(), 0); // le code ne resservira pas
    });
  }

  test('adresse déjà utilisée : aucun email', () async {
    await users.insertUser(brouillon());
    await expectLater(
      service.demanderCode(nom: 'autre', email: 'sami@gmail.com'),
      throwsA(isA<EmailDejaUtiliseException>()),
    );
    expect(faux.envoyes, isEmpty);
  });

  test('mauvais code : pas de compte, 5 essais au maximum', () async {
    await service.demanderCode(nom: 'sami', email: 'sami@gmail.com');
    final bon = faux.dernierCode;
    for (var i = 0; i < 5; i++) {
      await expectLater(
        service.verifierEtCreer(user: brouillon(), code: mauvaisCode()),
        throwsA(isA<VerificationException>()),
      );
    }
    await expectLater(
      service.verifierEtCreer(user: brouillon(), code: bon),
      throwsA(
        isA<VerificationException>().having(
          (e) => e.message,
          'm',
          contains("Trop d'essais"),
        ),
      ),
    );
    expect(await users.emailExists('sami@gmail.com'), isFalse);
  });

  test('code expiré après 15 minutes', () async {
    await service.demanderCode(nom: 'sami', email: 'sami@gmail.com');
    maintenant = maintenant.add(const Duration(minutes: 15, seconds: 1));
    await expectLater(
      service.verifierEtCreer(user: brouillon(), code: faux.dernierCode),
      throwsA(
        isA<VerificationException>().having(
          (e) => e.message,
          'm',
          contains('expiré'),
        ),
      ),
    );
    expect(await users.emailExists('sami@gmail.com'), isFalse);
  });

  test('renvoi : 60 s d\'attente, l\'ancien code ne marche plus', () async {
    await service.demanderCode(nom: 'sami', email: 'sami@gmail.com');
    final ancien = faux.dernierCode;
    await expectLater(
      service.demanderCode(nom: 'sami', email: 'sami@gmail.com'),
      throwsA(isA<AttenteRenvoiException>()),
    );
    expect(faux.envoyes, hasLength(1));

    maintenant = maintenant.add(const Duration(seconds: 61));
    do {
      faux.envoyes.clear();
      maintenant = maintenant.add(const Duration(seconds: 61));
      await service.demanderCode(nom: 'sami', email: 'sami@gmail.com');
    } while (faux.dernierCode == ancien);
    await expectLater(
      service.verifierEtCreer(user: brouillon(), code: ancien),
      throwsA(isA<VerificationException>()),
    );
    await service.verifierEtCreer(user: brouillon(), code: faux.dernierCode);
    expect(await users.emailExists('sami@gmail.com'), isTrue);
  });

  test('envoi impossible : message clair, on peut réessayer', () async {
    faux.erreur = const EnvoiException('réseau', reseau: true);
    await expectLater(
      service.demanderCode(nom: 'sami', email: 'sami@gmail.com'),
      throwsA(
        isA<VerificationException>().having(
          (e) => e.message,
          'm',
          contains('Pas de connexion'),
        ),
      ),
    );
    expect(await nbVerifications(), 0);
    faux.erreur = null;
    await service.demanderCode(nom: 'sami', email: 'sami@gmail.com');
    expect(faux.envoyes, hasLength(1));
  });

  testWidgets('écran : inscription terminée seulement avec le bon code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136); // 320 dp
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    service = VerificationEmailService(mails: MailService(envoyeur: faux));

    Future<void> attendre() async {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
    }

    Object? resultat;
    late BuildContext ctx;
    await tester.pumpWidget(
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
        .push<String>(
          MaterialPageRoute(
            builder: (_) => InscriptionScreen(service: service),
          ),
        )
        .then((v) => resultat = v);
    await tester.pumpAndSettle();

    final champs = find.byType(TextField);
    await tester.enterText(champs.at(0), 'sami');
    await tester.enterText(champs.at(1), 'sami@gmail.com');
    await tester.enterText(champs.at(2), 'secret123');
    await tester.enterText(champs.at(3), 'secret123');
    await tester.pump();
    final bouton = find.text('Créer mon compte freelancer');
    await tester.ensureVisible(bouton);
    await tester.pumpAndSettle();
    await tester.tap(bouton);
    await attendre();

    expect(find.textContaining('Vérifie ton'), findsOneWidget);
    expect(find.textContaining('sami@gmail.com'), findsOneWidget);
    expect(find.textContaining('Renvoyer le code ('), findsOneWidget);
    expect(faux.envoyes, hasLength(1));
    expect(
      await tester.runAsync(() => users.emailExists('sami@gmail.com')),
      isFalse,
    );

    // mauvais code : on reste sur l'écran
    await tester.enterText(find.byType(TextField), mauvaisCode());
    await tester.ensureVisible(find.text('Vérifier et créer mon compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vérifier et créer mon compte'));
    await attendre();
    expect(find.textContaining('Code incorrect'), findsOneWidget);
    expect(find.textContaining('Vérifie ton'), findsOneWidget);

    // bon code : compte créé, retour à la connexion avec l'email
    await tester.enterText(find.byType(TextField), faux.dernierCode);
    await tester.ensureVisible(find.text('Vérifier et créer mon compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vérifier et créer mon compte'));
    await attendre();
    expect(resultat, 'sami@gmail.com');
    expect(
      await tester.runAsync(() => users.emailExists('sami@gmail.com')),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
