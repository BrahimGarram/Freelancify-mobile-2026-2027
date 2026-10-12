import 'dart:async';

import 'package:flutter/material.dart';

// Même import que dans missions_list_page.dart (adaptez le chemin si besoin).
import '../LoginPage.dart' show AppColors;

/// Une question du test (statique pour le moment).
class TestQuestion {
  const TestQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
  });

  final String text;
  final List<String> options;
  final int correctIndex;
}

const _questions = <TestQuestion>[
  TestQuestion(
    text: 'Quel widget permet d\'afficher des éléments les uns sous les autres ?',
    options: ['Row', 'Column', 'Stack', 'Container'],
    correctIndex: 1,
  ),
  TestQuestion(
    text: 'Quelle méthode permet de mettre à jour l\'interface d\'un StatefulWidget ?',
    options: ['setState()', 'build()', 'initState()', 'dispose()'],
    correctIndex: 0,
  ),
  TestQuestion(
    text: 'Quel langage est utilisé pour développer avec Flutter ?',
    options: ['Kotlin', 'Swift', 'Dart', 'JavaScript'],
    correctIndex: 2,
  ),
  TestQuestion(
    text: 'Quel widget permet de faire défiler efficacement une longue liste ?',
    options: ['ListView.builder', 'Column', 'Row', 'Padding'],
    correctIndex: 0,
  ),
  TestQuestion(
    text: 'Dans quel fichier déclare-t-on les dépendances d\'un projet Flutter ?',
    options: ['main.dart', 'pubspec.yaml', 'build.gradle', 'README.md'],
    correctIndex: 1,
  ),
];

class SkillTestPage extends StatefulWidget {
  const SkillTestPage({super.key});

  @override
  State<SkillTestPage> createState() => _SkillTestPageState();
}

class _SkillTestPageState extends State<SkillTestPage> {
  /// Durée totale du test : 5 minutes.
  static const _totalSeconds = 5 * 60;

  int _current = 0;
  late List<int?> _answers;
  int _secondsLeft = _totalSeconds;
  bool _finished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _answers = List<int?>.filled(_questions.length, null);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- Logique

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) _finish();
    });
  }

  void _select(int index) {
    setState(() => _answers[_current] = index);
  }

  void _next() {
    if (_answers[_current] == null) return;
    if (_current == _questions.length - 1) {
      _finish();
    } else {
      setState(() => _current++);
    }
  }

  void _finish() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _secondsLeft = _secondsLeft < 0 ? 0 : _secondsLeft;
      _finished = true;
    });
  }

  void _restart() {
    setState(() {
      _current = 0;
      _answers = List<int?>.filled(_questions.length, null);
      _secondsLeft = _totalSeconds;
      _finished = false;
    });
    _startTimer();
  }

  int get _score {
    var score = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i].correctIndex) score++;
    }
    return score;
  }

  int get _answeredCount => _answers.where((a) => a != null).length;

  String _formatTime(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  Future<void> _confirmExit() async {
    if (_finished) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Quitter le test ?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Votre progression sera perdue.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Continuer',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Quitter',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ Build

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _finished ? _buildResultBar() : _buildQuestionBar(),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // Bandeau bleu acier
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + (_finished ? 200 : 230),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _BackButton(onTap: _confirmExit),
                        if (!_finished)
                          _TimerPill(
                            label: _formatTime(_secondsLeft),
                            low: _secondsLeft <= 60,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _finished ? 'Résultat du test' : 'Test de compétences',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _finished
                          ? 'Test Flutter terminé'
                          : 'Flutter · ${_questions.length} questions',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFFD6E4EB),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _finished ? _buildResultCard() : _buildQuestionCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- Question

  Widget _buildQuestionCard() {
    final question = _questions[_current];
    final selected = _answers[_current];
    final total = _questions.length;
    final progress = (_current + 1) / total;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_current + 1} sur $total',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label,
                ),
              ),
              Text(
                '${(progress * 100).round()} %',
                style: const TextStyle(fontSize: 13, color: AppColors.hint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.fieldFill,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 19,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OptionTile(
                letter: String.fromCharCode(65 + i),
                text: question.options[i],
                selected: selected == i,
                onTap: () => _select(i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionBar() {
    final isLast = _current == _questions.length - 1;
    final answered = _answers[_current] != null;

    return _BottomBar(
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: answered ? _next : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.35),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          child: Text(isLast ? 'TERMINER' : 'SUIVANT'),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- Résultat

  Widget _buildResultCard() {
    final total = _questions.length;
    final percent = _score / total;

    String title;
    String message;
    if (percent >= 0.8) {
      title = 'Excellent travail !';
      message = 'Vous maîtrisez très bien les bases de Flutter.';
    } else if (percent >= 0.5) {
      title = 'Bon résultat';
      message = 'Il vous reste quelques notions à revoir.';
    } else {
      title = 'Continuez à vous entraîner';
      message = 'Révisez les bases puis retentez le test.';
    }

    return _Card(
      child: Column(
        children: [
          const SizedBox(height: 6),
          SizedBox(
            width: 128,
            height: 128,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 10,
                  backgroundColor: AppColors.primaryLight,
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_score/$total',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${(percent * 100).round()} %',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          _StatRow(
            icon: Icons.check_circle_outline,
            label: 'Bonnes réponses',
            value: '$_score / $total',
          ),
          _StatRow(
            icon: Icons.timer_outlined,
            label: 'Temps utilisé',
            value: _formatTime(_totalSeconds - _secondsLeft),
          ),
          _StatRow(
            icon: Icons.help_outline,
            label: 'Sans réponse',
            value: '${total - _answeredCount}',
          ),
        ],
      ),
    );
  }

  Widget _buildResultBar() {
    return _BottomBar(
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: _restart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                child: const Text('REFAIRE'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                // Renvoie le score à la page précédente.
                onPressed: () => Navigator.of(context).pop(_score),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                child: const Text('TERMINER'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================ Widgets

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Minuteur : devient rouge pendant la dernière minute.
class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.label, required this.low});

  final String label;
  final bool low;

  @override
  Widget build(BuildContext context) {
    final foreground = low ? AppColors.error : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: low ? const Color(0xFFFEE2E2) : Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 19, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: foreground,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Une réponse possible (A, B, C, D).
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.fieldFill,
                shape: BoxShape.circle,
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14.5, color: AppColors.label),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre fixe en bas de l'écran (boutons).
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: child,
        ),
      ),
    );
  }
}