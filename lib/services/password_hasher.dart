import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hachage des mots de passe : SHA-256 + sel aléatoire + itérations.
///
/// Format stocké en base : `sha256$<iterations>$<sel>$<hash>`
/// - le sel (unique par utilisateur) empêche deux mots de passe identiques
///   d'avoir le même hash ;
/// - les itérations rendent une attaque par force brute beaucoup plus lente.
/// Le mot de passe en clair n'est JAMAIS enregistré.
class PasswordHasher {
  static const _prefix = 'sha256';
  static const _iterations = 10000;
  static final _random = Random.secure();

  /// Transforme un mot de passe en clair en chaîne hachée à stocker.
  static String hash(String password) {
    final salt = base64Url.encode(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    final digest = _derive(password, salt, _iterations);
    return '$_prefix\$$_iterations\$$salt\$$digest';
  }

  /// Vérifie un mot de passe en clair contre la valeur stockée.
  static bool verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _prefix) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations <= 0) return false;
    final digest = _derive(password, parts[2], iterations);
    return _constantTimeEquals(digest, parts[3]);
  }

  /// Vrai si la valeur est déjà au format haché (utile pour la migration).
  static bool isHashed(String stored) =>
      stored.startsWith('$_prefix\$') && stored.split(r'$').length == 4;

  static String _derive(String password, String salt, int iterations) {
    List<int> bytes = utf8.encode('$salt$password');
    for (var i = 0; i < iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }

  // Comparaison en temps constant (ne révèle pas où les chaînes diffèrent)
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
