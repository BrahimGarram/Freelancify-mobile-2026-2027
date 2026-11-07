import 'dart:math';

import '../database/database_helper.dart';
import '../utils/validators.dart';
import 'mail/mail_service.dart';
import 'mail/modeles_email.dart';
import 'password_hasher.dart';

class ReinitialisationException implements Exception {
  final String message;
  const ReinitialisationException(this.message);
  @override
  String toString() => message;
}

/// Aucun compte n'utilise l'adresse saisie
class EmailInconnuException extends ReinitialisationException {
  const EmailInconnuException()
    : super("Cette adresse email n'existe pas : aucun compte ne l'utilise.");
}

/// « Mot de passe oublié » :
/// 1. l'utilisateur donne son email → un code à 6 chiffres lui est envoyé
///    (depuis l'adresse Gmail configurée) ;
/// 2. il saisit le code et son nouveau mot de passe.
///
/// Sécurité : code aléatoire (Random.secure), stocké haché, valable
/// 15 minutes, 5 essais maximum, un seul code actif, 60 s entre deux envois.
class MotDePasseOublieService {
  static const longueurCode = 6;
  static const validiteMinutes = 15;
  static const essaisMax = 5;
  static const delaiRenvoi = Duration(seconds: 60);

  final _db = DatabaseHelper.instance;
  final MailService? mails; // null : MailService.instance
  final DateTime Function() _maintenant; // remplaçable dans les tests
  static final _random = Random.secure();

  MotDePasseOublieService({this.mails, DateTime Function()? maintenant})
    : _maintenant = maintenant ?? DateTime.now;

  MailService get _mail => mails ?? MailService.instance;

  // ---------- Étape 1 : envoyer le code ----------
  /// Lève [EmailInconnuException] si aucun compte n'utilise cet email.
  Future<void> demanderCode(String emailSaisi) async {
    final email = emailSaisi.trim().toLowerCase();
    final erreur = Validators.email(email);
    if (erreur != null) throw ReinitialisationException(erreur);

    final db = await _db.database;
    final users = await db.query(
      'users',
      columns: ['id', 'username', 'email'],
      where: 'lower(email) = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (users.isEmpty) {
      journalMail(
        'Mot de passe oublié : aucun compte pour $email (rien envoyé)',
      );
      throw const EmailInconnuException();
    }
    final userId = users.first['id'] as int;
    final nom = users.first['username'] as String;

    // anti-abus : un seul envoi par minute
    final dernier = await _dernierCode(userId);
    if (dernier != null) {
      final ecoule = _maintenant().difference(
        DateTime.parse(dernier['date_creation'] as String),
      );
      if (ecoule < delaiRenvoi) {
        final reste = (delaiRenvoi - ecoule).inSeconds + 1;
        throw ReinitialisationException(
          'Attends $reste s avant de demander un nouveau code.',
        );
      }
    }

    final code = genererCode();
    final now = _maintenant();
    // un seul code actif : les anciens ne marchent plus
    await db.update(
      'codes_reinitialisation',
      {'utilise': 1},
      where: 'user_id = ? AND utilise = 0',
      whereArgs: [userId],
    );
    final id = await db.insert('codes_reinitialisation', {
      'user_id': userId,
      'code_hash': PasswordHasher.hash(code),
      'expire_le': now
          .add(const Duration(minutes: validiteMinutes))
          .toIso8601String(),
      'date_creation': now.toIso8601String(),
    });

    try {
      await _mail.envoyerMaintenant(
        ModelesEmail.codeReinitialisation(
          nom: nom,
          email: users.first['email'] as String,
          code: code,
          minutes: validiteMinutes,
        ),
      );
    } on EnvoiException catch (e) {
      // le code n'est pas parti : on l'annule pour pouvoir réessayer tout de suite
      await db.delete(
        'codes_reinitialisation',
        where: 'id = ?',
        whereArgs: [id],
      );
      throw ReinitialisationException(
        e.reseau
            ? "Pas de connexion Internet : impossible d'envoyer le code."
            : "L'email n'a pas pu être envoyé. Réessaie plus tard.",
      );
    }
  }

  // ---------- Étape 2 : vérifier le code et changer le mot de passe ----------
  Future<void> reinitialiser({
    required String email,
    required String code,
    required String nouveauMotDePasse,
  }) async {
    final erreurMdp = Validators.password(nouveauMotDePasse);
    if (erreurMdp != null) throw ReinitialisationException(erreurMdp);
    final erreurCode = validerCode(code);
    if (erreurCode != null) throw ReinitialisationException(erreurCode);

    const invalide = ReinitialisationException(
      'Code incorrect ou expiré. Demande un nouveau code.',
    );
    final db = await _db.database;
    final users = await db.query(
      'users',
      columns: ['id'],
      where: 'lower(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (users.isEmpty) throw invalide;
    final userId = users.first['id'] as int;

    final ligne = await _dernierCode(userId, actifSeulement: true);
    if (ligne == null) throw invalide;
    final id = ligne['id'] as int;
    final tentatives = ligne['tentatives'] as int;

    if (_maintenant().isAfter(DateTime.parse(ligne['expire_le'] as String))) {
      throw const ReinitialisationException(
        'Ce code a expiré. Demande un nouveau code.',
      );
    }
    if (tentatives >= essaisMax) {
      throw const ReinitialisationException(
        'Trop d\'essais. Demande un nouveau code.',
      );
    }

    if (!PasswordHasher.verify(code.trim(), ligne['code_hash'] as String)) {
      await db.update(
        'codes_reinitialisation',
        {'tentatives': tentatives + 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      final reste = essaisMax - tentatives - 1;
      throw ReinitialisationException(
        reste > 0
            ? 'Code incorrect. Encore $reste essai${reste > 1 ? 's' : ''}.'
            : 'Code incorrect. Trop d\'essais : demande un nouveau code.',
      );
    }

    await db.transaction((txn) async {
      await txn.update(
        'users',
        {'password': PasswordHasher.hash(nouveauMotDePasse)},
        where: 'id = ?',
        whereArgs: [userId],
      );
      // le code ne peut servir qu'une fois
      await txn.update(
        'codes_reinitialisation',
        {'utilise': 1},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    });
    journalMail('Mot de passe réinitialisé pour l\'utilisateur #$userId');
  }

  Future<Map<String, Object?>?> _dernierCode(
    int userId, {
    bool actifSeulement = false,
  }) async {
    final db = await _db.database;
    final lignes = await db.query(
      'codes_reinitialisation',
      where: actifSeulement ? 'user_id = ? AND utilise = 0' : 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
      limit: 1,
    );
    return lignes.isEmpty ? null : lignes.first;
  }

  /// Code à 6 chiffres, ex : "048213"
  static String genererCode() =>
      List.generate(longueurCode, (_) => _random.nextInt(10)).join();

  static String? validerCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Entre le code reçu par email';
    if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'Le code contient 6 chiffres';
    return null;
  }
}
