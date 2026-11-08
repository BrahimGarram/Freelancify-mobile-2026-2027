import 'package:flutter/material.dart';

import '../../models/post_options.dart';
import '../../models/test_competences.dart';
import '../../models/user.dart';
import '../../services/test_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'certificat_screen.dart';
import 'demande_tentative_screen.dart';
import 'quiz_screen.dart';
import 'rapport_ia_carte.dart';

/// Résultat du test : score, détail par domaine, correction.
/// Réussi → voir la certification ; échoué → refaire un test (nouvelles
/// questions).
class ResultatScreen extends StatefulWidget {
  final User user;
  final ResultatTest resultat;
  final List<String> domaines;

  const ResultatScreen({
    super.key,
    required this.user,
    required this.resultat,
    required this.domaines,
  });

  @override
  State<ResultatScreen> createState() => _ResultatScreenState();
}

class _ResultatScreenState extends State<ResultatScreen> {
  bool _loading = false;

  // ---------- FONCTIONNALITÉ : refaire un test (autres questions) ----------
  Future<void> _refaire() async {
    setState(() => _loading = true);
    try {
      final quiz = await TestService().genererQuiz(
        widget.user.id!,
        widget.domaines,
      );
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

  // ---------- FONCTIONNALITÉ : tentative supplémentaire ----------
  Future<void> _demander() async {
    final accorde = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DemandeTentativeScreen(
          user: widget.user,
          domaines: widget.domaines,
        ),
      ),
    );
    // retour à l'espace des tests, où le bouton « Passer un test » est revenu
    if (accorde == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resultat;
    final couleur = r.reussi ? AppColors.cyan : AppColors.red;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Résultat',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: r.pourcentage / 100,
                      strokeWidth: 10,
                      color: couleur,
                      backgroundColor: AppColors.fieldBorder,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${r.pourcentage} %',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${r.score} / ${r.total}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              r.reussi ? 'Bravo, test réussi ! 🎉' : 'Pas encore…',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              r.reussi
                  ? 'Tu obtiens une certification « freelance » '
                        '(mention ${r.certification?.mention}). Elle est '
                        'visible sur ton profil public.'
                  : r.tentativesRestantes > 0
                  ? 'Il faut au moins ${TestService.seuilReussite} % pour '
                        'être certifié. Il te reste ${r.tentativesRestantes} '
                        'tentative${r.tentativesRestantes > 1 ? 's' : ''}, '
                        'avec de nouvelles questions.'
                  : r.peutDemanderTentative
                  ? 'Il fallait au moins ${TestService.seuilReussite} %. Tu as '
                        'utilisé tes ${r.tentativesTotal} tentatives, mais tu '
                        'peux en demander une de plus.'
                  : 'Il fallait au moins ${TestService.seuilReussite} %. Tu as '
                        'utilisé tes ${r.tentativesTotal} tentatives : '
                        'tu ne peux plus passer le test.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            if (r.reussi && r.certification != null)
              PrimaryButton(
                label: 'Voir ma certification',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CertificatScreen(
                      certification: r.certification!,
                      afficherRapport: true,
                    ),
                  ),
                ),
              )
            else if (r.tentativesRestantes > 0)
              PrimaryButton(
                label:
                    'Refaire un test (${r.tentativesRestantes} restante'
                    '${r.tentativesRestantes > 1 ? 's' : ''})',
                loading: _loading,
                onPressed: _refaire,
              )
            else if (r.peutDemanderTentative)
              PrimaryButton(
                label: 'Demander une tentative',
                onPressed: _demander,
              ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Retour aux tests'),
              ),
            ),
            const SizedBox(height: 14),
            // analyse personnalisée de l'IA (demandée tout de suite)
            RapportIaCarte(
              tentativeId: r.tentativeId,
              freelancerId: widget.user.id!,
              generationAuto: true,
            ),
            const SizedBox(height: 22),
            const _Titre('Par domaine'),
            for (final e in r.parDomaine.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            PostOptions.categories[e.key] ?? e.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${e.value.bonnes} / ${e.value.total}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: e.value.bonnes / e.value.total,
                        minHeight: 6,
                        color: AppColors.cyan,
                        backgroundColor: AppColors.fieldBorder,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            const _Titre('Correction'),
            for (var i = 0; i < r.corrections.length; i++)
              _Correction(numero: i + 1, correction: r.corrections[i]),
          ],
        ),
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  final String texte;
  const _Titre(this.texte);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      texte,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
}

class _Correction extends StatelessWidget {
  final int numero;
  final CorrectionQuestion correction;
  const _Correction({required this.numero, required this.correction});

  @override
  Widget build(BuildContext context) {
    final c = correction;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.correcte ? const Color(0x5925F4EE) : const Color(0x59FF6B8A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                c.correcte ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 20,
                color: c.correcte ? AppColors.cyan : AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$numero. ${c.question.enonce}',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!c.correcte)
            Text(
              c.sansReponse
                  ? 'Temps écoulé : pas de réponse'
                  : 'Ta réponse : ${c.reponseDonnee}',
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          Text(
            'Bonne réponse : ${c.bonneReponse}',
            style: const TextStyle(fontSize: 13, color: AppColors.cyan),
          ),
        ],
      ),
    );
  }
}
