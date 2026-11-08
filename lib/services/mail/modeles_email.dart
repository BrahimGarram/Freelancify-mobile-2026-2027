/// Un email prêt à être envoyé (version texte + version HTML)
class EmailSortant {
  final int? id;
  final String destinataire;
  final String sujet;
  final String texte;
  final String html;
  final int tentatives;

  const EmailSortant({
    this.id,
    required this.destinataire,
    required this.sujet,
    required this.texte,
    required this.html,
    this.tentatives = 0,
  });

  Map<String, dynamic> toMap() => {
    'destinataire': destinataire,
    'sujet': sujet,
    'texte': texte,
    'html': html,
    'tentatives': tentatives,
    'date_creation': DateTime.now().toIso8601String(),
  };

  factory EmailSortant.fromMap(Map<String, dynamic> m) => EmailSortant(
    id: m['id'] as int,
    destinataire: m['destinataire'] as String,
    sujet: m['sujet'] as String,
    texte: m['texte'] as String,
    html: m['html'] as String,
    tentatives: m['tentatives'] as int,
  );
}

/// Les informations d'une nouvelle candidature, pour le mail du client
class InfosCandidature {
  final String clientNom;
  final String clientEmail;
  final String freelancerNom;
  final String? freelancerMetier;
  final int nbRealisations;
  final String postTitre;
  final double postBudget;
  final bool horaire;
  final String message;

  const InfosCandidature({
    required this.clientNom,
    required this.clientEmail,
    required this.freelancerNom,
    this.freelancerMetier,
    this.nbRealisations = 0,
    required this.postTitre,
    required this.postBudget,
    this.horaire = false,
    required this.message,
  });
}

/// Modèles des emails envoyés par l'application
class ModelesEmail {
  ModelesEmail._();

  /// « Nouvelle candidature » : envoyé au client quand un freelancer postule
  static EmailSortant nouvelleCandidature(InfosCandidature i) {
    final titre = _uneLigne(i.postTitre);
    final budget = _budget(i.postBudget, horaire: i.horaire);
    final profil = [
      if (i.freelancerMetier != null) i.freelancerMetier!,
      if (i.nbRealisations > 0)
        '${i.nbRealisations} réalisation${i.nbRealisations > 1 ? 's' : ''} '
            'dans son portfolio',
    ].join(' · ');

    final texte =
        '''
Bonjour ${i.clientNom},

@${i.freelancerNom} vient de postuler à ta mission « $titre » ($budget).
${profil.isEmpty ? '' : '$profil\n'}
Son message :
« ${i.message.trim()} »

Pour lui répondre, accepter ou refuser sa candidature, ouvre l'application
freelance, onglet « Candidatures ».

—
L'équipe freelance
Cet email est envoyé automatiquement, merci de ne pas y répondre.
''';

    final e = _html;
    final html =
        '''
<!DOCTYPE html>
<html lang="fr">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f4f5;font-family:Arial,Helvetica,sans-serif;color:#18181b;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f5;padding:24px 12px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:16px;overflow:hidden;">
        <tr><td style="background:#000000;padding:20px 28px;">
          <span style="font-size:22px;font-weight:800;color:#ffffff;letter-spacing:-0.5px;">freelance</span>
          <span style="display:inline-block;width:8px;height:8px;border-radius:4px;background:#EE1D52;margin-left:4px;"></span>
        </td></tr>
        <tr><td style="padding:28px;">
          <p style="margin:0 0 6px;font-size:13px;font-weight:700;color:#EE1D52;text-transform:uppercase;letter-spacing:1px;">Nouvelle candidature</p>
          <h1 style="margin:0 0 18px;font-size:22px;line-height:1.3;">@${e(i.freelancerNom)} a postulé à ta mission</h1>
          <p style="margin:0 0 18px;font-size:15px;line-height:1.5;">Bonjour ${e(i.clientNom)},</p>
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#fafafa;border:1px solid #e4e4e7;border-radius:12px;">
            <tr><td style="padding:16px 18px;">
              <p style="margin:0 0 4px;font-size:12px;color:#71717a;">Mission</p>
              <p style="margin:0 0 4px;font-size:16px;font-weight:700;">${e(titre)}</p>
              <p style="margin:0;font-size:14px;font-weight:700;color:#EE1D52;">${e(budget)}</p>
            </td></tr>
          </table>
          <p style="margin:22px 0 4px;font-size:12px;color:#71717a;">Freelancer</p>
          <p style="margin:0;font-size:15px;font-weight:700;">@${e(i.freelancerNom)}</p>
          ${profil.isEmpty ? '' : '<p style="margin:2px 0 0;font-size:13px;color:#52525b;">${e(profil)}</p>'}
          <p style="margin:22px 0 6px;font-size:12px;color:#71717a;">Son message</p>
          <div style="border-left:3px solid #25F4EE;padding:4px 0 4px 14px;font-size:15px;line-height:1.55;color:#27272a;">${e(i.message.trim()).replaceAll('\n', '<br>')}</div>
          <p style="margin:26px 0 0;font-size:14px;line-height:1.5;color:#3f3f46;">Pour lui répondre, accepter ou refuser sa candidature, ouvre l'application <b>freelance</b>, onglet <b>« Candidatures »</b>.</p>
        </td></tr>
        <tr><td style="padding:16px 28px;border-top:1px solid #f4f4f5;font-size:12px;color:#a1a1aa;">
          Cet email est envoyé automatiquement, merci de ne pas y répondre.
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';

    return EmailSortant(
      destinataire: i.clientEmail,
      sujet: 'Nouvelle candidature pour « $titre »',
      texte: texte,
      html: html,
    );
  }

  /// Email de vérification de l'adresse à l'inscription
  static EmailSortant codeVerification({
    required String nom,
    required String email,
    required String code,
    required int minutes,
  }) {
    final texte =
        '''
Bonjour $nom,

Pour créer ton compte sur l'application freelance, confirme ton adresse email.

Ton code : $code

Il est valable $minutes minutes. Saisis-le dans l'application pour terminer
ton inscription.

Si tu n'es pas à l'origine de cette demande, ignore cet email : aucun compte
ne sera créé.

—
L'équipe freelance
Cet email est envoyé automatiquement, merci de ne pas y répondre.
''';
    return EmailSortant(
      destinataire: email,
      sujet: 'Vérifie ton email freelance : $code',
      texte: texte,
      html: _htmlCode(
        surtitre: 'Vérification de ton email',
        titre: 'Ton code pour créer ton compte',
        nom: nom,
        consigne:
            "saisis ce code dans l'application pour terminer ton inscription :",
        code: code,
        minutes: minutes,
        remarque: "Si tu n'es pas à l'origine de cette demande, ignore cet email : aucun compte ne sera créé.",
      ),
    );
  }

  static String _htmlCode({
    required String surtitre,
    required String titre,
    required String nom,
    required String consigne,
    required String code,
    required int minutes,
    required String remarque,
  }) {
    final e = _html;
    return '''
<!DOCTYPE html>
<html lang="fr">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f4f5;font-family:Arial,Helvetica,sans-serif;color:#18181b;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f5;padding:24px 12px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:16px;overflow:hidden;">
        <tr><td style="background:#000000;padding:20px 28px;">
          <span style="font-size:22px;font-weight:800;color:#ffffff;letter-spacing:-0.5px;">freelance</span>
          <span style="display:inline-block;width:8px;height:8px;border-radius:4px;background:#EE1D52;margin-left:4px;"></span>
        </td></tr>
        <tr><td style="padding:28px;">
          <p style="margin:0 0 6px;font-size:13px;font-weight:700;color:#EE1D52;text-transform:uppercase;letter-spacing:1px;">${e(surtitre)}</p>
          <h1 style="margin:0 0 18px;font-size:22px;line-height:1.3;">${e(titre)}</h1>
          <p style="margin:0 0 18px;font-size:15px;line-height:1.5;">Bonjour ${e(nom)},<br>${e(consigne)}</p>
          <p style="margin:0 0 18px;text-align:center;">
            <span style="display:inline-block;padding:14px 22px;background:#fafafa;border:1px solid #e4e4e7;border-radius:12px;font-size:32px;font-weight:800;letter-spacing:8px;font-family:'Courier New',monospace;">${e(code)}</span>
          </p>
          <p style="margin:0 0 6px;font-size:14px;color:#3f3f46;">Il est valable <b>$minutes minutes</b>.</p>
          <p style="margin:18px 0 0;font-size:13px;line-height:1.5;color:#71717a;">${e(remarque)}</p>
        </td></tr>
        <tr><td style="padding:16px 28px;border-top:1px solid #f4f4f5;font-size:12px;color:#a1a1aa;">
          Cet email est envoyé automatiquement, merci de ne pas y répondre.
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';
  }

  /// Code de réinitialisation du mot de passe
  static EmailSortant codeReinitialisation({
    required String nom,
    required String email,
    required String code,
    required int minutes,
  }) {
    final texte =
        '''
Bonjour $nom,

Tu as demandé à réinitialiser ton mot de passe sur l'application freelance.

Ton code : $code

Il est valable $minutes minutes. Saisis-le dans l'application pour choisir
un nouveau mot de passe.

Si tu n'es pas à l'origine de cette demande, ignore cet email : ton mot de
passe ne change pas.

—
L'équipe freelance
Cet email est envoyé automatiquement, merci de ne pas y répondre.
''';
    final html = _htmlCode(
      surtitre: 'Mot de passe oublié',
      titre: 'Ton code de réinitialisation',
      nom: nom,
      consigne: "saisis ce code dans l'application pour choisir un nouveau mot de passe :",
      code: code,
      minutes: minutes,
      remarque: "Si tu n'es pas à l'origine de cette demande, ignore cet email : ton mot de passe ne change pas.",
    );
    return EmailSortant(
      destinataire: email,
      sujet: 'Ton code freelance : $code',
      texte: texte,
      html: html,
    );
  }

  /// 150 → "150 DT\" ; 99.5 → "99.50 DT" ; horaire → "15 DT/h"
  static String _budget(double b, {bool horaire = false}) {
    final m = b == b.roundToDouble()
        ? b.toInt().toString()
        : b.toStringAsFixed(2);
    return horaire ? '$m DT/h' : '$m DT';
  }

  /// Échappe le texte saisi par les utilisateurs avant de le mettre en HTML
  static String _html(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  /// Pas de retour à la ligne dans un sujet (injection d'en-têtes)
  static String _uneLigne(String s) =>
      s.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
}
