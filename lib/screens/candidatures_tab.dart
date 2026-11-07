import 'package:flutter/material.dart';

import '../models/candidature.dart';
import '../models/user.dart';
import '../services/candidature_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/home_widgets.dart';
import 'messages/chat_screen.dart';
import 'profil_freelancer.dart';

/// Onglet « Candidatures » :
/// - Client : les candidatures reçues (lire le message, accepter, refuser,
///   discuter) ;
/// - Freelancer : ses candidatures envoyées (statut, discuter).
class CandidaturesTab extends StatefulWidget {
  final User user;

  /// Appelé quand quelque chose a changé (lecture, décision…)
  final VoidCallback? onChanged;

  const CandidaturesTab({super.key, required this.user, this.onChanged});

  @override
  State<CandidaturesTab> createState() => _CandidaturesTabState();
}

class _CandidaturesTabState extends State<CandidaturesTab> {
  final _service = CandidatureService();
  List<Candidature> _candidatures = [];
  bool _loading = true;

  bool get _isClient => widget.user.role == 'client';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final liste = _isClient
          ? await _service.getCandidaturesByClient(widget.user.id!)
          : await _service.getCandidaturesByFreelancer(widget.user.id!);
      if (!mounted) return;
      setState(() {
        _candidatures = liste;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppMessage(context, 'Erreur : $e', error: true);
    }
  }

  Future<void> _discuter(Candidature c) async {
    await ouvrirDiscussion(context, widget.user, c.id!);
    widget.onChanged?.call();
    _charger();
  }

  // ---------- FONCTIONNALITÉ : accepter / refuser (client) ----------
  Future<void> _decider(Candidature c, bool accepter) async {
    final ok = await confirmerDecision(
      context,
      accepter: accepter,
      freelancer: c.freelancerUsername ?? 'freelancer',
    );
    if (!ok) return;
    try {
      if (accepter) {
        await _service.accepterCandidature(c.id!);
      } else {
        await _service.refuserCandidature(c.id!);
      }
      if (!mounted) return;
      showAppMessage(
        context,
        accepter ? 'Candidature acceptée' : 'Candidature refusée',
      );
      widget.onChanged?.call();
      _charger();
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nbAttente = _candidatures
        .where((c) => c.statut == 'en_attente')
        .length;
    final nbAcceptees = _candidatures
        .where((c) => c.statut == 'acceptee')
        .length;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.red,
        backgroundColor: AppColors.surface,
        onRefresh: _charger,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            HomeHeader(
              user: widget.user,
              title: _isClient ? 'Candidatures' : 'Mes candidatures',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StatCard(value: '$nbAttente', label: 'En attente'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    value: '$nbAcceptees',
                    label: 'Acceptées',
                    valueColor: AppColors.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.red),
                ),
              )
            else if (_candidatures.isEmpty)
              EmptyState(
                icon: _isClient
                    ? Icons.people_outline_rounded
                    : Icons.send_outlined,
                title: 'Aucune candidature',
                message: _isClient
                    ? 'Les freelancers qui postulent à tes posts apparaîtront ici.'
                    : 'Postule à une mission depuis l\'onglet Missions.',
              )
            else
              for (final c in _candidatures)
                _CandidatureCard(
                  candidature: c,
                  isClient: _isClient,
                  onDiscuter: () => _discuter(c),
                  onAccepter: () => _decider(c, true),
                  onRefuser: () => _decider(c, false),
                  onVoirProfil: _isClient
                      ? () => ouvrirProfilFreelancer(
                          context,
                          freelancerId: c.freelancerId,
                          viewer: widget.user,
                        )
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}

class _CandidatureCard extends StatefulWidget {
  final Candidature candidature;
  final bool isClient;
  final VoidCallback onDiscuter;
  final VoidCallback onAccepter;
  final VoidCallback onRefuser;
  final VoidCallback? onVoirProfil; // client → profil du freelancer

  const _CandidatureCard({
    this.onVoirProfil,
    required this.candidature,
    required this.isClient,
    required this.onDiscuter,
    required this.onAccepter,
    required this.onRefuser,
  });

  @override
  State<_CandidatureCard> createState() => _CandidatureCardState();
}

class _CandidatureCardState extends State<_CandidatureCard> {
  bool _deplie = false; // message complet affiché ?

  @override
  Widget build(BuildContext context) {
    final c = widget.candidature;
    // Le client voit le freelancer, le freelancer voit le client
    final nom = widget.isClient
        ? (c.freelancerUsername ?? 'freelancer')
        : (c.clientUsername ?? 'client');
    final enAttente = c.statut == 'en_attente';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // le client touche le freelancer → sa page de profil
                child: InkWell(
                  onTap: widget.onVoirProfil,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      UserAvatar(
                        name: nom,
                        isClient: !widget.isClient,
                        size: 38,
                        withShadow: false,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@$nom',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              widget.onVoirProfil != null
                                  ? 'Voir le profil · '
                                        '${tempsEcoule(c.dateCandidature)}'
                                  : tempsEcoule(c.dateCandidature),
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.onVoirProfil != null
                                    ? AppColors.cyan
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatutCandidatureChip(statut: c.statut),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.work_outline_rounded,
                size: 15,
                color: AppColors.cyan,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.postTitre ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cyan,
                  ),
                ),
              ),
              if (c.postBudget != null)
                BudgetChip(
                  budget: c.postBudget!,
                  horaire: c.postTypeBudget == 'horaire',
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Le message de candidature (tap pour tout lire)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _deplie = !_deplie),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isClient ? 'Son message' : 'Ton message',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.message,
                    maxLines: _deplie ? null : 3,
                    overflow: _deplie ? null : TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.label,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onDiscuter,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Discuter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.fieldBorder),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 42),
                  ),
                ),
              ),
              if (widget.isClient && enAttente) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Refuser',
                  onPressed: widget.onRefuser,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.fieldBorder),
                    fixedSize: const Size(42, 42),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: widget.onAccepter,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Accepter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 42),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
