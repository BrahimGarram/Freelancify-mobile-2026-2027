import 'dart:convert';

import 'package:flutter/services.dart';

/// Les secrets de l'application (clés Gemini, mot de passe Gmail).
///
/// Ils sont lus au démarrage dans `assets/config/secrets.json` (fichier non
/// versionné, voir `secrets.example.json`). Ainsi l'app les trouve quel que
/// soit le moyen de la lancer (bouton ▶ d'Android Studio, VS Code,
/// `flutter run`, `flutter build apk`).
///
/// Une valeur passée avec `--dart-define` reste prioritaire.
class Secrets {
  Secrets._();

  static const chemin = 'assets/config/secrets.json';
  static Map<String, String> _valeurs = const {};

  /// À appeler une fois, avant runApp
  static Future<void> charger() async {
    try {
      final json = jsonDecode(await rootBundle.loadString(chemin)) as Map;
      _valeurs = {
        for (final e in json.entries) '${e.key}': '${e.value ?? ''}'.trim(),
      };
    } catch (_) {
      _valeurs = const {}; // pas de fichier : IA et emails désactivés
    }
  }

  /// [define] : la valeur de `String.fromEnvironment(cle)` (prioritaire)
  static String lire(String cle, String define, {String defaut = ''}) {
    if (define.isNotEmpty) return define;
    final v = _valeurs[cle] ?? '';
    // les textes d'exemple ne sont pas de vraies clés
    if (v.isEmpty ||
        v.startsWith('colle-ici') ||
        v.startsWith('mot-de-passe')) {
      return defaut;
    }
    return v;
  }
}
