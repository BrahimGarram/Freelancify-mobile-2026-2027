import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/post_options.dart';
import '../../models/test_competences.dart';
import '../../models/user.dart';
import '../../services/test_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/home_widgets.dart';
import 'resultat_screen.dart';

/// Le quiz : une question par écran, 4 choix, et un chronomètre par
/// question. Pas de retour en arrière : quand le temps est écoulé, la
/// question compte comme fausse et on passe automatiquement à la suivante.
class QuizScreen extends StatefulWidget {
  final User user;
  final Quiz quiz;
  final TestService? service; // remplaçable dans les tests

  const QuizScreen({
    super.key,
    required this.user,
    required this.quiz,
    this.service,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

/// État d'une question dans les pastilles du haut
enum _Etat { aVenir, enCours, repondue, tempsEcoule }

class _QuizScreenState extends State<QuizScreen> {
  late final TestService _service = widget.service ?? TestService();
  final Map<int, int> _reponses = {}; // id question → choix affiché
  final Set<int> _expirees = {}; // questions dont le temps est écoulé
  int _index = 0;
  bool _envoi = false;

  Timer? _chrono;
  late int _restant; // secondes restantes pour la question en cours

  List<QuestionQuiz> get _questions => widget.quiz.questions;
  QuestionQuiz get _question => _questions[_index];
  bool get _derniere => _index == _questions.length - 1;

  @override
  void initState() {
    super.initState();
    _demarrerChrono();
  }

  @override
  void dispose() {
    _chrono?.cancel();
    super.dispose();
  }

  // ---------- FONCTIONNALITÉ : chronomètre de chaque question ----------
  void _demarrerChrono() {
    _chrono?.cancel();
    _restant = _question.duree;
    _chrono = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _envoi) return;
      setState(() => _restant--);
      if (_restant <= 0) _tempsEcoule();
    });
  }

  void _tempsEcoule() {
    _chrono?.cancel();
    final q = _question;
    // la réponse cochée avant la fin du temps reste valable
    if (!_reponses.containsKey(q.id)) {
      _expirees.add(q.id);
      showAppMessage(
        context,
        'Temps écoulé pour la question ${_index + 1}',
        error: true,
      );
    }
    _suivante();
  }

  /// Valide la question en cours et passe à la suivante (ou termine)
  void _suivante() {
    if (_derniere) {
      _terminer();
      return;
    }
    setState(() => _index++);
    _demarrerChrono();
  }

  void _valider() {
    if (!_reponses.containsKey(_question.id)) {
      showAppMessage(context, 'Choisis une réponse', error: true);
      return;
    }
    _suivante();
  }

  // ---------- FONCTIONNALITÉ : terminer et corriger ----------
  Future<void> _terminer() async {
    if (_envoi) return;
    _chrono?.cancel();
    setState(() => _envoi = true);
    try {
      final resultat = await _service.corriger(
        freelancerId: widget.user.id!,
        quiz: widget.quiz,
        reponses: _reponses,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultatScreen(
            user: widget.user,
            resultat: resultat,
            domaines: widget.quiz.domaines,
          ),
        ),
      );
    } on TestException catch (e) {
      if (mounted) {
        showAppMessage(context, e.message, error: true);
        setState(() => _envoi = false);
      }
    }
  }

  Future<bool> _confirmerAbandon() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Abandonner le test ?'),
        content: const Text(
          'Ce test comptera comme une tentative échouée. Le chronomètre '
          'continue pendant ce message.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer le test'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Abandonner',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  _Etat _etat(int i) {
    if (i == _index) return _Etat.enCours;
    if (i > _index) return _Etat.aVenir;
    return _expirees.contains(_questions[i].id)
        ? _Etat.tempsEcoule
        : _Etat.repondue;
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    final choisi = _reponses[q.id];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmerAbandon() && context.mounted) {
          _chrono?.cancel();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Abandonner',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Question ${_index + 1} / ${_questions.length}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _Chrono(restant: _restant, total: q.duree),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // temps restant pour cette question
              LinearProgressIndicator(
                value: (_restant / q.duree).clamp(0.0, 1.0),
                minHeight: 4,
                color: _restant <= 5 ? AppColors.error : AppColors.cyan,
                backgroundColor: AppColors.fieldBorder,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < _questions.length; i++)
                      _Pastille(numero: i + 1, etat: _etat(i)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            iconesCategories[q.domaine] ??
                                Icons.more_horiz_rounded,
                            size: 16,
                            color: AppColors.cyan,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${PostOptions.categories[q.domaine] ?? q.domaine}'
                              ' · ${q.duree} s',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        q.enonce,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (var i = 0; i < q.choix.length; i++)
                        _Choix(
                          lettre: String.fromCharCode(65 + i), // A, B, C, D
                          texte: q.choix[i],
                          selectionne: choisi == i,
                          onTap: _envoi
                              ? null
                              : () => setState(() => _reponses[q.id] = i),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: PrimaryButton(
                  label: _derniere ? 'Terminer le test' : 'Suivante',
                  loading: _envoi,
                  onPressed: _valider,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le chronomètre (secondes restantes), rouge dans les 5 dernières secondes
class _Chrono extends StatelessWidget {
  final int restant;
  final int total;
  const _Chrono({required this.restant, required this.total});

  @override
  Widget build(BuildContext context) {
    final urgent = restant <= 5;
    final couleur = urgent ? AppColors.error : AppColors.cyan;
    return Semantics(
      label: '$restant secondes restantes',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: urgent ? const Color(0x26FF6B8A) : const Color(0x1A25F4EE),
          border: Border.all(color: couleur),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 16, color: couleur),
            const SizedBox(width: 4),
            Text(
              '${restant.clamp(0, total)} s',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: couleur,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  final int numero;
  final _Etat etat;
  const _Pastille({required this.numero, required this.etat});

  @override
  Widget build(BuildContext context) {
    final (fond, bord, texte) = switch (etat) {
      _Etat.enCours => (
        AppColors.fieldFill,
        AppColors.red,
        AppColors.textPrimary,
      ),
      _Etat.repondue => (
        const Color(0x3325F4EE),
        AppColors.cyan,
        AppColors.cyan,
      ),
      _Etat.tempsEcoule => (
        const Color(0x26FF6B8A),
        AppColors.error,
        AppColors.error,
      ),
      _Etat.aVenir => (
        AppColors.fieldFill,
        AppColors.fieldBorder,
        AppColors.textMuted,
      ),
    };
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fond,
        border: Border.all(color: bord, width: etat == _Etat.enCours ? 2 : 1),
      ),
      child: etat == _Etat.tempsEcoule
          ? const Icon(
              Icons.timer_off_outlined,
              size: 14,
              color: AppColors.error,
            )
          : Text(
              '$numero',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: texte,
              ),
            ),
    );
  }
}

class _Choix extends StatelessWidget {
  final String lettre;
  final String texte;
  final bool selectionne;
  final VoidCallback? onTap;
  const _Choix({
    required this.lettre,
    required this.texte,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selectionne,
        button: true,
        child: Material(
          color: selectionne ? const Color(0x1A25F4EE) : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selectionne ? AppColors.cyan : AppColors.fieldBorder,
              width: selectionne ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selectionne ? AppColors.cyan : AppColors.fieldFill,
                    ),
                    child: Text(
                      lettre,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: selectionne ? Colors.black : AppColors.label,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      texte,
                      style: const TextStyle(fontSize: 15, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
