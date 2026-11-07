import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Les cas d'erreur, pour afficher un message clair à l'utilisateur
enum GeminiErreur {
  cleManquante,
  horsLigne,
  delaiDepasse,
  cleInvalide,
  quota,
  surcharge,
  bloque,
  reponseInvalide,
  inconnue,
}

class GeminiException implements Exception {
  final GeminiErreur type;
  final String message; // message en français, prêt à afficher
  const GeminiException(this.type, this.message);

  @override
  String toString() => 'GeminiException($type) : $message';
}

/// Un message d'une conversation (utilisateur ou assistant)
class GeminiMessage {
  final bool deLUtilisateur;
  final String texte;
  const GeminiMessage.utilisateur(this.texte) : deLUtilisateur = true;
  const GeminiMessage.assistant(this.texte) : deLUtilisateur = false;
}

/// Petit client HTTP pour l'API Gemini (`models/{modèle}:generateContent`).
/// Le [http.Client] peut être remplacé dans les tests.
class GeminiClient {
  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  final String apiKey;
  final String modele;
  final http.Client _http;
  final Duration delai;

  /// Modèle utilisé si [modele] reste surchargé (erreur 5xx) malgré les
  /// nouveaux essais (ex : un modèle « lite », moins demandé).
  final String? modeleSecours;

  /// Nouveaux essais après une surcharge passagère (HTTP 5xx), avec une
  /// attente de [attenteReessai], puis 2×, 3×…
  final int reessais;
  final Duration attenteReessai;

  GeminiClient({
    required this.apiKey,
    required this.modele,
    http.Client? client,
    this.delai = const Duration(seconds: 30),
    this.modeleSecours,
    this.reessais = 2,
    this.attenteReessai = const Duration(seconds: 1),
  }) : _http = client ?? http.Client();

  bool get estConfigure => apiKey.trim().isNotEmpty;

  /// Envoie la conversation et renvoie le texte généré.
  /// Avec [schemaJson], la réponse est un JSON conforme à ce schéma.
  /// Si le service est surchargé, on réessaie, puis on passe au
  /// [modeleSecours] s'il y en a un.
  Future<String> generer({
    required String instructions,
    required List<GeminiMessage> messages,
    Map<String, dynamic>? schemaJson,
    String reflexion = 'LOW', // MINIMAL, LOW, MEDIUM, HIGH
    int maxTokens = 2048,
  }) async {
    final modeles = [modele, ?modeleSecours];
    for (var m = 0; m < modeles.length; m++) {
      for (var essai = 0; ; essai++) {
        try {
          return await _appeler(
            modeles[m],
            instructions: instructions,
            messages: messages,
            schemaJson: schemaJson,
            reflexion: reflexion,
            maxTokens: maxTokens,
          );
        } on GeminiException catch (e) {
          final dernierModele = m == modeles.length - 1;
          if (e.type != GeminiErreur.surcharge) rethrow;
          if (essai < reessais) {
            debugPrint('[IA] ${modeles[m]} surchargé : nouvel essai');
            await Future<void>.delayed(attenteReessai * (essai + 1));
            continue;
          }
          if (dernierModele) rethrow;
          debugPrint('[IA] ${modeles[m]} surchargé : modèle ${modeles[m + 1]}');
          break; // modèle suivant
        }
      }
    }
    throw StateError('inatteignable');
  }

  Future<String> _appeler(
    String modele, {
    required String instructions,
    required List<GeminiMessage> messages,
    Map<String, dynamic>? schemaJson,
    required String reflexion,
    required int maxTokens,
  }) async {
    if (!estConfigure) {
      throw const GeminiException(
        GeminiErreur.cleManquante,
        "L'assistant IA n'est pas configuré (clé API manquante).",
      );
    }

    final corps = {
      'systemInstruction': {
        'parts': [
          {'text': instructions},
        ],
      },
      'contents': [
        for (final m in messages)
          {
            'role': m.deLUtilisateur ? 'user' : 'model',
            'parts': [
              {'text': m.texte},
            ],
          },
      ],
      'generationConfig': {
        'maxOutputTokens': maxTokens,
        'thinkingConfig': {'thinkingLevel': reflexion},
        if (schemaJson != null) ...{
          'responseMimeType': 'application/json',
          'responseJsonSchema': schemaJson,
        },
      },
    };

    final http.Response reponse;
    try {
      reponse = await _http
          .post(
            Uri.parse('$_base/models/$modele:generateContent'),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(corps),
          )
          .timeout(delai);
    } on TimeoutException {
      throw const GeminiException(
        GeminiErreur.delaiDepasse,
        "L'IA met trop de temps à répondre. Réessaie.",
      );
    } on SocketException {
      throw _horsLigne;
    } on http.ClientException {
      throw _horsLigne;
    }

    if (reponse.statusCode != 200) {
      debugPrint('[IA] ❌ $modele : HTTP ${reponse.statusCode} ${reponse.body}');
      throw _erreurHttp(reponse);
    }
    debugPrint('[IA] ✅ $modele : réponse reçue');
    return _lireTexte(reponse.body);
  }

  static const _horsLigne = GeminiException(
    GeminiErreur.horsLigne,
    'Pas de connexion Internet. Cette fonction a besoin du réseau.',
  );

  static GeminiException _erreurHttp(http.Response r) {
    var detail = '';
    try {
      detail = (jsonDecode(r.body)['error']?['message'] as String?) ?? '';
    } catch (_) {}
    final cleRefusee =
        r.statusCode == 401 ||
        r.statusCode == 403 ||
        (r.statusCode == 400 && detail.toLowerCase().contains('api key'));
    if (cleRefusee) {
      return const GeminiException(
        GeminiErreur.cleInvalide,
        'La clé API Gemini est invalide ou désactivée.',
      );
    }
    if (r.statusCode == 429) {
      return const GeminiException(
        GeminiErreur.quota,
        'Limite gratuite atteinte. Attends une minute puis réessaie.',
      );
    }
    if (r.statusCode >= 500) {
      return const GeminiException(
        GeminiErreur.surcharge,
        "Le service d'IA est momentanément indisponible. Réessaie.",
      );
    }
    return GeminiException(
      GeminiErreur.inconnue,
      'Erreur du service IA (${r.statusCode}).',
    );
  }

  static String _lireTexte(String body) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const GeminiException(
        GeminiErreur.reponseInvalide,
        "Réponse de l'IA illisible. Réessaie.",
      );
    }

    const bloque = GeminiException(
      GeminiErreur.bloque,
      "L'IA n'a pas pu traiter cette demande. Reformule-la.",
    );
    if (json['promptFeedback']?['blockReason'] != null) throw bloque;

    final candidats = json['candidates'] as List?;
    if (candidats == null || candidats.isEmpty) throw bloque;
    final candidat = candidats.first as Map<String, dynamic>;
    final fin = candidat['finishReason'] as String?;
    if (fin != null && fin != 'STOP' && fin != 'MAX_TOKENS') throw bloque;

    final parts = (candidat['content']?['parts'] as List?) ?? const [];
    final texte = parts
        .whereType<Map<String, dynamic>>()
        .where((p) => p['thought'] != true) // ignore la réflexion interne
        .map((p) => p['text'])
        .whereType<String>()
        .join()
        .trim();
    if (texte.isEmpty) {
      throw const GeminiException(
        GeminiErreur.reponseInvalide,
        "L'IA n'a rien répondu. Réessaie.",
      );
    }
    return texte;
  }
}
