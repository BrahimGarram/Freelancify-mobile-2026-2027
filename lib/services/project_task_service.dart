import 'package:flutter/foundation.dart';
import 'package:file_saver/file_saver.dart';

import '../database/database_helper.dart';
import '../models/app_notification.dart';
import '../models/project_task.dart';
import 'notification_service.dart';

class ProjectTaskService {
  final _db = DatabaseHelper.instance;

  Future<List<ProjectTask>> getTasks(int projectId) async {
    final rows = await (await _db.database).query(
      'project_tasks',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy:
          'CASE priority WHEN "urgente" THEN 0 WHEN "haute" THEN 1 '
          'WHEN "normale" THEN 2 ELSE 3 END, id DESC',
    );
    return rows.map(ProjectTask.fromMap).toList();
  }

  /// La tâche [taskId], ou null si elle n'existe plus
  Future<ProjectTask?> getTask(int taskId) async {
    final rows = await (await _db.database).query(
      'project_tasks',
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    return rows.isEmpty ? null : ProjectTask.fromMap(rows.first);
  }

  Future<int> createTask({
    required int projectId,
    required int clientId,
    required String title,
    required String description,
    required String priority,
    String? dueDate,
    String? driveUrl,
    String? githubUrl,
    String? attachmentName,
    String? attachmentMime,
    List<int>? attachmentBytes,
  }) async {
    _validateTaskContent(title, description);
    _validateTaskResource(
      driveUrl: driveUrl,
      githubUrl: githubUrl,
      attachmentName: attachmentName,
      attachmentBytes: attachmentBytes,
    );
    final db = await _db.database;
    final project = await db.query(
      'projects',
      columns: ['client_id', 'freelancer_id', 'title'],
      where: 'id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    if (project.isEmpty || project.first['client_id'] != clientId) {
      throw StateError('Seul le client du projet peut créer une tâche.');
    }
    if (project.first['status'] == 'termine') {
      throw StateError(
        'Ce projet est terminé : aucune nouvelle tâche possible.',
      );
    }
    final now = DateTime.now().toIso8601String();
    final taskId = await db.insert('project_tasks', {
      'project_id': projectId,
      'title': title.trim(),
      'description': description.trim(),
      'priority': priority,
      'due_date': dueDate,
      'drive_url': _cleanUrl(driveUrl),
      'github_url': _cleanUrl(githubUrl),
      'attachment_name': attachmentName,
      'attachment_mime': attachmentMime,
      'attachment_bytes': attachmentBytes,
      'created_by': clientId,
      'assigned_to': project.first['freelancer_id'],
      'created_at': now,
      'updated_at': now,
    });
    await NotificationService.instance.creerPour(
      [project.first['freelancer_id'] as int],
      (userId) => AppNotification(
        userId: userId,
        type: AppNotification.typeProjet,
        taskId: taskId,
        titre: 'Nouvelle tâche',
        contenu:
            'La tâche « ${title.trim()} » a été ajoutée au projet « ${project.first['title']} ».',
        acteurId: clientId,
        dateCreation: now,
      ),
    );
    return taskId;
  }

  Future<String?> downloadAttachment(ProjectTask task) async {
    if (task.attachmentBytes == null || task.attachmentName == null) {
      throw StateError('Cette tâche ne contient pas de fichier.');
    }
    return _saveFile(task.attachmentName!, task.attachmentBytes!);
  }

  Future<String?> downloadWorkAttachment(ProjectTask task) async {
    if (task.workAttachmentBytes == null || task.workAttachmentName == null) {
      throw StateError('Le travail soumis ne contient pas de fichier.');
    }
    return _saveFile(task.workAttachmentName!, task.workAttachmentBytes!);
  }

  Future<String?> _saveFile(String name, List<int> bytes) async {
    if (bytes.isEmpty) {
      throw StateError('Le fichier est vide ou indisponible.');
    }
    final separator = name.lastIndexOf('.');
    final hasExtension = separator > 0 && separator < name.length - 1;
    final fileName = hasExtension ? name.substring(0, separator) : name;
    final extension = hasExtension ? name.substring(separator + 1) : '';
    return FileSaver.instance.saveAs(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: extension,
      mimeType: MimeType.other,
      dialogTitle: 'Enregistrer le fichier',
    );
  }

  Future<int> updateTask({
    required int taskId,
    required int clientId,
    required String title,
    required String description,
    required String priority,
    String? dueDate,
    String? driveUrl,
    String? githubUrl,
    String? attachmentName,
    String? attachmentMime,
    List<int>? attachmentBytes,
  }) async {
    _validateTaskContent(title, description);
    _validateTaskResource(
      driveUrl: driveUrl,
      githubUrl: githubUrl,
      attachmentName: attachmentName,
      attachmentBytes: attachmentBytes,
    );
    final db = await _db.database;
    final task = await db.rawQuery(
      '''
      SELECT t.id, t.status, t.work_description, t.work_link,
             t.work_attachment_name, p.client_id
      FROM project_tasks t
      JOIN projects p ON p.id = t.project_id
      WHERE t.id = ?
      LIMIT 1
      ''',
      [taskId],
    );
    if (task.isEmpty || task.first['client_id'] != clientId) {
      throw StateError('Seul le client du projet peut modifier une tâche.');
    }

    if (_taskHasSubmission(task.first)) {
      throw StateError(
        'Cette tâche ne peut plus être modifiée après soumission du travail.',
      );
    }
    return db.update(
      'project_tasks',
      {
        'title': title.trim(),
        'description': description.trim(),
        'priority': priority,
        'due_date': dueDate,
        'drive_url': _cleanUrl(driveUrl),
        'github_url': _cleanUrl(githubUrl),
        'attachment_name': attachmentName,
        'attachment_mime': attachmentMime,
        'attachment_bytes': attachmentBytes,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  void _validateTaskContent(String title, String description) {
    if (title.trim().length < 8) {
      throw ArgumentError(
        'Le titre de la tâche doit contenir au moins 8 caractères.',
      );
    }
    if (description.trim().length < 30) {
      throw ArgumentError(
        'La description doit contenir au moins 30 caractères.',
      );
    }
  }

  void _validateTaskResource({
    String? driveUrl,
    String? githubUrl,
    String? attachmentName,
    List<int>? attachmentBytes,
  }) {
    final hasLink =
        driveUrl?.trim().isNotEmpty == true ||
        githubUrl?.trim().isNotEmpty == true;
    final hasFile =
        attachmentName?.trim().isNotEmpty == true &&
        attachmentBytes != null &&
        attachmentBytes.isNotEmpty;
    if (!hasLink && !hasFile) {
      throw ArgumentError(
        'Ajoute au moins un lien ou un fichier comme ressource.',
      );
    }
  }

  Future<int> deleteTask({required int taskId, required int clientId}) async {
    final db = await _db.database;
    final task = await db.rawQuery(
      '''
      SELECT t.id, t.status, t.work_description, t.work_link,
             t.work_attachment_name
      FROM project_tasks t
      JOIN projects p ON p.id = t.project_id
      WHERE t.id = ? AND p.client_id = ?
      LIMIT 1
      ''',
      [taskId, clientId],
    );
    if (task.isEmpty) {
      throw StateError('Seul le client du projet peut supprimer une tâche.');
    }
    if (_taskHasSubmission(task.first)) {
      throw StateError(
        'Cette tâche ne peut plus être supprimée après soumission du travail.',
      );
    }
    return db.delete('project_tasks', where: 'id = ?', whereArgs: [taskId]);
  }

  bool _taskHasSubmission(Map<String, Object?> task) {
    final status = task['status'] as String?;
    return status == 'a_valider' ||
        status == 'validee' ||
        status == 'refusee' ||
        (task['work_description'] as String?)?.trim().isNotEmpty == true ||
        (task['work_link'] as String?)?.trim().isNotEmpty == true ||
        task['work_attachment_name'] != null;
  }

  Future<void> acceptTask({
    required int taskId,
    required int freelancerId,
  }) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT id FROM project_tasks WHERE id = ? AND assigned_to = ?',
      [taskId, freelancerId],
    );
    if (rows.isEmpty) {
      throw StateError('Cette tâche ne vous est pas attribuée.');
    }
    await db.update(
      'project_tasks',
      {'status': 'en_cours', 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> submitTask({
    required int taskId,
    required int freelancerId,
    required String description,
    String? link,
    String? attachmentName,
    String? attachmentMime,
    List<int>? attachmentBytes,
  }) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT t.id, t.status, t.due_date, t.title, p.client_id,
             p.candidature_id, p.title AS project_title
      FROM project_tasks t
      JOIN projects p ON p.id = t.project_id
      WHERE t.id = ? AND t.assigned_to = ?
      ''',
      [taskId, freelancerId],
    );
    if (rows.isEmpty) {
      throw StateError('Cette tâche ne vous est pas attribuée.');
    }
    final status = rows.first['status'] as String;
    if (status != 'en_cours' && status != 'refusee' && status != 'a_valider') {
      throw StateError('La tâche ne peut plus recevoir de modification.');
    }
    final dueDate = DateTime.tryParse(rows.first['due_date'] as String? ?? '');
    if (dueDate != null) {
      final deadlineEnd = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        23,
        59,
        59,
        999,
      );
      if (DateTime.now().isAfter(deadlineEnd)) {
        throw StateError(
          'Vous ne respectez pas la date limite de cette tâche.',
        );
      }
    }
    if (description.trim().length < 30) {
      throw ArgumentError(
        'La description du travail doit contenir au moins 30 caractères.',
      );
    }
    final hasLink = link?.trim().isNotEmpty == true;
    final hasFile =
        attachmentName?.trim().isNotEmpty == true &&
        attachmentBytes != null &&
        attachmentBytes.isNotEmpty;
    if (!hasLink && !hasFile) {
      throw ArgumentError(
        'Ajoutez au moins un lien ou un fichier comme ressource.',
      );
    }
    final now = DateTime.now().toIso8601String();
    final title = rows.first['title'] as String;
    await db.transaction((txn) async {
      await txn.update(
        'project_tasks',
        {
          'status': 'a_valider',
          'work_description': description.trim(),
          'work_link': _cleanUrl(link),
          'work_attachment_name': attachmentName,
          'work_attachment_mime': attachmentMime,
          'work_attachment_bytes': attachmentBytes,
          'review_note': null,
          'reviewed_at': null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );
      if (status != 'a_valider') {
        await txn.insert('messages', {
          'candidature_id': rows.first['candidature_id'],
          'expediteur_id': freelancerId,
          'contenu':
              'La tâche « $title » est terminée. Peux-tu revoir le travail soumis ?',
          'date_envoi': now,
          'lu': 0,
        });
      }
    });
    if (status != 'a_valider') {
      await NotificationService.instance.creerPour(
        [rows.first['client_id'] as int],
        (userId) => AppNotification(
          userId: userId,
          type: AppNotification.typeProjet,
          taskId: taskId,
          titre: 'Tâche terminée',
          contenu:
              'Le freelancer a soumis le travail pour une tâche de ton projet.',
          acteurId: freelancerId,
          dateCreation: DateTime.now().toIso8601String(),
        ),
      );
    }
  }

  Future<void> reviewTask({
    required int taskId,
    required int clientId,
    required bool accepted,
    required String note,
  }) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
        SELECT t.id, t.title, t.assigned_to, p.title AS project_title
        FROM project_tasks t
        JOIN projects p ON p.id = t.project_id
        WHERE t.id = ? AND p.client_id = ?
        ''',
      [taskId, clientId],
    );
    if (rows.isEmpty) {
      throw StateError('Vous ne pouvez pas revoir cette tâche.');
    }
    if (note.trim().isEmpty) {
      throw ArgumentError('Ajoutez une note de revue.');
    }
    await db.update(
      'project_tasks',
      {
        'status': accepted ? 'validee' : 'refusee',
        'review_note': note.trim(),
        'reviewed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
    if (rows.isNotEmpty) {
      final task = rows.first;
      await NotificationService.instance.creerPour(
        [task['assigned_to'] as int],
        (userId) => AppNotification(
          userId: userId,
          type: AppNotification.typeProjet,
          taskId: taskId,
          titre: accepted ? 'Travail validé' : 'Corrections demandées',
          contenu: accepted
              ? 'La tâche « ${task['title']} » du projet « ${task['project_title']} » a été validée par le client.'
              : 'Des corrections sont demandées pour la tâche « ${task['title']} » du projet « ${task['project_title']} ».',
          acteurId: clientId,
          dateCreation: DateTime.now().toIso8601String(),
        ),
      );
    }
  }

  String? _cleanUrl(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
