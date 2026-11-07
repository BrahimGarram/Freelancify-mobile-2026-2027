import 'dart:convert';

class Post {
  final int? id;
  final int clientId; // id du User (Client) qui a publié
  final String titre;
  final String description;

  /// 1 à 3 clés de PostOptions.categories (stockées "dev,design")
  final List<String> categories;
  final double budget;
  final String typeBudget; // 'fixe' ou 'horaire'
  final String? dateLimite; // 'yyyy-MM-dd' (null : anciens posts)
  final String modeTravail; // 'distance', 'sur_place', 'hybride'
  final String? ville; // seulement si sur place / hybride
  final List<String> competences; // max 5, ex : ['Figma', 'Logo']
  final bool urgent;
  final String statut; // 'ouvert', 'en_cours', 'termine'
  final String dateCreation;

  // Champs "calculés" : remplis seulement quand on fait une jointure SQL.
  // Ils ne sont PAS enregistrés dans la table posts.
  final String? clientUsername;
  final int nbCandidatures;

  Post({
    this.id,
    required this.clientId,
    required this.titre,
    required this.description,
    this.categories = const ['autre'],
    required this.budget,
    this.typeBudget = 'fixe',
    this.dateLimite,
    this.modeTravail = 'distance',
    this.ville,
    this.competences = const [],
    this.urgent = false,
    this.statut = 'ouvert',
    required this.dateCreation,
    this.clientUsername,
    this.nbCandidatures = 0,
  });

  bool get estHoraire => typeBudget == 'horaire';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'titre': titre,
      'description': description,
      'categorie': categories.join(','),
      'budget': budget,
      'type_budget': typeBudget,
      'date_limite': dateLimite,
      'mode_travail': modeTravail,
      'ville': ville,
      'competences': jsonEncode(competences), // liste → texte JSON
      'urgent': urgent ? 1 : 0, // SQLite n'a pas de booléen
      'statut': statut,
      'date_creation': dateCreation,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] as int?,
      clientId: map['client_id'] as int,
      titre: map['titre'] as String,
      description: map['description'] as String,
      categories: lireCategories(map['categorie'] as String?),
      budget: (map['budget'] as num).toDouble(),
      typeBudget: (map['type_budget'] as String?) ?? 'fixe',
      dateLimite: map['date_limite'] as String?,
      modeTravail: (map['mode_travail'] as String?) ?? 'distance',
      ville: map['ville'] as String?,
      competences: _lireCompetences(map['competences'] as String?),
      urgent: (map['urgent'] as int?) == 1,
      statut: map['statut'] as String,
      dateCreation: map['date_creation'] as String,
      clientUsername: map['client_username'] as String?,
      nbCandidatures: (map['nb_candidatures'] as int?) ?? 0,
    );
  }

  /// "dev,design" → ['dev', 'design'] (un ancien post "dev" reste valide)
  static List<String> lireCategories(String? texte) {
    final liste = (texte ?? '')
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    return liste.isEmpty ? const ['autre'] : liste;
  }

  static List<String> _lireCompetences(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }
}
