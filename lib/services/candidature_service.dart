import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/candidature.dart';
import 'mail/mail_service.dart';

class CandidatureService {
  final _dbHelper = DatabaseHelper.instance;

  /// Le freelancer postule à un post.
  /// Son message devient aussi le 1er message de la discussion avec le client,
  /// et le client est prévenu par email.
  Future<int> postuler(Candidature candidature) async {
    final db = await _dbHelper.database;
    final id = await db.transaction((txn) async {
      final id = await txn.insert('candidatures', candidature.toMap());
      await txn.insert('messages', {
        'candidature_id': id,
        'expediteur_id': candidature.freelancerId,
        'contenu': candidature.message,
        'date_envoi': candidature.dateCandidature,
        'lu': 0,
      });
      return id;
    });

    // Email au client, en arrière-plan : le freelancer n'attend pas, et un
    // problème d'email n'annule jamais la candidature.
    unawaited(
      MailService.instance
          .notifierNouvelleCandidature(id)
          .catchError(
            (Object e) => debugPrint('[MAIL] ❌ Notification impossible : $e'),
          ),
    );
    return id;
  }

  /// Les ids des posts auxquels ce freelancer a déjà postulé
  /// (pour afficher "Postulé" au lieu de "Postuler")
  Future<Set<int>> getPostIdsPostules(int freelancerId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'candidatures',
      columns: ['post_id'],
      where: 'freelancer_id = ?',
      whereArgs: [freelancerId],
    );
    return maps.map((m) => m['post_id'] as int).toSet();
  }

  /// Les candidatures envoyées par un freelancer (avec le titre du post)
  Future<List<Candidature>> getCandidaturesByFreelancer(
    int freelancerId,
  ) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT c.*, p.titre AS post_titre, p.budget AS post_budget,
             p.type_budget AS post_type_budget, u.username AS client_username
      FROM candidatures c
      JOIN posts p ON p.id = c.post_id
      JOIN users u ON u.id = p.client_id
      WHERE c.freelancer_id = ?
      ORDER BY c.id DESC
    ''',
      [freelancerId],
    );
    return maps.map((m) => Candidature.fromMap(m)).toList();
  }

  /// Toutes les candidatures reçues par un client (sur tous ses posts)
  Future<List<Candidature>> getCandidaturesByClient(int clientId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT c.*, p.titre AS post_titre, p.budget AS post_budget,
             p.type_budget AS post_type_budget,
             u.username AS freelancer_username
      FROM candidatures c
      JOIN posts p ON p.id = c.post_id
      JOIN users u ON u.id = c.freelancer_id
      WHERE p.client_id = ?
      ORDER BY CASE c.statut WHEN 'en_attente' THEN 0 ELSE 1 END, c.id DESC
    ''',
      [clientId],
    );
    return maps.map((m) => Candidature.fromMap(m)).toList();
  }

  /// Les candidatures reçues pour un post (avec le nom du freelancer)
  Future<List<Candidature>> getCandidaturesByPost(int postId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT c.*, u.username AS freelancer_username
      FROM candidatures c
      JOIN users u ON u.id = c.freelancer_id
      WHERE c.post_id = ?
      ORDER BY c.id DESC
    ''',
      [postId],
    );
    return maps.map((m) => Candidature.fromMap(m)).toList();
  }

  /// Le client accepte une candidature, en une seule transaction :
  /// - la candidature passe à 'acceptee' ;
  /// - les autres candidatures du même post passent à 'refusee' ;
  /// - le post passe à 'en_cours' (il disparaît du fil des freelancers).
  Future<void> accepterCandidature(int candidatureId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'candidatures',
        columns: ['post_id'],
        where: 'id = ?',
        whereArgs: [candidatureId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final postId = rows.first['post_id'] as int;

      await txn.update(
        'candidatures',
        {'statut': 'acceptee'},
        where: 'id = ?',
        whereArgs: [candidatureId],
      );
      await txn.update(
        'candidatures',
        {'statut': 'refusee'},
        where: 'post_id = ? AND id != ?',
        whereArgs: [postId, candidatureId],
      );
      await txn.update(
        'posts',
        {'statut': 'en_cours'},
        where: 'id = ?',
        whereArgs: [postId],
      );

      final post = (await txn.query(
        'posts',
        columns: ['client_id', 'titre', 'description', 'date_limite'],
        where: 'id = ?',
        whereArgs: [postId],
        limit: 1,
      )).first;
      final candidature = (await txn.query(
        'candidatures',
        columns: ['freelancer_id', 'date_candidature'],
        where: 'id = ?',
        whereArgs: [candidatureId],
        limit: 1,
      )).first;
      final now = DateTime.now().toIso8601String();
      final existingProject = await txn.query(
        'projects',
        columns: ['id'],
        where: 'candidature_id = ?',
        whereArgs: [candidatureId],
        limit: 1,
      );
      if (existingProject.isEmpty) {
        await txn.insert('projects', {
          'candidature_id': candidatureId,
          'post_id': postId,
          'client_id': post['client_id'],
          'freelancer_id': candidature['freelancer_id'],
          'title': post['titre'],
          'description': post['description'],
          'deadline': post['date_limite'],
          'status': 'en_cours',
          'created_at': candidature['date_candidature'] ?? now,
          'updated_at': now,
        });
        await txn.rawUpdate(
          'UPDATE users SET cofeecoins = cofeecoins + 1 WHERE id = ?',
          [post['client_id']],
        );
      }
    });
  }

  /// Refuser une candidature
  Future<int> refuserCandidature(int candidatureId) =>
      updateStatut(candidatureId, 'refusee');

  /// Changer le statut d'une candidature
  Future<int> updateStatut(int candidatureId, String statut) async {
    final db = await _dbHelper.database;
    return await db.update(
      'candidatures',
      {'statut': statut},
      where: 'id = ?',
      whereArgs: [candidatureId],
    );
  }
}
