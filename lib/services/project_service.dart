import '../database/database_helper.dart';
import '../models/app_notification.dart';
import '../models/project.dart';
import '../models/project_task.dart';
import 'notification_service.dart';

class ProjectService {
  final _dbHelper = DatabaseHelper.instance;

  Future<List<Project>> getProjectsForUser(int userId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT p.*,
             client.username AS client_username,
             freelancer.username AS freelancer_username,
             (SELECT COUNT(*) FROM project_tasks t
                WHERE t.project_id = p.id) AS total_tasks,
             (SELECT COUNT(*) FROM project_tasks t
                WHERE t.project_id = p.id AND t.status = 'validee')
                AS validated_tasks
      FROM projects p
      JOIN users client ON client.id = p.client_id
      JOIN users freelancer ON freelancer.id = p.freelancer_id
      WHERE p.client_id = ? OR p.freelancer_id = ?
      ORDER BY CASE p.status
        WHEN 'en_cours' THEN 0
        WHEN 'en_pause' THEN 1
        WHEN 'termine' THEN 2
        ELSE 3
      END, p.id DESC
      ''',
      [userId, userId],
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<List<Project>> getCompletedProjectsForFreelancer(
    int freelancerId,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT p.*,
             client.username AS client_username,
             freelancer.username AS freelancer_username,
             COUNT(t.id) AS total_tasks,
             SUM(CASE WHEN t.status = 'validee' THEN 1 ELSE 0 END)
               AS validated_tasks
      FROM projects p
      JOIN users client ON client.id = p.client_id
      JOIN users freelancer ON freelancer.id = p.freelancer_id
      JOIN project_tasks t ON t.project_id = p.id
      WHERE p.freelancer_id = ?
      GROUP BY p.id
      HAVING COUNT(t.id) > 0
         AND SUM(CASE WHEN t.status = 'validee' THEN 1 ELSE 0 END)
             = COUNT(t.id)
      ORDER BY p.updated_at DESC, p.id DESC
      ''',
      [freelancerId],
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<List<ProjectTask>> getTasks(int projectId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'project_tasks',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'id DESC',
    );
    return rows.map(ProjectTask.fromMap).toList();
  }

  Future<int> rewardCompletedProject({
    required int projectId,
    required int clientId,
    required int coins,
  }) async {
    if (coins < 1) {
      throw ArgumentError('Le nombre de CofeeCoins doit être positif.');
    }
    final db = await _dbHelper.database;
    late int freelancerId;
    late String projectTitle;
    final balance = await db.transaction((txn) async {
      final projects = await txn.query(
        'projects',
        columns: ['client_id', 'freelancer_id', 'status', 'title'],
        where: 'id = ?',
        whereArgs: [projectId],
        limit: 1,
      );
      if (projects.isEmpty || projects.first['client_id'] != clientId) {
        throw StateError(
          'Seul le client du projet peut offrir une récompense.',
        );
      }
      if (projects.first['status'] == 'termine') {
        throw StateError('Ce projet est déjà clôturé.');
      }
      final tasks = await txn.query(
        'project_tasks',
        columns: ['status'],
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
      if (tasks.isEmpty || tasks.any((task) => task['status'] != 'validee')) {
        throw StateError(
          'Toutes les tâches doivent être terminées avant la récompense.',
        );
      }
      final existing = await txn.query(
        'project_rewards',
        where: 'project_id = ?',
        whereArgs: [projectId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw StateError('La récompense a déjà été envoyée pour ce projet.');
      }
      final client = await txn.query(
        'users',
        columns: ['cofeecoins'],
        where: 'id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
      if (client.isEmpty || (client.first['cofeecoins'] as int) < coins) {
        throw StateError('Le client ne possède plus de CofeeCoin à offrir.');
      }
      freelancerId = projects.first['freelancer_id'] as int;
      projectTitle = projects.first['title'] as String;
      await txn.insert('project_rewards', {
        'project_id': projectId,
        'client_id': clientId,
        'freelancer_id': freelancerId,
        'coins': coins,
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.rawUpdate(
        'UPDATE users SET cofeecoins = cofeecoins - ?, '
        'cofeecoins_donnes = cofeecoins_donnes + ? WHERE id = ?',
        [coins, coins, clientId],
      );
      await txn.rawUpdate(
        'UPDATE users SET cofeecoins = cofeecoins + ? WHERE id = ?',
        [coins, freelancerId],
      );
      await txn.update(
        'projects',
        {'status': 'termine', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [projectId],
      );
      final user = await txn.query(
        'users',
        columns: ['cofeecoins'],
        where: 'id = ?',
        whereArgs: [freelancerId],
        limit: 1,
      );
      final balance = user.first['cofeecoins'] as int;
      return balance;
    });
    await NotificationService.instance.creerPour(
      [freelancerId],
      (userId) => AppNotification(
        userId: userId,
        type: AppNotification.typeProjet,
        titre: 'Projet terminé',
        contenu:
            'Le client t’a offert $coins CofeeCoin(s). Le projet « $projectTitle » est terminé.',
        acteurId: clientId,
        dateCreation: DateTime.now().toIso8601String(),
      ),
    );
    return balance;
  }

  Future<int> getClientCoinBalance(int clientId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'users',
      columns: ['cofeecoins'],
      where: 'id = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.first['cofeecoins'] as int;
  }

  Future<void> closeProjectWithoutReward({
    required int projectId,
    required int clientId,
  }) async {
    final db = await _dbHelper.database;
    late int freelancerId;
    late String title;
    await db.transaction((txn) async {
      final projects = await txn.query(
        'projects',
        columns: ['client_id', 'freelancer_id', 'title', 'status'],
        where: 'id = ?',
        whereArgs: [projectId],
        limit: 1,
      );
      if (projects.isEmpty || projects.first['client_id'] != clientId) {
        throw StateError('Seul le client peut clôturer ce projet.');
      }
      if (projects.first['status'] == 'termine') {
        throw StateError('Ce projet est déjà clôturé.');
      }
      final tasks = await txn.query(
        'project_tasks',
        columns: ['status'],
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
      if (tasks.isEmpty || tasks.any((task) => task['status'] != 'validee')) {
        throw StateError(
          'Toutes les tâches doivent être terminées avant la clôture.',
        );
      }
      final reward = await txn.query(
        'project_rewards',
        where: 'project_id = ?',
        whereArgs: [projectId],
        limit: 1,
      );
      if (reward.isNotEmpty) {
        throw StateError('Ce projet est déjà clôturé.');
      }
      freelancerId = projects.first['freelancer_id'] as int;
      title = projects.first['title'] as String;
      await txn.update(
        'projects',
        {'status': 'termine', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [projectId],
      );
    });
    await NotificationService.instance.creerPour(
      [freelancerId],
      (userId) => AppNotification(
        userId: userId,
        type: AppNotification.typeProjet,
        titre: 'Projet terminé',
        contenu: 'Le projet « $title » est terminé sans CofeeCoin.',
        acteurId: clientId,
        dateCreation: DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<bool> hasProjectReward(int projectId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'project_rewards',
      columns: ['id'],
      where: 'project_id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
