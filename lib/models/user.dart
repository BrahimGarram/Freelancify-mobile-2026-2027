class User {
  final int? id; // null avant l'insertion, SQLite le génère
  final String username;
  final String email;
  final String password;
  final String role; // 'freelancer' ou 'client'

  // Profil public (surtout pour les freelancers)
  final String? metier; // ex : "Graphiste", "Développeur Flutter"
  final String? bio; // présentation libre

  /// Domaines choisis au 1er test de compétences (ex : ['dev', 'design']).
  /// Fixés une fois pour toutes : écrits seulement par TestService.
  final List<String> domaines;

  User({
    this.id,
    required this.username,
    required this.email,
    required this.password,
    required this.role,
    this.metier,
    this.bio,
    this.domaines = const [],
  });

  bool get isFreelancer => role == 'freelancer';

  // Objet -> Map (pour insérer dans SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'role': role,
      'metier': metier,
      'bio': bio,
    };
  }

  // Map -> Objet (quand tu lis depuis SQLite)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      password: map['password'],
      role: map['role'],
      metier: map['metier'] as String?,
      bio: map['bio'] as String?,
      domaines: lireDomaines(map['domaines'] as String?),
    );
  }

  /// "dev,design" -> ['dev', 'design'] ; null ou vide -> []
  static List<String> lireDomaines(String? brut) {
    if (brut == null || brut.trim().isEmpty) return const [];
    return brut.split(',').where((d) => d.isNotEmpty).toList();
  }
}
