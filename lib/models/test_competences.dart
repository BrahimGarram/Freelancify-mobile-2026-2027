import '../models/post_options.dart';

/// Une question du quiz, avec ses choix dans l'ordre AFFICHÉ (mélangé).
class QuestionQuiz {
  final int id;
  final String domaine;
  final String enonce;
  final List<String> choix; // ordre affiché
  final List<int> ordre; // ordre[affiché] = index d'origine en base (0..3)
  final int duree; // temps pour répondre, en secondes

  const QuestionQuiz({
    required this.id,
    required this.domaine,
    required this.enonce,
    required this.choix,
    required this.ordre,
    this.duree = 30,
  });

  /// Index en base du choix affiché à la position [affiche]
  int indexOrigine(int affiche) => ordre[affiche];
}

class Quiz {
  final int tentativeId; // la tentative est comptée dès le début du test
  final List<String> domaines;
  final List<QuestionQuiz> questions;
  const Quiz({
    required this.tentativeId,
    required this.domaines,
    required this.questions,
  });
}

/// Où en est le freelancer : tentatives utilisées, certification
class EtatTests {
  final int utilisees;
  final int max;
  final bool certifie;
  const EtatTests({
    required this.utilisees,
    required this.max,
    required this.certifie,
  });

  int get restantes => (max - utilisees).clamp(0, max);

  /// Un test réussi ne se repasse pas ; au-delà de [max] essais, c'est fini
  bool get peutPasser => !certifie && restantes > 0;
}

/// Rapport de l'IA après un test : court, concret, personnel
class RapportTest {
  final int tentativeId;
  final String synthese;
  final List<String> pointsForts;
  final List<String> pointsFaibles;
  final List<String> conseils;
  final String dateCreation;

  const RapportTest({
    required this.tentativeId,
    required this.synthese,
    required this.pointsForts,
    required this.pointsFaibles,
    required this.conseils,
    required this.dateCreation,
  });
}

/// Correction d'une question après le test
class CorrectionQuestion {
  final QuestionQuiz question;
  final String? reponseDonnee; // null : temps écoulé sans réponse
  final String bonneReponse;
  bool get correcte => reponseDonnee == bonneReponse;
  bool get sansReponse => reponseDonnee == null;

  const CorrectionQuestion({
    required this.question,
    this.reponseDonnee,
    required this.bonneReponse,
  });
}

class ResultatTest {
  final int tentativeId;
  final int score;
  final int total;
  final int pourcentage;
  final bool reussi;
  final Map<String, ({int bonnes, int total})> parDomaine;
  final List<CorrectionQuestion> corrections;
  final Certification? certification; // si réussi
  final int tentativesRestantes;

  const ResultatTest({
    required this.tentativeId,
    required this.score,
    required this.total,
    required this.pourcentage,
    required this.reussi,
    required this.parDomaine,
    required this.corrections,
    this.certification,
    this.tentativesRestantes = 0,
  });
}

/// Certification délivrée par « freelance » quand le test est réussi
class Certification {
  final int? id;
  final int freelancerId;
  final int tentativeId;
  final String numero; // ex : FRL-2026-7KQ2MX
  final String nomFreelancer;
  final String? metier;
  final List<String> domaines;
  final String competences; // ex : « Design 4/5 · Développement 5/5 »
  final int score;
  final int total;
  final int pourcentage;
  final String mention;
  final String dateObtention;

  const Certification({
    this.id,
    required this.freelancerId,
    required this.tentativeId,
    required this.numero,
    required this.nomFreelancer,
    this.metier,
    required this.domaines,
    required this.competences,
    required this.score,
    required this.total,
    required this.pourcentage,
    required this.mention,
    required this.dateObtention,
  });

  String get domainesLisibles =>
      domaines.map((d) => PostOptions.categories[d] ?? d).join(', ');

  Map<String, dynamic> toMap() => {
    'freelancer_id': freelancerId,
    'tentative_id': tentativeId,
    'numero': numero,
    'nom_freelancer': nomFreelancer,
    'metier': metier,
    'domaines': domaines.join(','),
    'competences': competences,
    'score': score,
    'total': total,
    'pourcentage': pourcentage,
    'mention': mention,
    'date_obtention': dateObtention,
  };

  factory Certification.fromMap(Map<String, dynamic> m) => Certification(
    id: m['id'] as int,
    freelancerId: m['freelancer_id'] as int,
    tentativeId: m['tentative_id'] as int,
    numero: m['numero'] as String,
    nomFreelancer: m['nom_freelancer'] as String,
    metier: m['metier'] as String?,
    domaines: (m['domaines'] as String).split(','),
    competences: m['competences'] as String,
    score: m['score'] as int,
    total: m['total'] as int,
    pourcentage: m['pourcentage'] as int,
    mention: m['mention'] as String,
    dateObtention: m['date_obtention'] as String,
  );
}

/// Un test passé (historique)
class TentativeTest {
  final int id;
  final List<String> domaines;
  final int score;
  final int total;
  final int pourcentage;
  final bool reussi;
  final String date;
  final bool enCours; // commencée mais jamais terminée : abandonnée

  const TentativeTest({
    required this.id,
    required this.domaines,
    required this.score,
    required this.total,
    required this.pourcentage,
    required this.reussi,
    required this.date,
    this.enCours = false,
  });

  factory TentativeTest.fromMap(Map<String, dynamic> m) => TentativeTest(
    id: m['id'] as int,
    domaines: (m['domaines'] as String).split(','),
    score: m['score'] as int,
    total: m['total'] as int,
    pourcentage: m['pourcentage'] as int,
    reussi: (m['reussi'] as int) == 1,
    date: m['date_tentative'] as String,
    enCours: m['statut'] == 'en_cours',
  );
}
