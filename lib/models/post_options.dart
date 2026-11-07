/// Valeurs possibles des champs « à choix » d'un post.
/// La clé est ce qui est enregistré en base, la valeur est le texte affiché.
class PostOptions {
  PostOptions._();

  static const categories = {
    'design': 'Design',
    'dev': 'Développement',
    'video': 'Vidéo',
    'photo': 'Photo',
    'redaction': 'Rédaction',
    'marketing': 'Marketing',
    'traduction': 'Traduction',
    'autre': 'Autre',
  };

  static const typesBudget = {'fixe': 'Prix fixe', 'horaire': 'Par heure'};

  static const modesTravail = {
    'distance': 'À distance',
    'sur_place': 'Sur place',
    'hybride': 'Hybride',
  };

  static const statuts = {
    'ouvert': 'Ouvert',
    'en_cours': 'En cours',
    'termine': 'Terminé',
  };

  static const statutsCandidature = {
    'en_attente': 'En attente',
    'acceptee': 'Acceptée',
    'refusee': 'Refusée',
  };

  /// Les 24 gouvernorats de Tunisie (pour le champ Ville)
  static const villes = [
    'Ariana',
    'Béja',
    'Ben Arous',
    'Bizerte',
    'Gabès',
    'Gafsa',
    'Jendouba',
    'Kairouan',
    'Kasserine',
    'Kébili',
    'Le Kef',
    'Mahdia',
    'La Manouba',
    'Médenine',
    'Monastir',
    'Nabeul',
    'Sfax',
    'Sidi Bouzid',
    'Siliana',
    'Sousse',
    'Tataouine',
    'Tozeur',
    'Tunis',
    'Zaghouan',
  ];

  /// Le mode de travail demande-t-il une ville ?
  static bool besoinVille(String? mode) =>
      mode == 'sur_place' || mode == 'hybride';
}
