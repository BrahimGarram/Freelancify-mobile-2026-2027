import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sae2_brahim/database/database_helper.dart';
import 'package:sae2_brahim/models/app_notification.dart';
import 'package:sae2_brahim/models/user.dart';
import 'package:sae2_brahim/screens/notifications_screen.dart';
import 'package:sae2_brahim/screens/project_management_screen.dart';
import 'package:sae2_brahim/services/notification_service.dart';
import 'package:sae2_brahim/services/project_task_service.dart';
import 'package:sae2_brahim/services/user_service.dart';
import 'package:sae2_brahim/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  final taches = ProjectTaskService();
  late int client;
  late int freelancer;
  late int projet;

  setUp(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.overridePath = inMemoryDatabasePath;
    final users = UserService();
    client = await users.insertUser(
      User(username: 'imed', email: 'c@t.tn', password: 'p', role: 'client'),
    );
    freelancer = await users.insertUser(
      User(
        username: 'sami',
        email: 'f@t.tn',
        password: 'p',
        role: 'freelancer',
      ),
    );
    final db = await DatabaseHelper.instance.database;
    final post = await db.insert('posts', {
      'client_id': client,
      'titre': 'Un site',
      'description': 'Un site pour ma boulangerie',
      'budget': 100,
      'date_creation': '2026-11-01',
    });
    final candidature = await db.insert('candidatures', {
      'post_id': post,
      'freelancer_id': freelancer,
      'message': 'Bonjour, je suis disponible pour ce travail.',
      'statut': 'acceptee',
      'date_candidature': '2026-11-02',
    });
    projet = await db.insert('projects', {
      'candidature_id': candidature,
      'post_id': post,
      'client_id': client,
      'freelancer_id': freelancer,
      'title': 'Un site',
      'description': 'Un site pour ma boulangerie',
      'status': 'en_cours',
      'created_at': '2026-11-02',
      'updated_at': '2026-11-02',
    });
  });
  tearDown(() => DatabaseHelper.instance.close());

  Future<int> creerTache() => taches.createTask(
    projectId: projet,
    clientId: client,
    title: 'Maquette accueil',
    description: "Dessiner la page d'accueil complète du site web",
    priority: 'normale',
    driveUrl: 'https://drive.google.com/maquette',
  );

  Future<void> attendre(WidgetTester t) async {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
  }

  Future<void> afficher(WidgetTester t) async {
    final moi = (await t.runAsync(
      () => UserService().getUserById(freelancer),
    ))!;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: NotificationsScreen(user: moi),
      ),
    );
    await attendre(t);
  }

  test('la notification garde l\'identifiant de la tâche', () async {
    final id = await creerTache();
    final n = await NotificationService.instance.getNotifications(freelancer);
    expect(n.single.titre, 'Nouvelle tâche');
    expect(n.single.taskId, id);

    await taches.reviewTask(
      taskId: id,
      clientId: client,
      accepted: false,
      note: 'À reprendre',
    );
    final apres = await NotificationService.instance.getNotifications(
      freelancer,
    );
    expect(apres.first.titre, 'Corrections demandées');
    expect(apres.first.taskId, id);
  });

  testWidgets('un appui ouvre la tâche ; retour : liste des tâches', (t) async {
    await t.runAsync(creerTache);
    await afficher(t);

    await t.tap(find.text('Nouvelle tâche'));
    await attendre(t);
    expect(find.byType(TaskDetailsScreen), findsOneWidget);
    expect(find.text('Maquette accueil'), findsWidgets);

    await t.tap(find.byTooltip('Retour')); // flèche de l'en-tête
    await attendre(t);
    expect(find.byType(TaskDetailsScreen), findsNothing);
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('tâche supprimée : message clair', (t) async {
    await t.runAsync(() async {
      final id = await creerTache();
      final db = await DatabaseHelper.instance.database;
      await db.delete('project_tasks', where: 'id = ?', whereArgs: [id]);
    });
    await afficher(t);
    await t.tap(find.text('Nouvelle tâche'));
    await attendre(t);
    expect(find.text("Cette tâche n'existe plus."), findsOneWidget);
    expect(find.byType(TaskDetailsScreen), findsNothing);
  });

  testWidgets('ancienne notification sans tâche : liste des projets', (
    t,
  ) async {
    await t.runAsync(
      () => NotificationService.instance.creerPour(
        [freelancer],
        (u) => AppNotification(
          userId: u,
          type: AppNotification.typeProjet,
          titre: 'Tâche ancienne',
          contenu: 'Une tâche créée avant cette version.',
          dateCreation: DateTime.now().toIso8601String(),
        ),
      ),
    );
    await afficher(t);
    await t.tap(find.text('Tâche ancienne'));
    await attendre(t);
    expect(find.byType(ProjectManagementScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
