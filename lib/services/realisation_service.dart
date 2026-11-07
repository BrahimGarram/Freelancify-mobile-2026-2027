import '../database/database_helper.dart';
import '../models/realisation.dart';
import '../utils/validators.dart';
import 'image_service.dart';

/// Le portfolio des freelancers.
class RealisationService {
  final _dbHelper = DatabaseHelper.instance;
  final _images = ImageService();

  /// Publie une réalisation. [imageSource] : chemin de la photo choisie
  /// (facultatif) ; elle est vérifiée puis copiée dans l'app.
  Future<Realisation> publier(
    Realisation realisation, {
    String? imageSource,
  }) async {
    // Contrôle de saisie côté service aussi (sécurité)
    final erreur =
        Validators.titreRealisation(realisation.titre) ??
        Validators.descriptionRealisation(realisation.description) ??
        Validators.clientRealisation(realisation.client) ??
        Validators.lien(realisation.lien);
    if (erreur != null) throw RealisationException(erreur);

    String? imagePath;
    if (imageSource != null) {
      try {
        imagePath = await _images.enregistrer(imageSource);
      } on ImageException catch (e) {
        throw RealisationException(e.message);
      }
    }

    final map = realisation.toMap()
      ..['titre'] = realisation.titre.trim()
      ..['description'] = realisation.description.trim()
      ..['client'] = _videEnNull(realisation.client)
      ..['lien'] = Validators.normaliserLien(realisation.lien)
      ..['image_path'] = imagePath;
    try {
      final db = await _dbHelper.database;
      final id = await db.insert('realisations', map);
      return Realisation.fromMap({...map, 'id': id});
    } catch (_) {
      await _images.supprimer(imagePath); // pas d'image orpheline
      rethrow;
    }
  }

  /// Les réalisations d'un freelancer, la plus récente en premier.
  Future<List<Realisation>> getByFreelancer(int freelancerId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'realisations',
      where: 'freelancer_id = ?',
      whereArgs: [freelancerId],
      orderBy: 'id DESC',
    );
    return maps.map(Realisation.fromMap).toList();
  }

  /// Supprime une réalisation (seulement par son auteur) et sa photo.
  Future<void> supprimer(Realisation r, int freelancerId) async {
    final db = await _dbHelper.database;
    final n = await db.delete(
      'realisations',
      where: 'id = ? AND freelancer_id = ?',
      whereArgs: [r.id, freelancerId],
    );
    if (n > 0) await _images.supprimer(r.imagePath);
  }

  /// Nombre de missions acceptées (affiché sur le profil)
  Future<int> nbMissionsAcceptees(int freelancerId) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) AS n FROM candidatures "
      "WHERE freelancer_id = ? AND statut = 'acceptee'",
      [freelancerId],
    );
    return (res.first['n'] as int?) ?? 0;
  }

  static String? _videEnNull(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}

class RealisationException implements Exception {
  final String message;
  RealisationException(this.message);

  @override
  String toString() => message;
}
