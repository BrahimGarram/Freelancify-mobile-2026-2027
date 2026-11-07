import '../../models/user.dart';
import 'ai_config.dart';
import 'gemini_client.dart';
import 'guide_app.dart';

/// Chatbot d'aide : répond aux questions sur l'application, en tenant
/// compte du rôle de l'utilisateur (client, freelancer ou visiteur).
class AssistantService {
  static const questionMax = 500;

  /// Nombre de messages renvoyés à l'IA (mémoire de la conversation)
  static const historiqueMax = 12;

  final GeminiClient _ia;
  final User? user; // null : visiteur (pas encore connecté)

  AssistantService({this.user, GeminiClient? client})
    : _ia =
          client ??
          GeminiClient(
            apiKey: AiConfig.cleChatbot,
            modele: AiConfig.modeleChatbot,
          );

  bool get estConfigure => _ia.estConfigure;

  /// Questions proposées au démarrage, selon le rôle
  List<String> get suggestions => switch (user?.role) {
    'client' => const [
      'Comment publier un post ?',
      "L'IA peut remplir mon post ?",
      'Comment choisir un freelancer ?',
      'Que se passe-t-il si j\'accepte ?',
    ],
    'freelancer' => const [
      'Comment trouver une mission ?',
      'Comment ajouter une réalisation ?',
      'Comment rendre mon profil attirant ?',
      'Où voir mes candidatures ?',
    ],
    _ => const [
      "C'est quoi cette application ?",
      'Client ou freelancer : que choisir ?',
      'Comment créer un compte ?',
    ],
  };

  /// [historique] : toute la conversation, la nouvelle question en dernier.
  Future<String> repondre(List<GeminiMessage> historique) async {
    final recents = historique.length > historiqueMax
        ? historique.sublist(historique.length - historiqueMax)
        : historique;
    // l'API attend une conversation qui commence par l'utilisateur
    final debut = recents.indexWhere((m) => m.deLUtilisateur);
    final reponse = await _ia.generer(
      instructions: instructions,
      messages: debut <= 0 ? recents : recents.sublist(debut),
      reflexion: 'LOW',
      maxTokens: 1024,
    );
    return nettoyer(reponse);
  }

  String get instructions {
    final role = switch (user?.role) {
      'client' => 'CLIENT (il publie des missions et recrute)',
      'freelancer' => 'FREELANCER (il postule et montre son portfolio)',
      _ => 'VISITEUR non connecté (écran de connexion)',
    };
    final nom = user == null ? '' : ' Il s\'appelle ${user!.username}.';
    return '''
Tu es l'assistant intégré de l'application mobile « freelance ». Tu aides
l'utilisateur à comprendre et utiliser l'application.

<utilisateur>
Rôle : $role.$nom
</utilisateur>

<style>
- Réponses COURTES : 1 à 3 phrases. Pour une démarche, au plus 4 étapes
  numérotées, une ligne chacune, avec le nom exact des boutons et onglets.
- Texte simple, sans Markdown (pas de **, pas de #, pas de tableaux).
- Tutoie l'utilisateur. Réponds dans sa langue (français par défaut ; s'il
  écrit en arabe, en derja ou en anglais, réponds dans cette langue).
- Va droit au but : pas de « Bonne question », pas de formule de politesse
  inutile, pas de résumé de la question.
</style>

<comment_repondre>
- Comprends le vrai besoin derrière la question et réponds pour SON rôle :
  ne donne pas à un client les étapes d'un freelancer (et inversement), sauf
  s'il le demande.
- Si la question est trop vague pour répondre correctement, pose UNE seule
  question courte pour préciser.
- Si l'utilisateur décrit un problème (ex. « je ne vois pas mon post »),
  donne la cause la plus probable d'après le guide, puis la solution.
- Tu peux donner un conseil utile et court (ex. bien rédiger une
  candidature, un profil, une description de mission).
</comment_repondre>

<regles>
- Utilise UNIQUEMENT les informations du guide ci-dessous. N'invente jamais
  un bouton, un écran, une limite ou une fonctionnalité.
- Si une fonctionnalité n'existe pas, dis-le clairement en une phrase et
  propose l'alternative qui existe, s'il y en a une.
- Tu ne peux rien faire à la place de l'utilisateur (publier, accepter,
  modifier…) : explique-lui comment faire.
- Ne demande jamais de mot de passe ni d'information personnelle.
- Hors sujet (politique, devoirs, code, etc.) : réponds en une phrase que tu
  aides seulement pour l'application, et propose une question utile.
</regles>

<guide>
$guideApp
</guide>
''';
  }

  /// Retire le Markdown que le modèle pourrait quand même écrire
  static String nettoyer(String texte) {
    return texte
        .replaceAll(RegExp(r'\*\*|__|`'), '')
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[*-]\s+', multiLine: true), '• ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
