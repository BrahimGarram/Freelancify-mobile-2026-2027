import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/app_notification.dart';
import '../observer/evenements.dart';
import '../observer/observer.dart';

/// Les notifications dans l'application.
///
/// C'est aussi le SUJET n°2 du pattern Observer : à chaque changement
/// (nouvelle notification, lecture…), il prévient ses observateurs
/// (la cloche 🔔 de l'en-tête, l'écran des notifications) qui se
/// mettent à jour tout seuls.
class NotificationService with Sujet<NotificationsModifiees> {
  NotificationService._();
  static final instance = NotificationService._();

  final _dbHelper = DatabaseHelper.instance;

  /// Crée la même notification pour plusieurs destinataires
  Future<void> creerPour(
    List<int> destinataires,
    AppNotification Function(int userId) creer,
  ) async {
    if (destinataires.isEmpty) return;
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final id in destinataires) {
      batch.insert('notifications', creer(id).toMap());
    }
    await batch.commit(noResult: true);
    for (final id in destinataires) {
      await notifierObservateurs(NotificationsModifiees(id));
    }
  }

  Future<List<AppNotification>> getNotifications(
    int userId, {
    int limite = 100,
  }) async {
    final db = await _dbHelper.database;
    final lignes = await db.rawQuery(
      '''
      SELECT n.*, u.username AS acteur_nom
      FROM notifications n LEFT JOIN users u ON u.id = n.acteur_id
      WHERE n.user_id = ?
      ORDER BY n.id DESC
      LIMIT ?
    ''',
      [userId, limite],
    );
    return lignes.map(AppNotification.fromMap).toList();
  }

  Future<int> nbNonLues(int userId) async {
    final db = await _dbHelper.database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM notifications WHERE user_id = ? AND lu = 0',
      [userId],
    );
    return r.first['n'] as int;
  }

  Future<void> marquerLue(AppNotification n) async {
    if (n.lu || n.id == null) return;
    final db = await _dbHelper.database;
    await db.update(
      'notifications',
      {'lu': 1},
      where: 'id = ?',
      whereArgs: [n.id],
    );
    await notifierObservateurs(NotificationsModifiees(n.userId));
  }

  Future<void> marquerToutesLues(int userId) async {
    final db = await _dbHelper.database;
    final n = await db.update(
      'notifications',
      {'lu': 1},
      where: 'user_id = ? AND lu = 0',
      whereArgs: [userId],
    );
    if (n > 0) await notifierObservateurs(NotificationsModifiees(userId));
  }

  @override
  Future<void> notifierObservateurs(NotificationsModifiees evenement) {
    debugPrint(
      '[OBSERVER] NotificationService → $nbObservateurs observateur(s) '
      '(utilisateur #${evenement.userId})',
    );
    return super.notifierObservateurs(evenement);
  }
}
