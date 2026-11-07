import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/post.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/observer/evenements.dart';
import 'package:sae2_brahim/observer/flux_posts.dart';
import 'package:sae2_brahim/observer/observateurs_posts.dart';
import 'package:sae2_brahim/observer/observer.dart';
import 'package:sae2_brahim/services/abonnement_service.dart';
import 'package:sae2_brahim/services/notification_service.dart';
import 'package:sae2_brahim/services/post_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sae2_brahim/theme/app_theme.dart';
import 'package:sae2_brahim/widgets/cloche_notifications.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Sujet de test
class Compteur with Sujet<int> {
  Future<void> emettre(int v) => notifierObservateurs(v);
}

/// Observateur de test : enregistre ce qu'il reçoit
class Espion<E> implements Observateur<E> {
  final List<E> recus = [];
  final bool planter;
  Espion({this.planter = false});
  @override
  void mettreAJour(E e) {
    if (planter) throw StateError('boum');
    recus.add(e);
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  group('pattern Observer (générique)', () {
    test('abonner, notifier, désabonner', () async {
      final sujet = Compteur();
      final a = Espion<int>(), b = Espion<int>();
      sujet
        ..abonner(a)
        ..abonner(b)
        ..abonner(a); // pas de doublon
      expect(sujet.nbObservateurs, 2);

      await sujet.emettre(1);
      sujet.desabonner(a);
      await sujet.emettre(2);

      expect(a.recus, [1]);
      expect(b.recus, [1, 2]);
    });

    test('un observateur qui plante ne bloque pas les autres', () async {
      final sujet = Compteur();
      final ok = Espion<int>();
      sujet
        ..abonner(Espion<int>(planter: true))
        ..abonner(ok);
      await sujet.emettre(7);
      expect(ok.recus, [7]);
    });
  });

  group('suivre un client et notifications', () {
    final users = UserService();
    final posts = PostService();
    final abonnements = AbonnementService();
    final notifications = NotificationService.instance;
    final now = DateTime.now().toIso8601String();
    late int client, sami, lina;

    Post post(String titre) => Post(
      clientId: client,
      titre: titre,
      description: 'Une description suffisamment longue.',
      budget: 200,
      dateCreation: now,
    );

    setUp(() async {
      await DatabaseHelper.instance.close();
      DatabaseHelper.overridePath = inMemoryDatabasePath;
      configurerObservateurs();
      client = await users.insertUser(
        User(username: 'imed', email: 'i@t.tn', password: 'p', role: 'client'),
      );
      sami = await users.insertUser(
        User(
          username: 'sami',
          email: 's@t.tn',
          password: 'p',
          role: 'freelancer',
        ),
      );
      lina = await users.insertUser(
        User(
          username: 'lina',
          email: 'l@t.tn',
          password: 'p',
          role: 'freelancer',
        ),
      );
    });
    tearDown(() async {
      FluxPosts.instance.desabonnerTous();
      await DatabaseHelper.instance.close();
    });

    test('au démarrage, 2 observateurs écoutent le flux des posts', () {
      expect(FluxPosts.instance.nbObservateurs, 2);
    });

    test(
      'seuls les abonnés reçoivent la notification du nouveau post',
      () async {
        await abonnements.suivre(freelancerId: sami, clientId: client);
        final id = await posts.insertPost(post('Logo pour ma boulangerie'));

        final n = (await notifications.getNotifications(sami)).single;
        expect(n.titre, '@imed a publié une nouvelle mission');
        expect(n.contenu, 'Logo pour ma boulangerie');
        expect(n.postId, id);
        expect(n.acteurNom, 'imed');
        expect(n.lu, isFalse);
        expect(await notifications.nbNonLues(sami), 1);
        expect(
          await notifications.getNotifications(lina),
          isEmpty,
        ); // pas abonnée
      },
    );

    test('le service de notifications prévient ses observateurs', () async {
      final espion = Espion<NotificationsModifiees>();
      notifications.abonner(espion);
      addTearDown(() => notifications.desabonner(espion));

      await abonnements.suivre(freelancerId: sami, clientId: client);
      await posts.insertPost(post('Montage vidéo'));
      expect(espion.recus.map((e) => e.userId), [sami]);

      final n = (await notifications.getNotifications(sami)).single;
      await notifications.marquerLue(n);
      expect(await notifications.nbNonLues(sami), 0);
      expect(espion.recus, hasLength(2));
    });

    test('ne plus suivre : plus de notification', () async {
      await abonnements.suivre(freelancerId: sami, clientId: client);
      await abonnements.suivre(freelancerId: sami, clientId: client); // 2×: ok
      expect(await abonnements.nbAbonnes(client), 1);
      await abonnements.nePlusSuivre(freelancerId: sami, clientId: client);
      await posts.insertPost(post('Traduction'));
      expect(await notifications.getNotifications(sami), isEmpty);
    });

    test('règles : un freelancer suit un client, rien d\'autre', () async {
      expect(
        () => abonnements.suivre(freelancerId: client, clientId: client),
        throwsA(isA<AbonnementException>()),
      );
      expect(
        () => abonnements.suivre(freelancerId: sami, clientId: lina),
        throwsA(isA<AbonnementException>()),
      );
    });

    test('post supprimé : sa notification disparaît aussi', () async {
      await abonnements.suivre(freelancerId: sami, clientId: client);
      final id = await posts.insertPost(post('Site vitrine'));
      await posts.deletePost(id);
      expect(await notifications.getNotifications(sami), isEmpty);
    });

    testWidgets('la cloche 🔔 se met à jour toute seule (observateur UI)', (
      tester,
    ) async {
      final moi = (await tester.runAsync(() async {
        await abonnements.suivre(freelancerId: sami, clientId: client);
        return users.getUserById(sami);
      }))!;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(child: ClocheNotifications(user: moi)),
          ),
        ),
      );
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.text('1'), findsNothing);
      expect(NotificationService.instance.nbObservateurs, greaterThan(0));

      // le client publie : la pastille passe à 1 sans recharger l'écran
      await tester.runAsync(() async {
        await posts.insertPost(post('Application mobile'));
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      // l'écran disparaît : la cloche se désabonne
      final avant = NotificationService.instance.nbObservateurs;
      await tester.pumpWidget(const SizedBox());
      expect(NotificationService.instance.nbObservateurs, avant - 1);
    });
  });
}
