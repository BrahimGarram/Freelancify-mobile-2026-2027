import '../database/database_helper.dart';
import '../models/user.dart';
import '../utils/validators.dart';
import 'password_hasher.dart';

class UserService {
  final _dbHelper = DatabaseHelper.instance;

  /// Crée un utilisateur. `user.password` est le mot de passe EN CLAIR :
  /// il est haché ici, avant d'être enregistré.
  Future<int> insertUser(User user) async {
    final db = await _dbHelper.database;
    final map = user.toMap()..['password'] = PasswordHasher.hash(user.password);
    return await db.insert('users', map);
  }

  Future<List<User>> getUsers() async {
    final db = await _dbHelper.database;
    final maps = await db.query('users', orderBy: 'id DESC');
    return maps.map((m) => User.fromMap(m)).toList();
  }

  Future<User?> getUserById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty ? User.fromMap(maps.first) : null;
  }

  /// Connexion : on cherche l'utilisateur par email, puis on compare
  /// le mot de passe saisi avec le hash enregistré.
  Future<User?> login(String email, String password) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final user = User.fromMap(maps.first);
    return PasswordHasher.verify(password, user.password) ? user : null;
  }

  /// Vérifie si un email est déjà utilisé.
  /// [saufId] : ignore cet utilisateur (pour la modification de son profil).
  Future<bool> emailExists(String email, {int? saufId}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      columns: ['id'],
      where: saufId == null ? 'email = ?' : 'email = ? AND id != ?',
      whereArgs: saufId == null ? [email] : [email, saufId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// Modifie le profil d'un utilisateur et renvoie l'utilisateur à jour.
  ///
  /// [metier] et [bio] (profil public) ne sont modifiés que s'ils sont
  /// fournis ; une chaîne vide les efface.
  /// Pour changer de mot de passe, il faut fournir [nouveauMotDePasse]
  /// ET le [motDePasseActuel] correct.
  /// Lève une [ProfilException] (message à afficher) en cas de refus.
  Future<User> updateProfil({
    required int id,
    required String username,
    required String email,
    String? motDePasseActuel,
    String? nouveauMotDePasse,
    String? metier,
    String? bio,
  }) async {
    final db = await _dbHelper.database;
    final actuel = await getUserById(id);
    if (actuel == null) throw ProfilException('Utilisateur introuvable');

    final emailNormalise = email.trim().toLowerCase();
    if (await emailExists(emailNormalise, saufId: id)) {
      throw ProfilException('Cet email est déjà utilisé');
    }

    final changements = <String, Object?>{
      'username': username.trim(),
      'email': emailNormalise,
    };
    if (metier != null) {
      final m = metier.trim();
      final erreur = Validators.metier(m);
      if (erreur != null) throw ProfilException(erreur);
      changements['metier'] = m.isEmpty ? null : m;
    }
    if (bio != null) {
      final b = bio.trim();
      final erreur = Validators.bio(b);
      if (erreur != null) throw ProfilException(erreur);
      changements['bio'] = b.isEmpty ? null : b;
    }

    if (nouveauMotDePasse != null && nouveauMotDePasse.isNotEmpty) {
      if (motDePasseActuel == null ||
          !PasswordHasher.verify(motDePasseActuel, actuel.password)) {
        throw ProfilException('Mot de passe actuel incorrect');
      }
      changements['password'] = PasswordHasher.hash(nouveauMotDePasse);
    }

    await db.update('users', changements, where: 'id = ?', whereArgs: [id]);
    return (await getUserById(id))!;
  }

  Future<int> deleteUser(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}

/// Erreur « normale » de modification de profil (message pour l'utilisateur).
class ProfilException implements Exception {
  final String message;
  ProfilException(this.message);

  @override
  String toString() => message;
}
