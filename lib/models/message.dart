/// Un message d'une discussion (une discussion = une candidature).
class Message {
  final int? id;
  final int candidatureId;
  final int expediteurId;
  final String contenu;
  final String dateEnvoi;
  final bool lu;

  Message({
    this.id,
    required this.candidatureId,
    required this.expediteurId,
    required this.contenu,
    required this.dateEnvoi,
    this.lu = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'candidature_id': candidatureId,
    'expediteur_id': expediteurId,
    'contenu': contenu,
    'date_envoi': dateEnvoi,
    'lu': lu ? 1 : 0,
  };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
    id: map['id'] as int?,
    candidatureId: map['candidature_id'] as int,
    expediteurId: map['expediteur_id'] as int,
    contenu: map['contenu'] as String,
    dateEnvoi: map['date_envoi'] as String,
    lu: (map['lu'] as int?) == 1,
  );
}

/// Résumé d'une discussion pour la liste « Messages ».
class Conversation {
  final int candidatureId;
  final int postId;
  final String postTitre;
  final String statutCandidature; // 'en_attente', 'acceptee', 'refusee'
  final int freelancerId;
  final String freelancerUsername;
  final int clientId;
  final String clientUsername;
  final String? dernierMessage;
  final String? dateDernierMessage;
  final int? dernierExpediteurId;
  final int nbNonLus; // messages de l'autre personne pas encore lus

  Conversation({
    required this.candidatureId,
    required this.postId,
    required this.postTitre,
    required this.statutCandidature,
    required this.freelancerId,
    required this.freelancerUsername,
    required this.clientId,
    required this.clientUsername,
    this.dernierMessage,
    this.dateDernierMessage,
    this.dernierExpediteurId,
    this.nbNonLus = 0,
  });

  /// La discussion est fermée si la candidature a été refusée
  bool get fermee => statutCandidature == 'refusee';

  /// Le nom de l'autre personne, vu par [userId]
  String interlocuteur(int userId) =>
      userId == clientId ? freelancerUsername : clientUsername;

  /// L'autre personne est-elle le client ? (pour la couleur de l'avatar)
  bool interlocuteurEstClient(int userId) => userId != clientId;

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
    candidatureId: map['candidature_id'] as int,
    postId: map['post_id'] as int,
    postTitre: map['post_titre'] as String,
    statutCandidature: map['statut'] as String,
    freelancerId: map['freelancer_id'] as int,
    freelancerUsername: map['freelancer_username'] as String,
    clientId: map['client_id'] as int,
    clientUsername: map['client_username'] as String,
    dernierMessage: map['dernier_contenu'] as String?,
    dateDernierMessage: map['dernier_date'] as String?,
    dernierExpediteurId: map['dernier_expediteur'] as int?,
    nbNonLus: (map['nb_non_lus'] as int?) ?? 0,
  );
}
