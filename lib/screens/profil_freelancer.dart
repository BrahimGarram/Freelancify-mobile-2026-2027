import 'package:flutter/material.dart';

import '../models/realisation.dart';
import '../models/test_competences.dart';
import '../models/user.dart';
import '../services/realisation_service.dart';
import '../services/test_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/realisation_widgets.dart';
import 'freelancer/publier_realisation.dart';
import 'tests/certificat_screen.dart';
import 'tests/tests_screen.dart';

/// Ouvre la page de profil d'un freelancer.
Future<void> ouvrirProfilFreelancer(
  BuildContext context, {
  required int freelancerId,
  required User viewer,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          ProfilFreelancerScreen(freelancerId: freelancerId, viewer: viewer),
    ),
  );
}

/// Profil public d'un freelancer : métier, bio, stats et portfolio.
/// Si [viewer] est le freelancer lui-même, il peut ajouter / supprimer
/// ses réalisations.
class ProfilFreelancerScreen extends StatefulWidget {
  final int freelancerId;
  final User viewer; // la personne qui regarde la page

  const ProfilFreelancerScreen({
    super.key,
    required this.freelancerId,
    required this.viewer,
  });

  @override
  State<ProfilFreelancerScreen> createState() => _ProfilFreelancerScreenState();
}

class _ProfilFreelancerScreenState extends State<ProfilFreelancerScreen> {
  final _userService = UserService();
  final _realisationService = RealisationService();

  User? _freelancer;
  List<Realisation> _realisations = [];
  int _nbMissions = 0;
  List<Certification> _certifications = [];
  bool _loading = true;

  bool get _estMoi => widget.viewer.id == widget.freelancerId;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final f = await _userService.getUserById(widget.freelancerId);
      final r = await _realisationService.getByFreelancer(widget.freelancerId);
      final n = await _realisationService.nbMissionsAcceptees(
        widget.freelancerId,
      );
      final c = await TestService().getCertifications(widget.freelancerId);
      if (!mounted) return;
      setState(() {
        _freelancer = f;
        _realisations = r;
        _nbMissions = n;
        _certifications = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppMessage(context, 'Erreur : $e', error: true);
    }
  }

  Future<void> _ajouter() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PublierRealisationScreen(user: widget.viewer),
      ),
    );
    if (ok == true) _charger();
  }

  Future<void> _supprimer(Realisation r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Supprimer cette réalisation ?'),
        content: Text(
          '« ${r.titre} » sera retirée de ton portfolio.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _realisationService.supprimer(r, widget.viewer.id!);
    if (!mounted) return;
    showAppMessage(context, 'Réalisation supprimée');
    _charger();
  }

  /// Certifications obtenues aux tests (visibles par les clients)
  List<Widget> _buildCertifications() {
    if (_certifications.isEmpty && !_estMoi) return const [];
    return [
      Row(
        children: [
          const Text(
            'Certifications',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Text(
            '${_certifications.length}',
            style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_certifications.isEmpty)
        // le freelancer regarde son propre profil : on l'invite à passer un test
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TestsScreen(user: widget.viewer),
              ),
            );
            _charger();
          },
          icon: const Icon(Icons.workspace_premium_outlined, size: 18),
          label: const Text('Passer un test pour être certifié'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE9C46A),
            side: const BorderSide(color: Color(0x66E9C46A)),
            shape: const StadiumBorder(),
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
                  afficherRapport: _estMoi, // le rapport reste privé
                ),
              ),
            ),
          ),
      const SizedBox(height: 24),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final f = _freelancer;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _estMoi ? 'Mon profil public' : 'Profil',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: _estMoi && !_loading
          ? FloatingActionButton.extended(
              onPressed: _ajouter,
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Ajouter',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.red))
          : f == null || !f.isFreelancer
          ? const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Profil introuvable',
              message: "Ce freelancer n'existe plus.",
            )
          : RefreshIndicator(
              color: AppColors.red,
              backgroundColor: AppColors.surface,
              onRefresh: _charger,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  _buildEnTete(f),
                  const SizedBox(height: 24),
                  ..._buildCertifications(),
                  Row(
                    children: [
                      const Text(
                        'Portfolio',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_realisations.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_realisations.isEmpty)
                    EmptyState(
                      icon: Icons.photo_library_outlined,
                      title: 'Aucune réalisation',
                      message: _estMoi
                          ? 'Ajoute tes projets, expériences ou sites réalisés '
                                'pour convaincre les clients.'
                          : "Ce freelancer n'a encore rien publié.",
                    )
                  else
                    for (final r in _realisations)
                      RealisationCard(
                        realisation: r,
                        onDelete: _estMoi ? () => _supprimer(r) : null,
                      ),
                ],
              ),
            ),
    );
  }

  Widget _buildEnTete(User f) {
    return Column(
      children: [
        UserAvatar(name: f.username, isClient: false, size: 88),
        const SizedBox(height: 14),
        Text(
          '@${f.username}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          f.metier ?? 'Freelancer',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.cyan,
          ),
        ),
        if (f.domaines.isNotEmpty) ...[
          const SizedBox(height: 12),
          Center(child: PucesDomaines(domaines: f.domaines)),
        ],
        const SizedBox(height: 14),
        if (f.bio != null)
          Text(
            f.bio!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          )
        else if (_estMoi)
          const Text(
            'Ajoute une bio et ton métier depuis Profil › Modifier le profil.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: StatCard(
                value: '${_realisations.length}',
                label: 'Réalisations',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                value: '$_nbMissions',
                label: 'Missions acceptées',
                valueColor: AppColors.cyan,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
