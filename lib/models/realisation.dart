/// Une réalisation du portfolio d'un freelancer : un projet, une
/// expérience, un site sur lequel il a travaillé… (photo facultative).
class Realisation {
  final int? id;
  final int freelancerId;
  final String titre;
  final String description;
  final String categorie; // clé de PostOptions.categories
  final String? client; // pour qui (entreprise, client…), facultatif
  final String? lien; // URL du site / du projet, facultatif
  final String? imagePath; // chemin de la photo copiée dans l'app
  final String dateCreation;

  Realisation({
    this.id,
    required this.freelancerId,
    required this.titre,
    required this.description,
    this.categorie = 'autre',
    this.client,
    this.lien,
    this.imagePath,
    required this.dateCreation,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'freelancer_id': freelancerId,
    'titre': titre,
    'description': description,
    'categorie': categorie,
    'client': client,
    'lien': lien,
    'image_path': imagePath,
    'date_creation': dateCreation,
  };

  factory Realisation.fromMap(Map<String, dynamic> map) => Realisation(
    id: map['id'] as int?,
    freelancerId: map['freelancer_id'] as int,
    titre: map['titre'] as String,
    description: map['description'] as String,
    categorie: (map['categorie'] as String?) ?? 'autre',
    client: map['client'] as String?,
    lien: map['lien'] as String?,
    imagePath: map['image_path'] as String?,
    dateCreation: map['date_creation'] as String,
  );
}
