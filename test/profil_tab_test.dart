import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/profil_tab.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sae2_brahim/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  final users = UserService();

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
  });
  tearDown(() => DatabaseHelper.instance.close());

  Future<void> afficher(WidgetTester tester, User u, {Size? taille}) async {
    if (taille != null) {
      tester.view.physicalSize = taille * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: ProfilTab(user: u, onUserChanged: (_) {}),
        ),
      ),
    );
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }

  Future<User> creer(WidgetTester tester, String role) async {
    return (await tester.runAsync(() async {
      final id = await users.insertUser(
        User(
          username: 'sami',
          email: 's@t.com',
          password: 'pass1234',
          role: role,
        ),
      );
      return users.getUserById(id);
    }))!;
  }

  testWidgets('freelancer : stats, profil à compléter et menu', (tester) async {
    final u = await creer(tester, 'freelancer');
    await afficher(tester, u);
    expect(find.text('@sami'), findsOneWidget);
    expect(find.text('Candidatures'), findsOneWidget);
    expect(find.text('Réalisations'), findsOneWidget);
    expect(find.text('Complète ton profil'), findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mon profil public'), 200);
    expect(find.text('Mon profil public'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Se déconnecter'), 200);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });

  testWidgets('client : pas de portfolio, déconnexion confirmée', (
    tester,
  ) async {
    final u = await creer(tester, 'client');
    await afficher(tester, u);
    expect(find.text('Posts publiés'), findsOneWidget);
    expect(find.text('Complète ton profil'), findsNothing);
    expect(find.text('Mon profil public'), findsNothing);

    await tester.scrollUntilVisible(find.text('Se déconnecter'), 200);
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(find.text('Se déconnecter ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Se déconnecter ?'), findsNothing);
  });

  testWidgets('petit écran (320 dp) : aucun débordement', (tester) async {
    final u = await creer(tester, 'freelancer');
    await afficher(tester, u, taille: const Size(320, 568));
    expect(tester.takeException(), isNull);
  });
}
