class Candidature {
  final int? id;
  final int postId; // le post auquel le freelancer postule
  final int freelancerId; // le User (Freelancer) qui postule
  final String message; // son message au client
  final String statut; // 'en_attente', 'acceptee', 'refusee'
  final String dateCandidature;

  // Champs calculés (jointures), pas enregistrés dans la table
  final String? postTitre;
  final double? postBudget;
  final String? freelancerUsername;
  final String? clientUsername;
  final String? postTypeBudget;

  Candidature({
    this.id,
    required this.postId,
    required this.freelancerId,
    required this.message,
    this.statut = 'en_attente',
    required this.dateCandidature,
    this.postTitre,
    this.postBudget,
    this.freelancerUsername,
    this.clientUsername,
    this.postTypeBudget,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'freelancer_id': freelancerId,
      'message': message,
      'statut': statut,
      'date_candidature': dateCandidature,
    };
  }

  factory Candidature.fromMap(Map<String, dynamic> map) {
    return Candidature(
      id: map['id'] as int?,
      postId: map['post_id'] as int,
      freelancerId: map['freelancer_id'] as int,
      message: map['message'] as String,
      statut: map['statut'] as String,
      dateCandidature: map['date_candidature'] as String,
      postTitre: map['post_titre'] as String?,
      postBudget: (map['post_budget'] as num?)?.toDouble(),
      freelancerUsername: map['freelancer_username'] as String?,
      clientUsername: map['client_username'] as String?,
      postTypeBudget: map['post_type_budget'] as String?,
    );
  }
}
