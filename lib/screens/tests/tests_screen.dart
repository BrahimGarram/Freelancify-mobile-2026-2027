import 'package:flutter/material.dart';

import '../../models/post_options.dart';
import '../../models/test_competences.dart';
import '../../models/user.dart';
import '../../services/test_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/home_widgets.dart';
import 'certificat_screen.dart';
import 'choix_domaines_screen.dart';
import 'rapport_ia_carte.dart';

/// « Tests et certifications » du freelancer : passer un test, voir ses
/// certifications et l'historique de ses tests.
class TestsScreen extends StatefulWidget {
  final User user;
  const TestsScreen({super.key, required this.user});

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  final _service = TestService();
  List<Certification> _certifications = [];
  List<TentativeTest> _tentatives = [];
  List<String> _domaines = [];
  EtatTests? _etat;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final c = await _service.getCertifications(widget.user.id!);
    final t = await _service.getTentatives(widget.user.id!);
    final d = await _service.domainesProfil(widget.user.id!);
    final e = await _service.etat(widget.user.id!);
    if (mounted) {
      setState(() {
        _etat = e;
        _certifications = c;
        _tentatives = t;
        _domaines = d;
        _loading = false;
      });
    }
  }

  Future<void> _nouveauTest() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChoixDomainesScreen(user: widget.user)),
    );
    _charger(); // un test a pu être passé
  }

  /// Historique : le rapport de l'IA d'un test passé
  void _voirRapport(TentativeTest t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              '${t.domaines.map((d) => PostOptions.categories[d] ?? d).join(', ')}'
              ' · ${t.score}/${t.total}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${t.reussi ? 'Réussi' : 'Échoué'} · '
              '${formatDate(DateTime.parse(t.date))}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            RapportIaCarte(tentativeId: t.id, freelancerId: widget.user.id!),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Tests et certifications',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.red))
          : RefreshIndicator(
              color: AppColors.red,
              backgroundColor: AppColors.surface,
              onRefresh: _charger,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0x5925F4EE)),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x1A25F4EE), Color(0x14EE1D52)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 34,
                          color: Color(0xFFE9C46A),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Prouve tes compétences',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '${TestService.nbQuestions} questions dans tes '
                          'domaines. Avec au moins ${TestService.seuilReussite} %, '
                          'tu obtiens une certification « freelance » affichée '
                          'sur ton profil.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _ActionTest(etat: _etat!, onPasser: _nouveauTest),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  _Titre('Mes domaines', _domaines.length),
                  if (_domaines.isEmpty)
                    const Text(
                      'Tu les choisiras au début de ton premier test. Ils '
                      'seront ajoutés à ton profil, sans pouvoir les changer.',
                      style: TextStyle(color: AppColors.textMuted, height: 1.4),
                    )
                  else
                    PucesDomaines(domaines: _domaines),
                  const SizedBox(height: 26),
                  _Titre('Mes certifications', _certifications.length),
                  if (_certifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Aucune certification pour le moment.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    for (final c in _certifications)
                      CarteCertificationResume(
                        certification: c,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CertificatScreen(
                              certification: c,
                              afficherRapport: true,
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 20),
                  _Titre('Historique', _tentatives.length),
                  if (_tentatives.isEmpty)
                    const Text(
                      'Aucun test passé.',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else
                    for (final t in _tentatives)
                      _LigneTentative(
                        tentative: t,
                        onTap: t.enCours ? null : () => _voirRapport(t),
                      ),
                ],
              ),
            ),
    );
  }
}

class _Titre extends StatelessWidget {
  final String texte;
  final int nombre;
  const _Titre(this.texte, this.nombre);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Text(
          texte,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Text(
          '$nombre',
          style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}

/// Les domaines du freelancer, fixés sur son profil (cadenas)
class PucesDomaines extends StatelessWidget {
  final List<String> domaines;
  const PucesDomaines({super.key, required this.domaines});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in domaines)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x1A25F4EE),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0x5925F4EE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconesCategories[d] ?? Icons.more_horiz_rounded,
                  size: 16,
                  color: AppColors.cyan,
                ),
                const SizedBox(width: 6),
                Text(
                  PostOptions.categories[d] ?? d,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Résumé d'une certification (liste des tests, profil public)
class CarteCertificationResume extends StatelessWidget {
  final Certification certification;
  final VoidCallback? onTap;
  const CarteCertificationResume({
    super.key,
    required this.certification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = certification;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x66E9C46A)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFE9C46A),
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Certifié ${c.domainesLisibles}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.pourcentage} % · ${c.mention} · '
                        '${formatDate(DateTime.parse(c.dateObtention))}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le bouton « Passer un test », ou pourquoi on ne peut plus le passer
class _ActionTest extends StatelessWidget {
  final EtatTests etat;
  final VoidCallback onPasser;
  const _ActionTest({required this.etat, required this.onPasser});

  @override
  Widget build(BuildContext context) {
    if (etat.peutPasser) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(label: 'Passer un test', onPressed: onPasser),
          const SizedBox(height: 8),
          Text(
            'Tentatives : ${etat.utilisees} / ${etat.max} utilisée'
            '${etat.utilisees > 1 ? 's' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      );
    }
    final (icone, couleur, texte) = etat.certifie
        ? (
            Icons.verified_rounded,
            AppColors.cyan,
            'Test réussi : tu es certifié et tu peux postuler aux missions. '
                'Le test ne se repasse pas.',
          )
        : (
            Icons.block_rounded,
            AppColors.error,
            'Tu as utilisé tes ${etat.max} tentatives : tu ne peux plus '
                'passer le test.',
          );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icone, color: couleur, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneTentative extends StatelessWidget {
  final TentativeTest tentative;
  final VoidCallback? onTap; // voir le rapport de l'IA
  const _LigneTentative({required this.tentative, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = tentative;
    final domaines = t.domaines
        .map((d) => PostOptions.categories[d] ?? d)
        .join(', ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              t.enCours
                  ? Icons.do_not_disturb_on_outlined
                  : (t.reussi
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded),
              size: 20,
              color: t.enCours
                  ? AppColors.textMuted
                  : (t.reussi ? AppColors.cyan : AppColors.error),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                domaines,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Text(
              t.enCours
                  ? 'Abandonné · ${tempsEcoule(t.date)}'
                  : '${t.score}/${t.total} · ${tempsEcoule(t.date)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: Color(0xFFB794F6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
