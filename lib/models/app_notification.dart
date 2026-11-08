/// Une notification affichée dans l'application (cloche 🔔)
class AppNotification {
  static const typeNouveauPost = 'nouveau_post';
  static const typeProjet = 'projet';

  final int? id;
  final int userId; // destinataire
  final String type;
  final String titre;
  final String contenu;
  final int? postId;
  final int? acteurId; // qui l'a provoquée (ex : le client)
  final bool lu;
  final String dateCreation;

  // jointure : nom de l'acteur
  final String? acteurNom;

  const AppNotification({
    this.id,
    required this.userId,
    required this.type,
    required this.titre,
    required this.contenu,
    this.postId,
    this.acteurId,
    this.lu = false,
    required this.dateCreation,
    this.acteurNom,
  });

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'type': type,
    'titre': titre,
    'contenu': contenu,
    'post_id': postId,
    'acteur_id': acteurId,
    'lu': lu ? 1 : 0,
    'date_creation': dateCreation,
  };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    id: m['id'] as int,
    userId: m['user_id'] as int,
    type: m['type'] as String,
    titre: m['titre'] as String,
    contenu: m['contenu'] as String,
    postId: m['post_id'] as int?,
    acteurId: m['acteur_id'] as int?,
    lu: (m['lu'] as int) == 1,
    dateCreation: m['date_creation'] as String,
    acteurNom: m['acteur_nom'] as String?,
  );
}
