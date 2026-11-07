import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../../database/database_helper.dart';
import '../../utils/validators.dart';
import 'mail_config.dart';
import 'modeles_email.dart';

/// Messages de debug, visibles dans le terminal (flutter run / logcat)
void journalMail(String message) => debugPrint('[MAIL] $message');

/// Envoie réellement un email (remplaçable dans les tests)
abstract class EnvoyeurEmail {
  bool get estConfigure;
  Future<void> envoyer(EmailSortant email);
}

/// Erreur d'envoi. [reseau] : vrai si la connexion manque (on arrête la
/// file et on réessaiera plus tard).
class EnvoiException implements Exception {
  final String message;
  final bool reseau; // pas de connexion : inutile d'essayer les suivants
  const EnvoiException(this.message, {this.reseau = false});
  @override
  String toString() => message;
}

/// Envoi par le serveur SMTP de Gmail (mot de passe d'application)
class EnvoyeurGmail implements EnvoyeurEmail {
  final String compte;
  final String motDePasse;

  EnvoyeurGmail({String? compte, String? motDePasse})
    : compte = compte ?? MailConfig.expediteur,
      motDePasse = motDePasse ?? MailConfig.motDePasse;

  @override
  bool get estConfigure => compte.isNotEmpty && motDePasse.isNotEmpty;

  @override
  Future<void> envoyer(EmailSortant email) async {
    final message = Message()
      ..from = Address(compte, MailConfig.nomExpediteur)
      ..recipients.add(email.destinataire)
      ..subject = email.sujet
      ..text = email.texte
      ..html = email.html;
    try {
      await send(
        message,
        gmail(compte, motDePasse),
        timeout: const Duration(seconds: 25),
      );
    } on SmtpClientAuthenticationException catch (e) {
      journalMail('Gmail : authentification refusée (${e.message})');
      throw const EnvoiException(
        'Gmail refuse la connexion : vérifie le mot de passe d\'application.',
      );
    } on SmtpMessageValidationException catch (e) {
      journalMail('Gmail : message refusé ${e.problems.map((p) => p.msg)}');
      throw EnvoiException('Email invalide : ${e.message}');
    } on MailerException catch (e) {
      journalMail('Gmail : erreur SMTP ${e.runtimeType} (${e.message})');
      throw EnvoiException('Erreur SMTP : ${e.message}');
    } on SocketException catch (e) {
      journalMail('Réseau indisponible : ${e.message}');
      throw const EnvoiException('Pas de connexion Internet', reseau: true);
    } on TimeoutException {
      journalMail('Délai dépassé : Gmail ne répond pas');
      throw const EnvoiException('Délai dépassé', reseau: true);
    }
  }
}

/// Notifications par email, avec une « boîte d'envoi » en base :
/// l'email est d'abord enregistré, puis envoyé. S'il n'a pas pu partir
/// (pas de réseau…), il est renvoyé au prochain démarrage ou au prochain
/// email. Une candidature n'échoue JAMAIS à cause d'un email.
class MailService {
  static MailService instance = MailService();

  /// Au-delà, on abandonne l'email (mot de passe faux, adresse rejetée…)
  static const tentativesMax = 5;

  final EnvoyeurEmail _envoyeur;
  final _db = DatabaseHelper.instance;
  Future<void>? _envoiEnCours;

  MailService({EnvoyeurEmail? envoyeur})
    : _envoyeur = envoyeur ?? EnvoyeurGmail();

  bool get estConfigure => _envoyeur.estConfigure;

  // ---------- FONCTIONNALITÉ : prévenir le client d'une candidature ----------
  Future<void> notifierNouvelleCandidature(int candidatureId) async {
    journalMail(
      'Nouvelle candidature #$candidatureId : préparation de l\'email',
    );
    if (!estConfigure) {
      journalMail(
        'ANNULÉ : emails désactivés (GMAIL_APP_PASSWORD manquant dans '
        'assets/config/secrets.json)',
      );
      return;
    }
    final infos = await _lireInfos(candidatureId);
    if (infos == null) {
      journalMail('ANNULÉ : candidature #$candidatureId introuvable');
      return;
    }
    if (Validators.email(infos.clientEmail) != null) {
      journalMail(
        'ANNULÉ : adresse du client @${infos.clientNom} invalide '
        '(« ${infos.clientEmail} »)',
      );
      return;
    }
    journalMail(
      'Destinataire : ${infos.clientEmail} (client @${infos.clientNom}), '
      'freelancer @${infos.freelancerNom}, mission « ${infos.postTitre} »',
    );
    await mettreEnAttente(ModelesEmail.nouvelleCandidature(infos));
    await envoyerEnAttente();
  }

  /// Envoi immédiat, sans boîte d'envoi (ex : code de réinitialisation,
  /// qui expire vite). L'appelant reçoit l'erreur s'il y en a une.
  Future<void> envoyerMaintenant(EmailSortant email) async {
    if (!estConfigure) {
      journalMail('ANNULÉ : emails désactivés, « ${email.sujet} » non envoyé');
      throw const EnvoiException("L'envoi d'emails n'est pas configuré.");
    }
    final debut = DateTime.now();
    journalMail('Envoi immédiat → ${email.destinataire} : « ${email.sujet} »');
    try {
      await _envoyeur.envoyer(email);
    } on EnvoiException catch (e) {
      journalMail('❌ NON ENVOYÉ à ${email.destinataire} : $e');
      rethrow;
    }
    final ms = DateTime.now().difference(debut).inMilliseconds;
    journalMail('✅ ENVOYÉ à ${email.destinataire} ($ms ms)');
  }

  Future<void> mettreEnAttente(EmailSortant email) async {
    final db = await _db.database;
    final id = await db.insert('emails_sortants', email.toMap());
    journalMail('Email #$id mis dans la boîte d\'envoi');
  }

  /// Résumé de la configuration (au démarrage)
  void journaliserConfiguration() {
    final mdp = MailConfig.motDePasse;
    journalMail(
      estConfigure
          ? 'Emails ACTIVÉS : expéditeur ${MailConfig.expediteur}, '
                'mot de passe ${mdp.length} caractères'
          : 'Emails DÉSACTIVÉS : GMAIL_APP_PASSWORD manquant dans '
                'assets/config/secrets.json',
    );
  }

  /// Envoie les emails en attente. Un seul envoi à la fois : si un envoi
  /// est déjà en cours, on attend sa fin puis on vérifie la file.
  Future<void> envoyerEnAttente() async {
    if (!estConfigure) return;
    while (_envoiEnCours != null) {
      await _envoiEnCours;
    }
    final envoi = _vider();
    _envoiEnCours = envoi;
    try {
      await envoi;
    } finally {
      _envoiEnCours = null;
    }
  }

  Future<void> _vider() async {
    final db = await _db.database;
    final lignes = await db.query(
      'emails_sortants',
      where: 'tentatives < ?',
      whereArgs: [tentativesMax],
      orderBy: 'id',
    );
    if (lignes.isNotEmpty) {
      journalMail('${lignes.length} email(s) à envoyer');
    }
    for (final ligne in lignes) {
      final email = EmailSortant.fromMap(ligne);
      final debut = DateTime.now();
      journalMail(
        'Envoi #${email.id} → ${email.destinataire} '
        '(essai ${email.tentatives + 1}/$tentativesMax) : « ${email.sujet} »',
      );
      try {
        await _envoyeur.envoyer(email);
        await db.delete(
          'emails_sortants',
          where: 'id = ?',
          whereArgs: [email.id],
        );
        final ms = DateTime.now().difference(debut).inMilliseconds;
        journalMail('✅ ENVOYÉ #${email.id} à ${email.destinataire} ($ms ms)');
      } on EnvoiException catch (e) {
        await db.update(
          'emails_sortants',
          {'tentatives': email.tentatives + 1, 'derniere_erreur': e.message},
          where: 'id = ?',
          whereArgs: [email.id],
        );
        final restant = tentativesMax - email.tentatives - 1;
        journalMail(
          '❌ NON ENVOYÉ #${email.id} à ${email.destinataire} : $e — '
          '${restant > 0 ? 'nouvel essai plus tard ($restant restant(s))' : 'abandonné'}',
        );
        if (e.reseau) return; // hors ligne : on réessaiera plus tard
      } catch (e) {
        journalMail('❌ ERREUR INATTENDUE #${email.id} : $e');
        rethrow;
      }
    }
  }

  /// Nombre d'emails pas encore partis (pour les tests / le débogage)
  Future<int> nbEnAttente() async {
    final db = await _db.database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM emails_sortants WHERE tentatives < ?',
      [tentativesMax],
    );
    return r.first['n'] as int;
  }

  Future<InfosCandidature?> _lireInfos(int candidatureId) async {
    final db = await _db.database;
    final lignes = await db.rawQuery(
      '''
      SELECT c.message, p.titre, p.budget, p.type_budget,
             cl.username AS client_nom, cl.email AS client_email,
             f.username AS freelancer_nom, f.metier AS freelancer_metier,
             (SELECT COUNT(*) FROM realisations r
              WHERE r.freelancer_id = f.id) AS nb_realisations
      FROM candidatures c
      JOIN posts p ON p.id = c.post_id
      JOIN users cl ON cl.id = p.client_id
      JOIN users f ON f.id = c.freelancer_id
      WHERE c.id = ?
    ''',
      [candidatureId],
    );
    if (lignes.isEmpty) return null;
    final l = lignes.first;
    return InfosCandidature(
      clientNom: l['client_nom'] as String,
      clientEmail: l['client_email'] as String,
      freelancerNom: l['freelancer_nom'] as String,
      freelancerMetier: l['freelancer_metier'] as String?,
      nbRealisations: (l['nb_realisations'] as int?) ?? 0,
      postTitre: l['titre'] as String,
      postBudget: (l['budget'] as num).toDouble(),
      horaire: l['type_budget'] == 'horaire',
      message: l['message'] as String,
    );
  }
}
