import '../database/database_helper.dart';
import '../models/message.dart';
import '../utils/validators.dart';

/// Discussion entre un client et un freelancer, autour d'une candidature.
class MessageService {
  final _dbHelper = DatabaseHelper.instance;

  static const _selectConversations = '''
    SELECT c.id AS candidature_id, c.post_id, c.statut, c.freelancer_id,
           p.titre AS post_titre, p.client_id,
           uf.username AS freelancer_username,
           uf.cofeecoins AS freelancer_cofeecoins,
           uc.username AS client_username,
           m.contenu AS dernier_contenu,
           m.date_envoi AS dernier_date,
           m.expediteur_id AS dernier_expediteur,
           (SELECT COUNT(*) FROM messages nl
             WHERE nl.candidature_id = c.id AND nl.lu = 0
               AND nl.expediteur_id != ?) AS nb_non_lus
    FROM candidatures c
    JOIN posts p ON p.id = c.post_id
    JOIN users uf ON uf.id = c.freelancer_id
    JOIN users uc ON uc.id = p.client_id
    LEFT JOIN messages m ON m.id = (
      SELECT MAX(id) FROM messages WHERE candidature_id = c.id
    )
  ''';

  /// Les discussions d'un utilisateur (client ou freelancer),
  /// la plus récente en premier.
  Future<List<Conversation>> getConversations(int userId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      $_selectConversations
      WHERE c.freelancer_id = ? OR p.client_id = ?
      ORDER BY COALESCE(m.id, 0) DESC, c.id DESC
    ''',
      [userId, userId, userId],
    );
    return maps.map(Conversation.fromMap).toList();
  }

  /// Une seule discussion (pour ouvrir le chat depuis une candidature).
  /// Null si elle n'existe pas ou si [userId] n'y participe pas.
  Future<Conversation?> getConversation(int candidatureId, int userId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '''
      $_selectConversations
      WHERE c.id = ? AND (c.freelancer_id = ? OR p.client_id = ?)
    ''',
      [userId, candidatureId, userId, userId],
    );
    return maps.isEmpty ? null : Conversation.fromMap(maps.first);
  }

  /// Tous les messages d'une discussion, du plus ancien au plus récent.
  Future<List<Message>> getMessages(int candidatureId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'messages',
      where: 'candidature_id = ?',
      whereArgs: [candidatureId],
      orderBy: 'id ASC',
    );
    return maps.map(Message.fromMap).toList();
  }

  /// Envoie un message. Vérifie le contenu, que l'expéditeur participe
  /// bien à la discussion et que la candidature n'a pas été refusée.
  Future<Message> envoyer({
    required int candidatureId,
    required int expediteurId,
    required String contenu,
  }) async {
    final texte = contenu.trim();
    final erreur = Validators.messageChat(texte);
    if (erreur != null) throw MessageException(erreur);

    final conv = await getConversation(candidatureId, expediteurId);
    if (conv == null) {
      throw MessageException('Tu ne participes pas à cette discussion');
    }
    if (conv.fermee) {
      throw MessageException('Candidature refusée : discussion fermée');
    }

    final message = Message(
      candidatureId: candidatureId,
      expediteurId: expediteurId,
      contenu: texte,
      dateEnvoi: DateTime.now().toIso8601String(),
    );
    final db = await _dbHelper.database;
    final id = await db.insert('messages', message.toMap());
    return Message.fromMap({...message.toMap(), 'id': id});
  }

  /// Marque comme lus les messages reçus par [lecteurId] dans la discussion.
  Future<void> marquerLus(int candidatureId, int lecteurId) async {
    final db = await _dbHelper.database;
    await db.update(
      'messages',
      {'lu': 1},
      where: 'candidature_id = ? AND expediteur_id != ? AND lu = 0',
      whereArgs: [candidatureId, lecteurId],
    );
  }

  /// Nombre total de messages non lus (badge de l'onglet Messages).
  Future<int> nbNonLus(int userId) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      '''
      SELECT COUNT(*) AS n
      FROM messages m
      JOIN candidatures c ON c.id = m.candidature_id
      JOIN posts p ON p.id = c.post_id
      WHERE m.lu = 0 AND m.expediteur_id != ?
        AND (c.freelancer_id = ? OR p.client_id = ?)
    ''',
      [userId, userId, userId],
    );
    return (res.first['n'] as int?) ?? 0;
  }
}

/// Erreur « normale » d'envoi de message (message pour l'utilisateur).
class MessageException implements Exception {
  final String message;
  MessageException(this.message);

  @override
  String toString() => message;
}
