import '../database/database_helper.dart';
import '../models/user.dart';
import '../utils/validators.dart';
import 'mail/mail_service.dart';
import 'mail/modeles_email.dart';
import 'mot_de_passe_oublie_service.dart';
import 'password_hasher.dart';

class VerificationException implements Exception {
  final String message;
  const VerificationException(this.message);
  @override
  String toString() => message;
}

/// Un compte utilise déjà cette adresse
class EmailDejaUtiliseException extends VerificationException {
  const EmailDejaUtiliseException() : super('Cet email est déjà utilisé');
}

/// Un code vient d'être envoyé à cette adresse : il reste valable
class AttenteRenvoiException extends VerificationException {
  final int secondes;
  AttenteRenvoiException(this.secondes)
    : super('Attends $secondes s avant de demander un nouveau code.');
}

/// Vérification de l'adresse email à l'inscription (client ou freelancer) :
/// 1. [demanderCode] envoie un code à 6 chiffres à l'adresse saisie ;
/// 2. [verifierEtCreer] contrôle le code et crée le compte.
///
/// Aucune ligne n'est écrite dans `users` avant l'étape 2 : un compte a
/// toujours une adresse vérifiée, et un email envoyé par erreur à quelqu'un
/// d'autre ne crée rien.
///
/// Sécurité : code aléatoire stocké haché, valable 15 minutes, 5 essais
/// maximum, un seul code actif par adresse, 60 s entre deux envois.
class VerificationEmailService {
  static const validiteMinutes = MotDePasseOublieService.validiteMinutes;
  static const essaisMax = MotDePasseOublieService.essaisMax;
  static const delaiRenvoi = MotDePasseOublieService.delaiRenvoi;

  final _db = DatabaseHelper.instance;
  final MailService? mails; // null : MailService.instance
  final DateTime Function() _maintenant; // remplaçable dans les tests

  VerificationEmailService({this.mails, DateTime Function()? maintenant})
    : _maintenant = maintenant ?? DateTime.now;

  MailService get _mail => mails ?? MailService.instance;

  static String _normaliser(String email) => email.trim().toLowerCase();

  Future<bool> _emailPris(String email) async {
    final db = await _db.database;
    final l = await db.query(
      'users',
      columns: ['id'],
      where: 'lower(email) = ?',
      whereArgs: [email],
      limit: 1,
    );
    return l.isNotEmpty;
  }

  // ---------- Étape 1 : envoyer le code ----------
  /// Lève [EmailDejaUtiliseException] si un compte utilise cet email, et
  /// [AttenteRenvoiException] si un code vient d'être envoyé.
  Future<void> demanderCode({
    required String nom,
    required String email,
  }) async {
    final adresse = _normaliser(email);
    final erreur = Validators.email(adresse);
    if (erreur != null) throw VerificationException(erreur);
    if (await _emailPris(adresse)) throw const EmailDejaUtiliseException();

    final db = await _db.database;
    final now = _maintenant();
    // les inscriptions jamais terminées ne restent pas en base
    await db.delete(
      'verifications_email',
      where: 'expire_le < ?',
      whereArgs: [now.toIso8601String()],
    );

    final existant = await _ligne(adresse);
    if (existant != null) {
      final ecoule = now.difference(
        DateTime.parse(existant['date_creation'] as String),
      );
      if (ecoule < delaiRenvoi) {
        throw AttenteRenvoiException((delaiRenvoi - ecoule).inSeconds + 1);
      }
    }

    final code = MotDePasseOublieService.genererCode();
    // même clé primaire : le nouveau code remplace l'ancien
    await db.rawInsert(
      'INSERT OR REPLACE INTO verifications_email '
      '(email, code_hash, expire_le, tentatives, date_creation) '
      'VALUES (?, ?, ?, 0, ?)',
      [
        adresse,
        PasswordHasher.hash(code),
        now.add(const Duration(minutes: validiteMinutes)).toIso8601String(),
        now.toIso8601String(),
      ],
    );

    try {
      await _mail.envoyerMaintenant(
        ModelesEmail.codeVerification(
          nom: nom.trim(),
          email: adresse,
          code: code,
          minutes: validiteMinutes,
        ),
      );
    } on EnvoiException catch (e) {
      // le code n'est pas parti : on l'annule pour pouvoir réessayer tout de suite
      await db.delete(
        'verifications_email',
        where: 'email = ?',
        whereArgs: [adresse],
      );
      throw VerificationException(
        e.reseau
            ? "Pas de connexion Internet : impossible d'envoyer le code."
            : "L'email n'a pas pu être envoyé. Réessaie plus tard.",
      );
    }
  }

  // ---------- Étape 2 : vérifier le code et créer le compte ----------
  /// [user] : `password` est le mot de passe EN CLAIR, haché ici.
  /// Renvoie l'id du compte créé.
  Future<int> verifierEtCreer({
    required User user,
    required String code,
  }) async {
    final erreurCode = MotDePasseOublieService.validerCode(code);
    if (erreurCode != null) throw VerificationException(erreurCode);
    final erreurChamps =
        Validators.username(user.username) ??
        Validators.password(user.password);
    if (erreurChamps != null) throw VerificationException(erreurChamps);
    if (user.role != 'client' && user.role != 'freelancer') {
      throw const VerificationException('Rôle invalide.');
    }

    final adresse = _normaliser(user.email);
    final ligne = await _ligne(adresse);
    if (ligne == null) {
      throw const VerificationException(
        'Code incorrect ou expiré. Demande un nouveau code.',
      );
    }
    if (_maintenant().isAfter(DateTime.parse(ligne['expire_le'] as String))) {
      throw const VerificationException(
        'Ce code a expiré. Demande un nouveau code.',
      );
    }
    final tentatives = ligne['tentatives'] as int;
    if (tentatives >= essaisMax) {
      throw const VerificationException(
        "Trop d'essais. Demande un nouveau code.",
      );
    }

    final db = await _db.database;
    if (!PasswordHasher.verify(code.trim(), ligne['code_hash'] as String)) {
      await db.update(
        'verifications_email',
        {'tentatives': tentatives + 1},
        where: 'email = ?',
        whereArgs: [adresse],
      );
      final reste = essaisMax - tentatives - 1;
      throw VerificationException(
        reste > 0
            ? 'Code incorrect. Encore $reste essai${reste > 1 ? 's' : ''}.'
            : "Code incorrect. Trop d'essais : demande un nouveau code.",
      );
    }

    if (await _emailPris(adresse)) throw const EmailDejaUtiliseException();
    final id = await db.transaction((txn) async {
      final id = await txn.insert('users', {
        'username': user.username.trim(),
        'email': adresse,
        'password': PasswordHasher.hash(user.password),
        'role': user.role,
      });
      // le code ne peut servir qu'une fois
      await txn.delete(
        'verifications_email',
        where: 'email = ?',
        whereArgs: [adresse],
      );
      return id;
    });
    journalMail('Adresse vérifiée, compte #$id créé pour $adresse');
    return id;
  }

  Future<Map<String, Object?>?> _ligne(String email) async {
    final db = await _db.database;
    final l = await db.query(
      'verifications_email',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return l.isEmpty ? null : l.first;
  }
}
