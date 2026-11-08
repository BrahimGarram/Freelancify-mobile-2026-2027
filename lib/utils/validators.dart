import '../models/post_options.dart';

/// Contrôle de saisie : toutes les règles de validation des formulaires.
///
/// Chaque fonction renvoie `null` si la valeur est correcte, sinon le message
/// d'erreur à afficher sous le champ. Elles s'utilisent directement comme
/// `validator:` d'un champ de formulaire.
class Validators {
  Validators._();

  // ---------- Limites (utilisées aussi pour le maxLength des champs) ----------
  static const usernameMin = 3;
  static const usernameMax = 20;
  static const emailMax = 100;
  static const passwordMin = 8;
  static const passwordMax = 64;
  static const titreMin = 5;
  static const titreMax = 80;
  static const descriptionMin = 20;
  static const descriptionMax = 1000;
  static const messageMin = 20;
  static const messageMax = 500;
  static const messageChatMax = 1000;
  static const budgetMax = 1000000; // prix fixe, en DT
  static const tauxHoraireMax = 500; // par heure, en DT
  static const categoriesMax = 3;
  static const competencesMax = 5;
  static const competenceMin = 2;
  static const competenceMax = 20;
  static const delaiMaxJours = 365;
  static const metierMin = 2;
  static const metierMax = 50;
  static const bioMax = 500;
  static const clientMax = 60;
  static const lienMax = 200;
  static const precisionMotifMin = 5;
  static const precisionMotifMax = 60;
  static const explicationDemandeMin = 30;
  static const explicationDemandeMax = 300;
  static const revisionsDemandeMin = 20;
  static const revisionsDemandeMax = 200;
  static const heuresRevisionMax = 200;
  static const imageMaxOctets = 5 * 1024 * 1024; // 5 Mo
  static const extensionsImage = ['jpg', 'jpeg', 'png', 'webp'];

  static final _usernameRegex = RegExp(r'^[\p{L}\p{N}_.\-]+$', unicode: true);
  static final _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );
  static final _budgetRegex = RegExp(r'^\d+([.,]\d{1,2})?$');
  // lettres, chiffres, espace et + # . / - (ex : "C#", "Node.js", "UI/UX")
  static final _competenceRegex = RegExp(
    r'^[\p{L}\p{N}][\p{L}\p{N} +#./\-]*$',
    unicode: true,
  );

  // ---------- Utilisateur ----------
  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return "Choisis un nom d'utilisateur";
    if (v.length < usernameMin) return '$usernameMin caractères minimum';
    if (v.length > usernameMax) return '$usernameMax caractères maximum';
    if (!_usernameRegex.hasMatch(v)) {
      return 'Lettres, chiffres, . _ - uniquement (sans espace)';
    }
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Entre ton email';
    if (v.length > emailMax) return '$emailMax caractères maximum';
    if (v.contains('..') || !_emailRegex.hasMatch(v)) return 'Email invalide';
    return null;
  }

  /// Mot de passe à la connexion : on vérifie seulement qu'il est rempli
  /// (les anciens comptes peuvent avoir un mot de passe plus simple).
  static String? passwordLogin(String? value) {
    if (value == null || value.isEmpty) return 'Entre ton mot de passe';
    return null;
  }

  /// Nouveau mot de passe (inscription, changement de mot de passe)
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Choisis un mot de passe';
    if (v.length < passwordMin) return '$passwordMin caractères minimum';
    if (v.length > passwordMax) return '$passwordMax caractères maximum';
    if (v.contains(RegExp(r'\s'))) return "Pas d'espace dans le mot de passe";
    if (!v.contains(RegExp(r'[A-Za-z]'))) return 'Ajoute au moins une lettre';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Ajoute au moins un chiffre';
    return null;
  }

  /// Confirmation : doit être identique au mot de passe saisi.
  static String? Function(String?) confirmation(String Function() original) =>
      (value) {
        if (value == null || value.isEmpty) return 'Confirme le mot de passe';
        if (value != original()) {
          return 'Les mots de passe ne correspondent pas';
        }
        return null;
      };

  // ---------- Post ----------
  static String? titre(String? value) => _texte(
    value,
    vide: 'Donne un titre à ton post',
    min: titreMin,
    max: titreMax,
  );

  static String? description(String? value) => _texte(
    value,
    vide: 'Décris le travail demandé',
    min: descriptionMin,
    max: descriptionMax,
    tropCourt:
        'Ajoute un peu plus de détails ($descriptionMin caractères min.)',
  );

  /// Budget : la limite dépend du type ('fixe' ou 'horaire').
  static String? budget(String? value, {String typeBudget = 'fixe'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Entre un budget';
    if (!_budgetRegex.hasMatch(v)) {
      return 'Montant invalide (ex : 150 ou 150,50)';
    }
    final montant = lireBudget(v)!;
    if (montant <= 0) return 'Le budget doit être supérieur à 0';
    if (typeBudget == 'horaire' && montant > tauxHoraireMax) {
      return 'Taux horaire maximum : $tauxHoraireMax DT/h';
    }
    if (montant > budgetMax) return 'Budget maximum : $budgetMax DT';
    return null;
  }

  /// Champ à choix obligatoire (catégorie, type de budget, mode de travail)
  static String? Function(String?) choix(
    Map<String, String> options,
    String messageVide,
  ) => (value) {
    if (value == null || value.isEmpty) return messageVide;
    if (!options.containsKey(value)) return 'Choix invalide';
    return null;
  };

  /// Catégories d'un post : au moins 1, au plus 3, sans doublon.
  static String? categories(List<String>? value) {
    final liste = value ?? const [];
    if (liste.isEmpty) return 'Choisis au moins une catégorie';
    if (liste.length > categoriesMax) {
      return '$categoriesMax catégories maximum';
    }
    if (liste.toSet().length != liste.length) return 'Catégorie en double';
    if (liste.any((c) => !PostOptions.categories.containsKey(c))) {
      return 'Choix invalide';
    }
    return null;
  }

  /// Date limite : obligatoire, au plus tôt demain, au plus tard dans 1 an.
  /// [aujourdHui] sert uniquement aux tests.
  static String? dateLimite(DateTime? value, {DateTime? aujourdHui}) {
    if (value == null) return 'Choisis une date limite';
    final now = aujourdHui ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final jour = DateTime(value.year, value.month, value.day);
    if (!jour.isAfter(today)) return 'La date doit être au plus tôt demain';
    if (jour.isAfter(today.add(const Duration(days: delaiMaxJours)))) {
      return 'Au maximum dans $delaiMaxJours jours';
    }
    return null;
  }

  /// Ville : obligatoire seulement pour un travail sur place ou hybride.
  static String? ville(String? value, String? modeTravail) {
    if (!PostOptions.besoinVille(modeTravail)) return null;
    if (value == null || value.isEmpty) return 'Choisis la ville';
    if (!PostOptions.villes.contains(value)) return 'Ville invalide';
    return null;
  }

  /// Une compétence avant de l'ajouter à la liste.
  static String? competence(String? value, List<String> dejaAjoutees) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Écris une compétence';
    if (v.length < competenceMin) return '$competenceMin caractères minimum';
    if (v.length > competenceMax) return '$competenceMax caractères maximum';
    if (!_competenceRegex.hasMatch(v)) return 'Caractères non autorisés';
    if (dejaAjoutees.any((c) => c.toLowerCase() == v.toLowerCase())) {
      return 'Compétence déjà ajoutée';
    }
    if (dejaAjoutees.length >= competencesMax) {
      return '$competencesMax compétences maximum';
    }
    return null;
  }

  /// La liste complète (facultative, mais au plus 5 éléments valides).
  static String? competences(List<String>? value) {
    final liste = value ?? const [];
    if (liste.length > competencesMax) {
      return '$competencesMax compétences maximum';
    }
    for (var i = 0; i < liste.length; i++) {
      final erreur = competence(liste[i], liste.sublist(0, i));
      if (erreur != null) return '« ${liste[i]} » : $erreur';
    }
    return null;
  }

  /// Accepte "150", "150.5" et "150,5"
  static double? lireBudget(String texte) =>
      double.tryParse(texte.trim().replaceAll(',', '.'));

  // ---------- Candidature ----------
  static String? message(String? value) => _texte(
    value,
    vide: 'Écris un message au client',
    min: messageMin,
    max: messageMax,
    tropCourt: 'Présente-toi un peu plus ($messageMin caractères min.)',
  );

  /// Message dans une discussion : non vide, 1000 caractères maximum.
  static String? messageChat(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Écris un message';
    if (v.length > messageChatMax) return '$messageChatMax caractères maximum';
    return null;
  }

  // ---------- Profil freelancer ----------
  /// Métier : facultatif, 2 à 50 caractères (lettres, chiffres, espaces…)
  static String? metier(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length < metierMin) return '$metierMin caractères minimum';
    if (v.length > metierMax) return '$metierMax caractères maximum';
    if (!RegExp(
      r"^[\p{L}\p{N}][\p{L}\p{N} '&/+#.\-]*$",
      unicode: true,
    ).hasMatch(v)) {
      return 'Caractères non autorisés';
    }
    return null;
  }

  /// Bio : facultative, 500 caractères maximum
  static String? bio(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > bioMax) return '$bioMax caractères maximum';
    return null;
  }

  // ---------- Réalisation (portfolio) ----------
  static String? titreRealisation(String? value) => _texte(
    value,
    vide: 'Donne un titre à ta réalisation',
    min: titreMin,
    max: titreMax,
  );

  static String? descriptionRealisation(String? value) => _texte(
    value,
    vide: 'Décris ce que tu as fait',
    min: descriptionMin,
    max: descriptionMax,
    tropCourt:
        'Ajoute un peu plus de détails ($descriptionMin caractères min.)',
  );

  /// Client / entreprise : facultatif, 2 à 60 caractères
  static String? clientRealisation(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length < 2) return '2 caractères minimum';
    if (v.length > clientMax) return '$clientMax caractères maximum';
    return null;
  }

  /// Lien : facultatif ; sinon une adresse web valide (http ou https).
  /// "monsite.tn" est accepté (https:// est ajouté par [normaliserLien]).
  static String? lien(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length > lienMax) return '$lienMax caractères maximum';
    if (v.contains(RegExp(r'\s'))) return "Pas d'espace dans un lien";
    final uri = Uri.tryParse(normaliserLien(v)!);
    final hote = uri?.host ?? '';
    final ok =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        RegExp(r'^[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$')
            .hasMatch(hote);
    if (!ok) return 'Lien invalide (ex : https://monsite.tn)';
    return null;
  }

  /// Ajoute https:// si l'utilisateur ne l'a pas écrit. Null si vide.
  static String? normaliserLien(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return RegExp(r'^https?://', caseSensitive: false).hasMatch(v)
        ? v
        : 'https://$v';
  }

  /// Photo : facultative ; jpg / png / webp de 5 Mo maximum.
  static String? image(String? chemin, int? tailleOctets) {
    if (chemin == null) return null;
    final ext = chemin.split('.').last.toLowerCase();
    if (!extensionsImage.contains(ext)) {
      return 'Format non accepté (jpg, png ou webp)';
    }
    if (tailleOctets != null && tailleOctets > imageMaxOctets) {
      return 'Image trop lourde (5 Mo maximum)';
    }
    if (tailleOctets == 0) return 'Image vide ou illisible';
    return null;
  }

  // ---------- Outil commun ----------
  // ---------- Demande de tentative supplémentaire ----------
  /// Obligatoire seulement si le motif est « Autre »
  static String? precisionMotif(String? value, String? motif) {
    if (motif != 'autre') return null;
    return _texte(
      value,
      vide: 'Précise le motif',
      min: precisionMotifMin,
      max: precisionMotifMax,
    );
  }

  static String? explicationDemande(String? value) =>
      _texte(
        value,
        vide: 'Explique ce qui s\'est passé',
        min: explicationDemandeMin,
        max: explicationDemandeMax,
      ) ??
      _phrase(value, mots: 5);

  static String? revisionsDemande(String? value) =>
      _texte(
        value,
        vide: 'Indique ce que tu as révisé',
        min: revisionsDemandeMin,
        max: revisionsDemandeMax,
      ) ??
      _phrase(value, mots: 3);

  static String? heuresRevision(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Indique le nombre d\'heures';
    if (!RegExp(r'^\d+$').hasMatch(v)) return 'Nombre entier uniquement';
    final n = int.parse(v);
    if (n < 1) return 'Au moins 1 heure';
    if (n > heuresRevisionMax) return '$heuresRevisionMax heures maximum';
    return null;
  }

  static String? engagement(bool? value) =>
      value == true ? null : 'Tu dois accepter cet engagement';

  /// Refuse les textes de remplissage (« aaaaaaaa », « 12345 »…)
  static String? _phrase(String? value, {required int mots}) {
    final v = value!.trim().toLowerCase();
    final liste = v
        .split(RegExp(r'\s+'))
        .where((m) => RegExp(r'\p{L}{2,}', unicode: true).hasMatch(m))
        .toList();
    if (liste.length < mots || liste.toSet().length < (mots + 1) ~/ 2) {
      return 'Écris une vraie phrase ($mots mots minimum)';
    }
    return null;
  }

  static String? _texte(
    String? value, {
    required String vide,
    required int min,
    required int max,
    String? tropCourt,
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return vide;
    if (v.length < min) return tropCourt ?? '$min caractères minimum';
    if (v.length > max) return '$max caractères maximum';
    return null;
  }
}
