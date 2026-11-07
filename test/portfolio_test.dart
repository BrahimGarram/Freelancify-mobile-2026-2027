import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/realisation.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/freelancer/publier_realisation.dart';
import 'package:sae2_brahim/screens/profil_freelancer.dart';
import 'package:sae2_brahim/services/image_service.dart';
import 'package:sae2_brahim/services/realisation_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sae2_brahim/theme/app_theme.dart';
import 'package:sae2_brahim/utils/validators.dart';
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

  final users = UserService();
  final service = RealisationService();
  final now = DateTime.now().toIso8601String();
  late Directory tmp;
  late int freelancer, client;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
    tmp = await Directory.systemTemp.createTemp('sae2_img');
    ImageService.overrideDir = tmp;

    freelancer = await users.insertUser(
      User(
        username: 'sami',
        email: 'sami@test.com',
        password: 'pass1234',
        role: 'freelancer',
      ),
    );
    client = await users.insertUser(
      User(
        username: 'lina',
        email: 'lina@test.com',
        password: 'pass1234',
        role: 'client',
      ),
    );
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Realisation exemple({String? lien, String? clientNom}) => Realisation(
    freelancerId: freelancer,
    titre: 'Site vitrine restaurant',
    description: 'Création du site complet avec menu et réservation.',
    categorie: 'dev',
    client: clientNom,
    lien: lien,
    dateCreation: now,
  );

  group('contrôle de saisie', () {
    test('lien', () {
      expect(Validators.lien(''), isNull); // facultatif
      expect(Validators.lien('monsite.tn'), isNull);
      expect(Validators.lien('https://www.exemple.com/projet?id=3'), isNull);
      for (final bad in [
        'pas un lien',
        'ftp://site.com',
        'http://localhost',
        'site',
        'https://.com',
      ]) {
        expect(Validators.lien(bad), isNotNull, reason: bad);
      }
      expect(Validators.normaliserLien('monsite.tn'), 'https://monsite.tn');
      expect(Validators.normaliserLien('HTTP://a.tn'), 'HTTP://a.tn');
    });

    test('image', () {
      expect(Validators.image(null, null), isNull); // facultative
      expect(Validators.image('photo.JPG', 1000), isNull);
      expect(Validators.image('doc.pdf', 1000), isNotNull);
      expect(Validators.image('photo.png', 6 * 1024 * 1024), isNotNull);
      expect(Validators.image('photo.png', 0), isNotNull);
    });

    test('métier et bio', () {
      expect(Validators.metier(''), isNull);
      expect(Validators.metier('Développeur Flutter'), isNull);
      expect(Validators.metier('UI/UX & Motion'), isNull);
      expect(Validators.metier('a'), isNotNull);
      expect(Validators.metier('<b>'), isNotNull);
      expect(Validators.bio('a' * 500), isNull);
      expect(Validators.bio('a' * 501), isNotNull);
    });
  });

  test('publier sans photo, puis lire le portfolio', () async {
    await service.publier(exemple(lien: 'resto.tn', clientNom: '  Le Golfe '));
    final liste = await service.getByFreelancer(freelancer);
    expect(liste.single.lien, 'https://resto.tn'); // normalisé
    expect(liste.single.client, 'Le Golfe'); // espaces retirés
    expect(liste.single.imagePath, isNull);
    expect(await service.getByFreelancer(client), isEmpty);
  });

  test(
    'la photo est copiée dans l\'app puis supprimée avec la réalisation',
    () async {
      final source = File(p.join(tmp.path, 'source.png'));
      await source.writeAsBytes(List.filled(100, 1));

      final r = await service.publier(exemple(), imageSource: source.path);
      expect(r.imagePath, isNotNull);
      expect(r.imagePath, isNot(source.path));
      expect(await File(r.imagePath!).exists(), isTrue);

      // un autre utilisateur ne peut pas la supprimer
      await service.supprimer(r, client);
      expect(await service.getByFreelancer(freelancer), hasLength(1));

      await service.supprimer(r, freelancer);
      expect(await service.getByFreelancer(freelancer), isEmpty);
      expect(await File(r.imagePath!).exists(), isFalse);
    },
  );

  test('le service refuse les données invalides', () async {
    expect(
      () => service.publier(exemple(lien: 'pas un lien')),
      throwsA(isA<RealisationException>()),
    );
    final pdf = File(p.join(tmp.path, 'cv.pdf'))..writeAsBytesSync([1, 2, 3]);
    expect(
      () => service.publier(exemple(), imageSource: pdf.path),
      throwsA(isA<RealisationException>()),
    );
    expect(await service.getByFreelancer(freelancer), isEmpty);
  });

  test('métier et bio enregistrés via le profil', () async {
    final u = await users.updateProfil(
      id: freelancer,
      username: 'sami',
      email: 'sami@test.com',
      metier: '  Développeur web ',
      bio: 'Je crée des sites rapides.',
    );
    expect(u.metier, 'Développeur web');
    expect(u.bio, 'Je crée des sites rapides.');

    // sans metier/bio : ils ne sont pas effacés
    final u2 = await users.updateProfil(
      id: freelancer,
      username: 'sami2',
      email: 'sami@test.com',
    );
    expect(u2.metier, 'Développeur web');

    expect(
      () => users.updateProfil(
        id: freelancer,
        username: 'sami',
        email: 'sami@test.com',
        bio: 'a' * 501,
      ),
      throwsA(isA<ProfilException>()),
    );
  });

  test(
    'migration v5 → v6 : colonnes métier/bio et table réalisations',
    () async {
      await DatabaseHelper.instance.close();
      final path = p.join(tmp.path, 'v5.db');
      final old = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE, password TEXT NOT NULL,
            role TEXT NOT NULL)''');
            await db.insert('users', {
              'username': 'ancien',
              'email': 'a@t.com',
              'password': 'x',
              'role': 'freelancer',
            });
          },
        ),
      );
      await old.close();

      DatabaseHelper.overridePath = path;
      final u = (await users.getUserById(1))!;
      expect(u.username, 'ancien');
      expect(u.bio, isNull);
      expect(await service.getByFreelancer(1), isEmpty); // la table existe
    },
  );

  group('écrans', () {
    testWidgets('le client voit le profil du freelancer (lecture seule)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await users.updateProfil(
          id: freelancer,
          username: 'sami',
          email: 'sami@test.com',
          metier: 'Développeur web',
          bio: 'Je crée des sites rapides.',
        );
        await service.publier(exemple(clientNom: 'Le Golfe'));
      });
      final viewer = (await tester.runAsync(() => users.getUserById(client)))!;

      await tester.pumpWidget(
        app(ProfilFreelancerScreen(freelancerId: freelancer, viewer: viewer)),
      );
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      expect(find.text('@sami'), findsOneWidget);
      expect(find.text('Développeur web'), findsOneWidget);
      expect(find.text('Je crée des sites rapides.'), findsOneWidget);
      expect(find.text('Site vitrine restaurant'), findsOneWidget);
      expect(find.text('Pour Le Golfe'), findsOneWidget);
      // pas de bouton Ajouter ni Supprimer pour le client
      expect(find.text('Ajouter'), findsNothing);
      expect(find.byTooltip('Supprimer'), findsNothing);
    });

    testWidgets('le freelancer voit son profil avec Ajouter', (tester) async {
      final moi = (await tester.runAsync(() => users.getUserById(freelancer)))!;
      await tester.pumpWidget(
        app(ProfilFreelancerScreen(freelancerId: freelancer, viewer: moi)),
      );
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      expect(find.text('Mon profil public'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);
      expect(find.text('Aucune réalisation'), findsOneWidget);
    });

    testWidgets('formulaire de réalisation : contrôle de saisie', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final moi = User(
        id: freelancer,
        username: 'sami',
        email: 'sami@test.com',
        password: '',
        role: 'freelancer',
      );
      await tester.pumpWidget(app(PublierRealisationScreen(user: moi)));

      final bouton = find.text('Publier la réalisation');
      await tester.ensureVisible(bouton);
      await tester.tap(bouton);
      await tester.pump();

      expect(find.text('Donne un titre à ta réalisation'), findsOneWidget);
      expect(find.text('Choisis une catégorie'), findsOneWidget);
      expect(find.text('Décris ce que tu as fait'), findsOneWidget);
      // la photo, le client et le lien sont facultatifs : pas d'erreur
      expect(find.textContaining('Lien invalide'), findsNothing);

      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'monsite.tn',
        ),
        'pas un lien',
      );
      await tester.pump();
      expect(find.text("Pas d'espace dans un lien"), findsOneWidget);
    });
  });
}
