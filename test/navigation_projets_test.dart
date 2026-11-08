import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/candidatures_tab.dart';
import 'package:sae2_brahim/screens/client/client_home.dart';
import 'package:sae2_brahim/screens/freelancer/freelancer_home.dart';
import 'package:sae2_brahim/screens/messages/messages_tab.dart';
import 'package:sae2_brahim/screens/profil_tab.dart';
import 'package:sae2_brahim/screens/project_management_screen.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sae2_brahim/theme/app_theme.dart';
import 'package:sae2_brahim/widgets/home_widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
  });
  tearDown(() => DatabaseHelper.instance.close());

  Future<void> attendre(WidgetTester t) async {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await t.pumpAndSettle();
  }

  /// Accueil → onglet Profil → « Gestion des projets »
  Future<void> ouvrirProjets(WidgetTester t, String role) async {
    t.view.physicalSize = const Size(864, 1920);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final moi = (await t.runAsync<User?>(() async {
      final id = await UserService().insertUser(
        User(username: 'sami', email: 's@t.tn', password: 'p', role: role),
      );
      return UserService().getUserById(id);
    }))!;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: role == 'client'
            ? ClientHome(user: moi)
            : FreelancerHome(user: moi),
      ),
    );
    await attendre(t);
    await t.tap(find.text('Profil'));
    await attendre(t);
    await t.scrollUntilVisible(
      find.text('Gestion des projets'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Gestion des projets'));
    await attendre(t);
    expect(find.byType(ProjectManagementScreen), findsOneWidget);
  }

  /// Retour direct à l'accueil : plus aucun écran à fermer, barre visible
  void verifierAccueil(WidgetTester t, Type onglet) {
    expect(find.byType(ProjectManagementScreen), findsNothing);
    expect(find.byType(onglet), findsOneWidget);
    expect(
      find.ancestor(of: find.byType(onglet), matching: find.byType(Scaffold)),
      findsWidgets,
    );
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(
      Navigator.of(t.element(find.byType(AppBottomNav))).canPop(),
      isFalse,
    );
    final barre = t.widget<AppBottomNav>(find.byType(AppBottomNav));
    expect(barre.onPlus, isNotNull);
    expect(t.takeException(), isNull);
  }

  for (final role in ['client', 'freelancer']) {
    testWidgets('$role : Messages garde le style et la barre du bas', (
      t,
    ) async {
      await ouvrirProjets(t, role);
      await t.tap(find.text('Messages'));
      await attendre(t);
      verifierAccueil(t, MessagesTab);
      expect(t.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex, 2);
    });

    testWidgets('$role : Profil revient à l\'onglet Profil', (t) async {
      await ouvrirProjets(t, role);
      await t.tap(find.text('Profil'));
      await attendre(t);
      verifierAccueil(t, ProfilTab);
      expect(t.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex, 3);
    });

    testWidgets('$role : Candidatures en un seul appui', (t) async {
      await ouvrirProjets(t, role);
      await t.tap(find.text('Candidatures'));
      await attendre(t);
      verifierAccueil(t, CandidaturesTab);
    });
  }
}
