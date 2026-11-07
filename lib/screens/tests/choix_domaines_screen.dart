import 'package:flutter/material.dart';

import '../../models/post_options.dart';
import '../../models/user.dart';
import '../../services/test_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/home_widgets.dart';
import 'quiz_screen.dart';
import 'tests_screen.dart' show PucesDomaines;

/// Étape 1 du test : choisir un ou plusieurs domaines.
/// Au 1er test, les domaines choisis sont ajoutés au profil du freelancer
/// et ne peuvent plus être changés : les tests suivants portent sur eux.
class ChoixDomainesScreen extends StatefulWidget {
  final User user;
  const ChoixDomainesScreen({super.key, required this.user});

  @override
  State<ChoixDomainesScreen> createState() => _ChoixDomainesScreenState();
}

class _ChoixDomainesScreenState extends State<ChoixDomainesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = TestService();
  Map<String, int> _disponibles = {};
  List<String> _fixes = const []; // domaines déjà sur le profil
  List<String> _domaines = [];
  bool _chargement = true;
  bool _loading = false;

  bool get _verrouille => _fixes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final d = await _service.domainesDisponibles();
    final f = await _service.domainesProfil(widget.user.id!);
    if (!mounted) return;
    setState(() {
      _disponibles = d;
      _fixes = f;
      _chargement = false;
    });
  }

  String _noms(List<String> d) =>
      d.map((x) => PostOptions.categories[x] ?? x).join(', ');

  // ---------- FONCTIONNALITÉ : lancer le test ----------
  Future<void> _commencer() async {
    final List<String> domaines;
    if (_verrouille) {
      domaines = _fixes;
    } else {
      if (!_formKey.currentState!.validate()) return;
      domaines = _domaines;
      if (!await _confirmerDomaines(domaines)) return;
    }
    setState(() => _loading = true);
    try {
      final quiz = await _service.genererQuiz(widget.user.id!, domaines);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizScreen(user: widget.user, quiz: quiz),
        ),
      );
    } on TestException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Avertit que le choix est définitif
  Future<bool> _confirmerDomaines(List<String> domaines) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Choix définitif'),
        content: Text(
          '${_noms(domaines)} ${domaines.length > 1 ? 'seront ajoutés' : 'sera ajouté'} '
          'à ton profil. Tu ne pourras plus changer tes domaines : tous tes '
          'tests porteront sur eux.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Modifier'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Confirmer',
              style: TextStyle(color: AppColors.cyan),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final options = {
      for (final d in _disponibles.keys) d: PostOptions.categories[d]!,
    };
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Nouveau test',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: AppColors.red))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _verrouille
                            ? 'Tes domaines'
                            : 'Quels sont tes\ndomaines ?',
                        style: const TextStyle(
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _verrouille
                            ? 'Ils sont fixés sur ton profil : le test porte '
                                  'sur ces domaines.'
                            : 'Choisis un ou plusieurs domaines. Attention : '
                                  'ils seront ajoutés à ton profil et ne '
                                  'pourront plus être changés.',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_verrouille)
                        PucesDomaines(domaines: _fixes)
                      else
                        MultiChoiceChipsField(
                          label: 'Domaines du test',
                          options: options,
                          icones: iconesCategories,
                          max: options.length,
                          initialValue: _domaines,
                          validator: TestService.validerDomaines,
                          onChanged: (v) => _domaines = v,
                        ),
                      const SizedBox(height: 24),
                      const _Regle(
                        Icons.quiz_outlined,
                        '${TestService.nbQuestions} questions à choix multiple',
                      ),
                      const _Regle(
                        Icons.timer_outlined,
                        'Chaque question a son chronomètre (20 à 60 s). Temps '
                        'écoulé : la question compte comme fausse',
                      ),
                      const _Regle(
                        Icons.block_rounded,
                        'Pas de retour aux questions précédentes',
                      ),
                      const _Regle(
                        Icons.workspace_premium_outlined,
                        'Au moins ${TestService.seuilReussite} % de bonnes '
                        'réponses : tu obtiens une certification « freelance » '
                        'et tu peux postuler aux missions (le test ne se '
                        'repasse pas)',
                      ),
                      const _Regle(
                        Icons.replay_rounded,
                        '${TestService.tentativesMax} tentatives au maximum, '
                        'avec de nouvelles questions à chaque fois. Un test '
                        'commencé compte, même abandonné',
                      ),
                      const _Regle(
                        Icons.auto_awesome_rounded,
                        "À la fin, l'IA analyse tes réponses : points forts, "
                        'points à améliorer et conseils',
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: 'Commencer le test',
                        loading: _loading,
                        onPressed: _commencer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _Regle extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _Regle(this.icone, this.texte);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: AppColors.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.label,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
