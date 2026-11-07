import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

class AbonnementException implements Exception {
  final String message;
  const AbonnementException(this.message);
  @override
  String toString() => message;
}

/// Un freelancer peut suivre des clients : il est alors notifié de leurs
/// nouveaux posts (voir [NotifieurAbonnes]).
class AbonnementService {
  final _dbHelper = DatabaseHelper.instance;

  Future<void> suivre({
    required int freelancerId,
    required int clientId,
  }) async {
    final db = await _dbHelper.database;
    final roles = await db.query(
      'users',
      columns: ['id', 'role'],
      where: 'id IN (?, ?)',
      whereArgs: [freelancerId, clientId],
    );
    String? role(int id) =>
        roles.where((r) => r['id'] == id).firstOrNull?['role'] as String?;
    if (role(freelancerId) != 'freelancer') {
      throw const AbonnementException(
        'Seul un freelancer peut suivre un client.',
      );
    }
    if (role(clientId) != 'client') {
      throw const AbonnementException('On ne peut suivre que des clients.');
    }
    await db.insert('abonnements', {
      'freelancer_id': freelancerId,
      'client_id': clientId,
      'date_abonnement': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore); // déjà suivi : rien
  }

  Future<void> nePlusSuivre({
    required int freelancerId,
    required int clientId,
  }) async {
    final db = await _dbHelper.database;
    await db.delete(
      'abonnements',
      where: 'freelancer_id = ? AND client_id = ?',
      whereArgs: [freelancerId, clientId],
    );
  }

  /// Les ids des clients suivis par ce freelancer
  Future<Set<int>> clientsSuivis(int freelancerId) async {
    final db = await _dbHelper.database;
    final lignes = await db.query(
      'abonnements',
      columns: ['client_id'],
      where: 'freelancer_id = ?',
      whereArgs: [freelancerId],
    );
    return lignes.map((l) => l['client_id'] as int).toSet();
  }

  /// Les clients suivis, avec leur nom et leur nombre de posts ouverts
  Future<List<({int id, String nom, int postsOuverts})>> detailsClientsSuivis(
    int freelancerId,
  ) async {
    final db = await _dbHelper.database;
    final lignes = await db.rawQuery(
      '''
      SELECT u.id, u.username,
             (SELECT COUNT(*) FROM posts p
              WHERE p.client_id = u.id AND p.statut = 'ouvert') AS ouverts
      FROM abonnements a JOIN users u ON u.id = a.client_id
      WHERE a.freelancer_id = ?
      ORDER BY a.date_abonnement DESC
    ''',
      [freelancerId],
    );
    return [
      for (final l in lignes)
        (
          id: l['id'] as int,
          nom: l['username'] as String,
          postsOuverts: l['ouverts'] as int,
        ),
    ];
  }

  /// Les ids des freelancers qui suivent ce client (ses « abonnés »)
  Future<List<int>> abonnes(int clientId) async {
    final db = await _dbHelper.database;
    final lignes = await db.query(
      'abonnements',
      columns: ['freelancer_id'],
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
    return lignes.map((l) => l['freelancer_id'] as int).toList();
  }

  Future<int> nbAbonnes(int clientId) async => (await abonnes(clientId)).length;
}
