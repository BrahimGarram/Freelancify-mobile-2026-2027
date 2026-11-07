import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/validators.dart';

/// Stockage des photos du portfolio, DANS l'application (hors connexion).
/// La photo choisie est copiée : elle reste visible même si l'original
/// est supprimé de la galerie.
class ImageService {
  /// Dossier de stockage. Modifiable uniquement pour les tests.
  static Directory? overrideDir;

  Future<Directory> _dossier() async {
    final base = overrideDir ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'realisations'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Vérifie puis copie l'image dans l'app. Renvoie le nouveau chemin.
  Future<String> enregistrer(String source) async {
    final fichier = File(source);
    if (!await fichier.exists()) throw ImageException('Image introuvable');
    final erreur = Validators.image(source, await fichier.length());
    if (erreur != null) throw ImageException(erreur);

    final ext = p.extension(source).toLowerCase();
    final nom = 'img_${DateTime.now().microsecondsSinceEpoch}$ext';
    final copie = await fichier.copy(p.join((await _dossier()).path, nom));
    return copie.path;
  }

  /// Supprime une image de l'app (sans erreur si elle n'existe plus).
  Future<void> supprimer(String? chemin) async {
    if (chemin == null) return;
    try {
      final f = File(chemin);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // pas grave : au pire un fichier orphelin
    }
  }
}

class ImageException implements Exception {
  final String message;
  ImageException(this.message);

  @override
  String toString() => message;
}
