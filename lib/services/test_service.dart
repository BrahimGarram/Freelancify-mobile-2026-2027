import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/post_options.dart';
import '../models/test_competences.dart';
import '../models/user.dart';

class TestException implements Exception {
  final String message;
  const TestException(this.message);
  @override
  String toString() => message;
}

/// Tests de compétences des freelancers.
///
/// 1. Le freelancer choisit un ou plusieurs domaines.
/// 2. [genererQuiz] tire 10 questions réparties entre ces domaines, en
///    donnant la priorité aux questions qu'il n'a JAMAIS vues : un nouveau
///    test après un échec ne repose pas les mêmes questions.
/// 3. [corriger] calcule le score à partir de la base (pas de l'écran),
///    enregistre la tentative et, si le score atteint 50 %, délivre une
///    certification.
class TestService {
  static const nbQuestions = 10;
  static const seuilReussite = 50; // en %
  static const tentativesMax = 3;

  final _db = DatabaseHelper.instance;
  final Random _random;

  TestService({Random? random}) : _random = random ?? Random();

  /// Les domaines qui ont des questions, avec leur nombre de questions
  Future<Map<String, int>> domainesDisponibles() async {
    final db = await _db.database;
    final lignes = await db.rawQuery(
      'SELECT domaine, COUNT(*) AS n FROM test GROUP BY domaine',
    );
    final nb = {for (final l in lignes) l['domaine'] as String: l['n'] as int};
    // dans l'ordre des catégories de l'application
    return {
      for (final d in PostOptions.categories.keys)
        if ((nb[d] ?? 0) > 0) d: nb[d]!,
    };
  }

  /// Contrôle de saisie du choix des domaines
  static String? validerDomaines(List<String>? domaines) {
    final liste = domaines ?? const [];
    if (liste.isEmpty) return 'Choisis au moins un domaine';
    if (liste.toSet().length != liste.length) return 'Domaine en double';
    if (liste.any((d) => !PostOptions.categories.containsKey(d))) {
      return 'Domaine invalide';
    }
    return null;
  }

  /// Les domaines fixés sur le profil du freelancer ([] : pas encore choisis)
  Future<List<String>> domainesProfil(int freelancerId) async {
    final db = await _db.database;
    final l = await db.query(
      'users',
      columns: ['domaines'],
      where: 'id = ?',
      whereArgs: [freelancerId],
    );
    if (l.isEmpty) return const [];
    return User.lireDomaines(l.first['domaines'] as String?);
  }

  /// true si le freelancer a réussi au moins un test (il peut postuler)
  Future<bool> estCertifie(int freelancerId) async {
    final db = await _db.database;
    final n = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM certifications WHERE freelancer_id = ?',
        [freelancerId],
      ),
    );
    return (n ?? 0) > 0;
  }

  /// Tentatives utilisées (même abandonnées) et certification
  Future<EtatTests> etat(int freelancerId) async {
    final db = await _db.database;
    final n = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM tentatives_test WHERE freelancer_id = ?',
        [freelancerId],
      ),
    );
    return EtatTests(
      utilisees: n ?? 0,
      max: tentativesMax,
      certifie: await estCertifie(freelancerId),
    );
  }

  // ---------- FONCTIONNALITÉ : générer un quiz de 10 questions ----------
  Future<Quiz> genererQuiz(int freelancerId, List<String> domaines) async {
    final erreur = validerDomaines(domaines);
    if (erreur != null) throw TestException(erreur);
    final db = await _db.database;

    final infos = await db.query(
      'users',
      columns: ['role', 'domaines'],
      where: 'id = ?',
      whereArgs: [freelancerId],
    );
    if (infos.isEmpty || infos.first['role'] != 'freelancer') {
      throw const TestException('Les tests sont réservés aux freelancers.');
    }

    // Un test réussi ne se repasse pas ; 3 tentatives au maximum
    final e = await etat(freelancerId);
    if (e.certifie) {
      throw const TestException(
        'Tu as déjà réussi le test : ta certification est obtenue.',
      );
    }
    if (e.restantes == 0) {
      throw const TestException(
        'Tu as utilisé tes $tentativesMax tentatives : tu ne peux plus '
        'passer le test.',
      );
    }

    // Les domaines du 1er test sont ajoutés au profil et ne changent plus
    final fixes = User.lireDomaines(infos.first['domaines'] as String?);
    if (fixes.isEmpty) {
      await db.update(
        'users',
        {'domaines': domaines.join(',')},
        where: 'id = ? AND domaines IS NULL',
        whereArgs: [freelancerId],
      );
    } else if (fixes.toSet().length != domaines.toSet().length ||
        !fixes.toSet().containsAll(domaines)) {
      throw TestException(
        'Tes domaines sont fixés sur ton profil '
        '(${fixes.map((d) => PostOptions.categories[d] ?? d).join(', ')}) '
        'et ne peuvent plus être changés.',
      );
    }

    // Toutes les questions des domaines choisis, avec le nombre de fois où
    // ce freelancer les a déjà vues et la date de la dernière fois.
    final marques = List.filled(domaines.length, '?').join(', ');
    final lignes = await db.rawQuery(
      '''
      SELECT q.*,
             COUNT(r.question_id) AS vues,
             MAX(t.date_tentative) AS derniere_fois
      FROM test q
      LEFT JOIN reponses_test r ON r.question_id = q.id
        AND r.tentative_id IN (SELECT id FROM tentatives_test
                               WHERE freelancer_id = ?)
      LEFT JOIN tentatives_test t ON t.id = r.tentative_id
      WHERE q.domaine IN ($marques)
      GROUP BY q.id
    ''',
      [freelancerId, ...domaines],
    );

    // par domaine : jamais vues d'abord (au hasard), puis les plus anciennes
    final parDomaine = <String, List<Map<String, Object?>>>{
      for (final d in domaines) d: [],
    };
    for (final l in lignes) {
      parDomaine[l['domaine'] as String]!.add(l);
    }
    for (final liste in parDomaine.values) {
      liste.shuffle(_random);
      liste.sort((a, b) {
        final va = a['vues'] as int, vb = b['vues'] as int;
        if ((va == 0) != (vb == 0)) return va == 0 ? -1 : 1;
        if (va == 0) return 0; // deux jamais vues : ordre aléatoire gardé
        return ((a['derniere_fois'] as String?) ?? '').compareTo(
          (b['derniere_fois'] as String?) ?? '',
        );
      });
    }
    if (parDomaine.values.every((l) => l.isEmpty)) {
      throw const TestException('Aucune question pour ces domaines.');
    }

    // Répartition des 10 questions entre les domaines (le reste au hasard)
    final quotas = {
      for (final d in domaines) d: nbQuestions ~/ domaines.length,
    };
    final ordreReste = [...domaines]..shuffle(_random);
    for (var i = 0; i < nbQuestions % domaines.length; i++) {
      quotas[ordreReste[i]] = quotas[ordreReste[i]]! + 1;
    }

    final choisies = <Map<String, Object?>>[];
    for (final d in domaines) {
      choisies.addAll(parDomaine[d]!.take(quotas[d]!));
    }
    // un domaine sans assez de questions : on complète avec les autres
    if (choisies.length < nbQuestions) {
      final restantes = [
        for (final d in domaines) ...parDomaine[d]!.skip(quotas[d]!),
      ];
      choisies.addAll(restantes.take(nbQuestions - choisies.length));
    }
    choisies.shuffle(_random);

    // La tentative compte dès maintenant (quitter l'app ne la rend pas).
    // Les questions sont marquées « vues » pour ne pas revenir au test suivant.
    final tentativeId = await db.transaction((txn) async {
      final id = await txn.insert('tentatives_test', {
        'freelancer_id': freelancerId,
        'domaines': domaines.join(','),
        'score': 0,
        'total': choisies.length,
        'pourcentage': 0,
        'reussi': 0,
        'date_tentative': DateTime.now().toIso8601String(),
        'statut': 'en_cours',
      });
      for (final q in choisies) {
        await txn.insert('reponses_test', {
          'tentative_id': id,
          'question_id': q['id'],
          'choix': null,
          'correcte': 0,
        });
      }
      return id;
    });

    return Quiz(
      tentativeId: tentativeId,
      domaines: domaines,
      questions: [for (final l in choisies) _versQuestion(l)],
    );
  }

  QuestionQuiz _versQuestion(Map<String, Object?> l) {
    final choixBase = [
      l['choix_a'] as String,
      l['choix_b'] as String,
      l['choix_c'] as String,
      l['choix_d'] as String,
    ];
    final ordre = [0, 1, 2, 3]..shuffle(_random); // choix mélangés
    return QuestionQuiz(
      id: l['id'] as int,
      domaine: l['domaine'] as String,
      enonce: l['question'] as String,
      choix: [for (final i in ordre) choixBase[i]],
      ordre: ordre,
      duree: (l['duree'] as int?) ?? 30,
    );
  }

  // ---------- FONCTIONNALITÉ : corriger, enregistrer, certifier ----------
  /// [reponses] : id de la question → position du choix AFFICHÉ (0..3).
  /// Une question absente (temps écoulé) compte comme fausse.
  Future<ResultatTest> corriger({
    required int freelancerId,
    required Quiz quiz,
    required Map<int, int> reponses,
  }) async {
    if (quiz.questions.isEmpty) throw const TestException('Quiz vide.');
    if (reponses.values.any((r) => r < 0 || r > 3)) {
      throw const TestException('Réponse invalide.');
    }

    final db = await _db.database;
    final tentative = await db.query(
      'tentatives_test',
      where: 'id = ? AND freelancer_id = ?',
      whereArgs: [quiz.tentativeId, freelancerId],
    );
    if (tentative.isEmpty) throw const TestException('Test introuvable.');
    if (tentative.first['statut'] != 'en_cours') {
      throw const TestException('Ce test a déjà été corrigé.');
    }
    final ids = quiz.questions.map((q) => q.id).toList();
    final bonnes = await db.query(
      'test',
      columns: [
        'id',
        'bonne_reponse',
        'choix_a',
        'choix_b',
        'choix_c',
        'choix_d',
      ],
      where: 'id IN (${List.filled(ids.length, '?').join(', ')})',
      whereArgs: ids,
    );
    final parId = {for (final b in bonnes) b['id'] as int: b};

    final corrections = <CorrectionQuestion>[];
    final parDomaine = <String, ({int bonnes, int total})>{};
    var score = 0;
    final lignesReponses = <Map<String, Object?>>[];
    for (final q in quiz.questions) {
      final ligne = parId[q.id];
      if (ligne == null) throw const TestException('Question introuvable.');
      final textes = [
        ligne['choix_a'] as String,
        ligne['choix_b'] as String,
        ligne['choix_c'] as String,
        ligne['choix_d'] as String,
      ];
      final bonne = ligne['bonne_reponse'] as int;
      final affiche = reponses[q.id];
      final donnee = affiche == null ? null : q.indexOrigine(affiche);
      final ok = donnee == bonne;
      if (ok) score++;
      final avant = parDomaine[q.domaine] ?? (bonnes: 0, total: 0);
      parDomaine[q.domaine] = (
        bonnes: avant.bonnes + (ok ? 1 : 0),
        total: avant.total + 1,
      );
      corrections.add(
        CorrectionQuestion(
          question: q,
          reponseDonnee: donnee == null ? null : textes[donnee],
          bonneReponse: textes[bonne],
        ),
      );
      lignesReponses.add({
        'question_id': q.id,
        'choix': donnee,
        'correcte': ok ? 1 : 0,
      });
    }

    final total = quiz.questions.length;
    final pourcentage = (score * 100 / total).round();
    final reussi = pourcentage >= seuilReussite;
    final maintenant = DateTime.now().toIso8601String();

    final user = (await db.query(
      'users',
      columns: ['username', 'metier'],
      where: 'id = ?',
      whereArgs: [freelancerId],
    )).first;

    Certification? certification;
    final tentativeId = await db.transaction((txn) async {
      final id = quiz.tentativeId;
      // « AND statut » : deux corrections simultanées n'en valident qu'une
      final maj = await txn.update(
        'tentatives_test',
        {
          'score': score,
          'total': total,
          'pourcentage': pourcentage,
          'reussi': reussi ? 1 : 0,
          'date_tentative': maintenant,
          'statut': 'terminee',
        },
        where: "id = ? AND statut = 'en_cours'",
        whereArgs: [id],
      );
      if (maj != 1) throw const TestException('Ce test a déjà été corrigé.');
      for (final r in lignesReponses) {
        await txn.insert('reponses_test', {
          ...r,
          'tentative_id': id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (reussi) {
        final c = Certification(
          freelancerId: freelancerId,
          tentativeId: id,
          numero: genererNumero(),
          nomFreelancer: user['username'] as String,
          metier: user['metier'] as String?,
          domaines: quiz.domaines,
          competences: [
            for (final d in quiz.domaines)
              if (parDomaine[d] != null)
                '${PostOptions.categories[d]} '
                    '${parDomaine[d]!.bonnes}/${parDomaine[d]!.total}',
          ].join(' · '),
          score: score,
          total: total,
          pourcentage: pourcentage,
          mention: mention(pourcentage),
          dateObtention: maintenant,
        );
        final cid = await txn.insert('certifications', c.toMap());
        certification = Certification.fromMap({...c.toMap(), 'id': cid});
      }
      return id;
    });

    return ResultatTest(
      tentativeId: tentativeId,
      score: score,
      total: total,
      pourcentage: pourcentage,
      reussi: reussi,
      parDomaine: parDomaine,
      corrections: corrections,
      certification: certification,
      tentativesRestantes: (await etat(freelancerId)).restantes,
    );
  }

  Future<List<Certification>> getCertifications(int freelancerId) async {
    final db = await _db.database;
    final lignes = await db.query(
      'certifications',
      where: 'freelancer_id = ?',
      whereArgs: [freelancerId],
      orderBy: 'id DESC',
    );
    return lignes.map(Certification.fromMap).toList();
  }

  Future<List<TentativeTest>> getTentatives(int freelancerId) async {
    final db = await _db.database;
    final lignes = await db.query(
      'tentatives_test',
      where: 'freelancer_id = ?',
      whereArgs: [freelancerId],
      orderBy: 'id DESC',
    );
    return lignes.map(TentativeTest.fromMap).toList();
  }

  /// Domaines certifiés (meilleur pourcentage pour chacun) : pour le profil
  Future<Map<String, int>> domainesCertifies(int freelancerId) async {
    final meilleurs = <String, int>{};
    for (final c in await getCertifications(freelancerId)) {
      for (final d in c.domaines) {
        if ((meilleurs[d] ?? -1) < c.pourcentage) meilleurs[d] = c.pourcentage;
      }
    }
    return meilleurs;
  }

  static String mention(int pourcentage) => switch (pourcentage) {
    >= 90 => 'Excellent',
    >= 75 => 'Très bien',
    >= 60 => 'Bien',
    _ => 'Passable',
  };

  static final _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.split('');
  static final _secure = Random.secure();

  /// Numéro unique de certificat, ex : FRL-2026-7KQ2MX
  static String genererNumero() {
    final code = List.generate(
      6,
      (_) => _alphabet[_secure.nextInt(_alphabet.length)],
    ).join();
    return 'FRL-${DateTime.now().year}-$code';
  }
}
