import '../database/database_helper.dart';
import '../models/post.dart';
import '../observer/evenements.dart';
import '../observer/flux_posts.dart';

class PostService {
  final _dbHelper = DatabaseHelper.instance;

  // Requête de base : le post + le nom du client + le nombre de candidatures
  static const _selectAvecInfos = '''
    SELECT p.*,
           u.username AS client_username,
           (SELECT COUNT(*) FROM candidatures c WHERE c.post_id = p.id)
             AS nb_candidatures
    FROM posts p
    JOIN users u ON u.id = p.client_id
  ''';

  /// Le client publie un nouveau post.
  /// Pattern Observer : le flux des posts (SUJET) prévient ensuite ses
  /// observateurs (notifications des abonnés, journal…).
  Future<int> insertPost(Post post) async {
    final db = await _dbHelper.database;
    final id = await db.insert('posts', post.toMap());

    final client = await db.query(
      'users',
      columns: ['username'],
      where: 'id = ?',
      whereArgs: [post.clientId],
      limit: 1,
    );
    await FluxPosts.instance.publier(
      PostPublie(
        postId: id,
        post: post,
        clientNom: client.isEmpty
            ? 'client'
            : client.first['username'] as String,
      ),
    );
    return id;
  }

  /// Un post avec ses infos (null s'il n'existe plus)
  Future<Post?> getPostById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('$_selectAvecInfos WHERE p.id = ?', [id]);
    return maps.isEmpty ? null : Post.fromMap(maps.first);
  }

  /// Tous les posts ouverts (le fil du Freelancer)
  Future<List<Post>> getPostsOuverts() async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      "$_selectAvecInfos WHERE p.statut = 'ouvert' ORDER BY p.id DESC",
    );
    return maps.map((m) => Post.fromMap(m)).toList();
  }

  /// Les posts d'un client (l'écran "Mes posts")
  Future<List<Post>> getPostsByClient(int clientId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      '$_selectAvecInfos WHERE p.client_id = ? ORDER BY p.id DESC',
      [clientId],
    );
    return maps.map((m) => Post.fromMap(m)).toList();
  }

  /// Change le statut d'un post ('ouvert', 'en_cours', 'termine')
  Future<int> updateStatut(int postId, String statut) async {
    final db = await _dbHelper.database;
    return await db.update(
      'posts',
      {'statut': statut},
      where: 'id = ?',
      whereArgs: [postId],
    );
  }

  /// Supprime un post (ses candidatures sont supprimées aussi : ON DELETE CASCADE)
  Future<int> deletePost(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('posts', where: 'id = ?', whereArgs: [id]);
  }
}
