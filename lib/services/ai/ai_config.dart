import '../secrets.dart';

/// Configuration de l'IA (Gemini).
///
/// Les clés ne sont JAMAIS écrites dans le code : elles sont lues dans
/// `assets/config/secrets.json` (non versionné, voir [Secrets]).
///
/// Clés séparées : chatbot, aide à la rédaction des posts, rapport des
/// tests (quotas et suivi indépendants).
class AiConfig {
  AiConfig._();

  static String get cleChatbot => Secrets.lire(
    'GEMINI_CHAT_KEY',
    const String.fromEnvironment('GEMINI_CHAT_KEY'),
  );

  static String get clePost => Secrets.lire(
    'GEMINI_POST_KEY',
    const String.fromEnvironment('GEMINI_POST_KEY'),
  );

  /// Clé du rapport de l'IA après un test. Si elle n'est pas encore
  /// renseignée, on utilise celle des posts (l'app reste fonctionnelle).
  static String get cleRapport {
    final cle = Secrets.lire(
      'GEMINI_RAPPORT_KEY',
      const String.fromEnvironment('GEMINI_RAPPORT_KEY'),
    );
    return cle.isNotEmpty ? cle : clePost;
  }

  static bool get cleRapportDediee => Secrets.lire(
    'GEMINI_RAPPORT_KEY',
    const String.fromEnvironment('GEMINI_RAPPORT_KEY'),
  ).isNotEmpty;

  /// Modèles gratuits (offre gratuite de Google AI Studio)
  static String get modeleChatbot => Secrets.lire(
    'GEMINI_CHAT_MODEL',
    const String.fromEnvironment('GEMINI_CHAT_MODEL'),
    defaut: 'gemini-3.5-flash-lite', // rapide : réponses courtes
  );

  static String get modelePost => Secrets.lire(
    'GEMINI_POST_MODEL',
    const String.fromEnvironment('GEMINI_POST_MODEL'),
    defaut: 'gemini-3.6-flash', // meilleure compréhension du besoin
  );

  static String get modeleRapport => Secrets.lire(
    'GEMINI_RAPPORT_MODEL',
    const String.fromEnvironment('GEMINI_RAPPORT_MODEL'),
    defaut: 'gemini-3.6-flash', // analyse fine des erreurs
  );
}
