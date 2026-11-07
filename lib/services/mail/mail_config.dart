import '../secrets.dart';

/// Configuration de l'envoi des emails (Gmail, SMTP).
///
/// Le mot de passe d'application Gmail n'est JAMAIS écrit dans le code : il
/// est lu dans `assets/config/secrets.json` (non versionné, voir [Secrets]).
class MailConfig {
  MailConfig._();

  /// Compte Gmail qui envoie les notifications
  static String get expediteur => Secrets.lire(
    'GMAIL_USER',
    const String.fromEnvironment('GMAIL_USER'),
    defaut: 'alpha2025group@gmail.com',
  );

  /// Mot de passe d'application Gmail (16 lettres, pas le mot de passe
  /// du compte). Les espaces affichés par Google sont ignorés.
  static String get motDePasse => Secrets.lire(
    'GMAIL_APP_PASSWORD',
    const String.fromEnvironment('GMAIL_APP_PASSWORD'),
  ).replaceAll(' ', '');

  static const nomExpediteur = 'freelance';
}
