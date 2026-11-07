import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/abonnement_service.dart';
import '../services/candidature_service.dart';
import '../services/post_service.dart';
import '../services/realisation_service.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/home_widgets.dart';
import 'assistant/assistant_screen.dart';
import 'freelancer/clients_suivis.dart';
import 'tests/tests_screen.dart';
import '../services/test_service.dart';
import 'freelancer/publier_realisation.dart';
import 'login.dart';
import 'modifier_profil.dart';
import 'profil_freelancer.dart';

/// Onglet Profil (commun au Client et au Freelancer) :
/// carte d'identité, statistiques, profil à compléter (freelancer),
/// menu du compte et déconnexion.
class ProfilTab extends StatefulWidget {
  final User user;

  /// Appelé avec l'utilisateur mis à jour après une modification du profil
  final ValueChanged<User> onUserChanged;

  const ProfilTab({super.key, required this.user, required this.onUserChanged});

  @override
  State<ProfilTab> createState() => _ProfilTabState();
}

/// Une statistique affichée sous la carte
typedef _Stat = ({String valeur, String label, Color couleur});

class _ProfilTabState extends State<ProfilTab> {
  List<_Stat>? _stats;
  int _nbRealisations = 0;
  List<String> _domaines = const []; // fixés au 1er test

  User get _user => widget.user;
  bool get _isClient => _user.role == 'client';

  @override
  void initState() {
    super.initState();
    _chargerStats();
  }

  @override
  void didUpdateWidget(ProfilTab old) {
    super.didUpdateWidget(old);
    if (old.user != widget.user) _chargerStats();
  }

  // ---------- FONCTIONNALITÉ : statistiques ----------
  Future<void> _chargerStats() async {
    try {
      final List<_Stat> stats;
      if (_isClient) {
        final posts = await PostService().getPostsByClient(_user.id!);
        final abonnes = await AbonnementService().nbAbonnes(_user.id!);
        final candidatures = await CandidatureService().getCandidaturesByClient(
          _user.id!,
        );
        stats = [
          (
            valeur: '${posts.length}',
            label: 'Posts publiés',
            couleur: AppColors.textPrimary,
          ),
          (
            valeur: '$abonnes',
            label: 'Abonnés', // freelancers qui le suivent
            couleur: AppColors.cyan,
          ),
          (
            valeur:
                '${candidatures.where((c) => c.statut == 'acceptee').length}',
            label: 'Recrutements',
            couleur: AppColors.red,
          ),
        ];
      } else {
        final candidatures = await CandidatureService()
            .getCandidaturesByFreelancer(_user.id!);
        final realisations = await RealisationService().getByFreelancer(
          _user.id!,
        );
        _nbRealisations = realisations.length;
        _domaines = await TestService().domainesProfil(_user.id!);
        stats = [
          (
            valeur: '${candidatures.length}',
            label: 'Candidatures',
            couleur: AppColors.textPrimary,
          ),
          (
            valeur:
                '${candidatures.where((c) => c.statut == 'acceptee').length}',
            label: 'Acceptées',
            couleur: AppColors.cyan,
          ),
          (
            valeur: '${realisations.length}',
            label: 'Réalisations',
            couleur: AppColors.red,
          ),
        ];
      }
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // les statistiques sont un bonus : la page reste utilisable sans
      if (mounted) setState(() => _stats = const []);
    }
  }

  // ---------- Navigation ----------
  Future<void> _modifier() async {
    final misAJour = await Navigator.of(context).push<User>(
      MaterialPageRoute(builder: (_) => ModifierProfilScreen(user: _user)),
    );
    if (misAJour != null) widget.onUserChanged(misAJour);
  }

  Future<void> _profilPublic() async {
    await ouvrirProfilFreelancer(
      context,
      freelancerId: _user.id!,
      viewer: _user,
    );
    _chargerStats(); // il a pu ajouter / supprimer des réalisations
  }

  Future<void> _ajouterRealisation() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PublierRealisationScreen(user: _user)),
    );
    if (ok == true) _chargerStats();
  }

  // ---------- FONCTIONNALITÉ : déconnexion (avec confirmation) ----------
  Future<void> _deconnecter() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Tu devras entrer à nouveau ton email et ton mot de passe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Se déconnecter',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SessionManager.logout(); // oublie la session
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ---------- Interface ----------
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.red,
        backgroundColor: AppColors.surface,
        onRefresh: _chargerStats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Text(
              'Profil',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 18),
            _buildCarte(),
            const SizedBox(height: 12),
            _buildStats(),
            if (!_isClient) _buildACompleter(),
            const SizedBox(height: 26),
            const _TitreSection('Mon compte'),
            _Groupe(
              children: [
                _Ligne(
                  icone: Icons.edit_outlined,
                  titre: 'Modifier le profil',
                  sousTitre: _isClient
                      ? 'Nom, email et mot de passe'
                      : 'Nom, email, métier, bio, mot de passe',
                  onTap: _modifier,
                ),
                if (!_isClient) ...[
                  _Ligne(
                    icone: Icons.visibility_outlined,
                    titre: 'Mon profil public',
                    sousTitre: 'Ce que voient les clients',
                    onTap: _profilPublic,
                  ),
                  _Ligne(
                    icone: Icons.add_photo_alternate_outlined,
                    titre: 'Ajouter une réalisation',
                    sousTitre: 'Un projet, un site, une expérience…',
                    onTap: _ajouterRealisation,
                  ),
                  _Ligne(
                    icone: Icons.workspace_premium_outlined,
                    titre: 'Tests et certifications',
                    sousTitre: 'Passe un test et obtiens une certification',
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TestsScreen(user: _user),
                        ),
                      );
                      _chargerStats(); // domaines fixés au 1er test
                    },
                  ),
                  _Ligne(
                    icone: Icons.notifications_active_outlined,
                    titre: 'Clients suivis',
                    sousTitre: 'Notifié de leurs nouvelles missions',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClientsSuivisScreen(user: _user),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),
            const _TitreSection('Application'),
            _Groupe(
              children: [
                _Ligne(
                  icone: Icons.auto_awesome_rounded,
                  titre: 'Assistant',
                  sousTitre: "Une question sur l'application ?",
                  onTap: () => ouvrirAssistant(context, user: _user),
                ),
                const _Ligne(
                  icone: Icons.cloud_off_outlined,
                  titre: 'Fonctionne hors connexion',
                  sousTitre: "Tes données restent sur ce téléphone (sauf l'IA)",
                ),
                const _Ligne(
                  icone: Icons.info_outline_rounded,
                  titre: 'Version',
                  valeur: '1.0.0',
                ),
              ],
            ),
            const SizedBox(height: 22),
            _Groupe(
              children: [
                _Ligne(
                  icone: Icons.logout_rounded,
                  titre: 'Se déconnecter',
                  couleur: AppColors.error,
                  onTap: _deconnecter,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Carte d'identité : avatar, nom, email, rôle, métier et bio
  Widget _buildCarte() {
    final accent = _isClient ? AppColors.red : AppColors.cyan;
    final bio = _user.bio;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 8, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.fieldBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.16), AppColors.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(name: _user.username, isClient: _isClient, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${_user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _isClient ? 'Client' : 'Freelancer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isClient ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        if (!_isClient && _user.metier != null)
                          Text(
                            _user.metier!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.cyan,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Modifier le profil',
                onPressed: _modifier,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (!_isClient && _domaines.isNotEmpty) ...[
            const SizedBox(height: 14),
            PucesDomaines(domaines: _domaines),
          ],
          if (!_isClient) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: bio != null
                  ? Text(
                      bio,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.label,
                      ),
                    )
                  : GestureDetector(
                      onTap: _modifier,
                      child: const Text(
                        '+ Ajoute une bio pour te présenter aux clients',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats() {
    final stats = _stats;
    if (stats == null) {
      return const SizedBox(
        height: 76,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.red,
            ),
          ),
        ),
      );
    }
    if (stats.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: StatCard(
              value: stats[i].valeur,
              label: stats[i].label,
              valueColor: stats[i].couleur,
            ),
          ),
        ],
      ],
    );
  }

  /// Freelancer : ce qu'il reste à remplir pour un profil attirant
  Widget _buildACompleter() {
    if (_stats == null) return const SizedBox.shrink();
    final etapes = [
      (
        fait: _user.metier != null,
        texte: 'Indique ton métier',
        onTap: _modifier,
      ),
      (fait: _user.bio != null, texte: 'Écris ta bio', onTap: _modifier),
      (
        fait: _nbRealisations > 0,
        texte: 'Ajoute une réalisation',
        onTap: _ajouterRealisation,
      ),
    ];
    final nbFaites = etapes.where((e) => e.fait).length;
    if (nbFaites == etapes.length) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x4025F4EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Complète ton profil',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$nbFaites/${etapes.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Un profil complet donne confiance aux clients.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: nbFaites / etapes.length,
              minHeight: 6,
              color: AppColors.cyan,
              backgroundColor: AppColors.fieldBorder,
            ),
          ),
          const SizedBox(height: 8),
          for (final e in etapes)
            InkWell(
              onTap: e.fait ? null : e.onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      e.fait
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: e.fait ? AppColors.cyan : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.texte,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: e.fait
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          decoration: e.fait
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (!e.fait)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TitreSection extends StatelessWidget {
  final String texte;
  const _TitreSection(this.texte);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        texte.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Un bloc arrondi qui regroupe plusieurs lignes, séparées par un trait
class _Groupe extends StatelessWidget {
  final List<Widget> children;
  const _Groupe({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 60,
                color: AppColors.fieldBorder,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Une ligne du menu (cliquable si [onTap] est donné)
class _Ligne extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String? sousTitre;
  final String? valeur; // texte à droite (ex : version)
  final Color couleur;
  final VoidCallback? onTap;

  const _Ligne({
    required this.icone,
    required this.titre,
    this.sousTitre,
    this.valeur,
    this.couleur = AppColors.textPrimary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: couleur == AppColors.error
                      ? const Color(0x1FFF6B8A)
                      : AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icone,
                  size: 19,
                  color: couleur == AppColors.error
                      ? AppColors.error
                      : AppColors.label,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: couleur,
                      ),
                    ),
                    if (sousTitre != null)
                      Text(
                        sousTitre!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (valeur != null)
                Text(
                  valeur!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                )
              else if (onTap != null && couleur != AppColors.error)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
