import 'package:flutter/material.dart';

import '../../models/candidature.dart';
import '../../models/post.dart';
import '../../models/user.dart';
import '../../services/abonnement_service.dart';
import '../../services/message_service.dart';
import '../../services/candidature_service.dart';
import '../../services/post_service.dart';
import '../../services/test_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/home_widgets.dart';
import '../candidatures_tab.dart';
import '../profil_freelancer.dart';
import '../tests/tests_screen.dart';
import 'publier_realisation.dart';
import '../messages/messages_tab.dart';
import '../profil_tab.dart';

/// Page principale du Freelancer, avec la barre de navigation du bas.
class FreelancerHome extends StatefulWidget {
  final User user;
  const FreelancerHome({super.key, required this.user});

  @override
  State<FreelancerHome> createState() => _FreelancerHomeState();
}

class _FreelancerHomeState extends State<FreelancerHome> {
  // Copie modifiable : mise à jour après « Modifier le profil »
  late User _user = widget.user;
  int _nonLus = 0; // pastille sur l'onglet Messages

  @override
  void initState() {
    super.initState();
    _rafraichirNonLus();
  }

  // Bouton "+" → ajouter une réalisation au portfolio
  Future<void> _ajouterRealisation() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PublierRealisationScreen(user: _user)),
    );
    if (ok == true && mounted) {
      ouvrirProfilFreelancer(context, freelancerId: _user.id!, viewer: _user);
    }
  }

  Future<void> _rafraichirNonLus() async {
    final n = await MessageService().nbNonLus(_user.id!);
    if (mounted) setState(() => _nonLus = n);
  }

  int _index = 0;

  static const _items = [
    NavItem(Icons.home_outlined, 'Missions'),
    NavItem(Icons.send_outlined, 'Candidatures'),
    NavItem(Icons.chat_bubble_outline_rounded, 'Messages'),
    NavItem(Icons.person_outline_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final Widget page = switch (_index) {
      0 => MissionsTab(user: _user),
      1 => CandidaturesTab(user: _user, onChanged: _rafraichirNonLus),
      2 => MessagesTab(user: _user, onLu: _rafraichirNonLus),
      _ => ProfilTab(
        user: _user,
        onUserChanged: (u) => setState(() => _user = u),
      ),
    };

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -120,
            left: -100,
            child: Halo(size: 280, color: Color(0x2425F4EE)),
          ),
          page,
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        items: _items,
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          _rafraichirNonLus();
        },
        badges: {2: _nonLus},
        onPlus: _ajouterRealisation,
        plusPosition: 2,
      ),
    );
  }
}

// =========================== Onglet "Missions" ===========================

class MissionsTab extends StatefulWidget {
  final User user;
  const MissionsTab({super.key, required this.user});

  @override
  State<MissionsTab> createState() => _MissionsTabState();
}

class _MissionsTabState extends State<MissionsTab> {
  final _postService = PostService();
  final _candidatureService = CandidatureService();
  final _abonnements = AbonnementService();

  List<Post> _posts = [];
  Set<int> _postules = {}; // ids des posts où j'ai déjà postulé
  Set<int> _suivis = {}; // ids des clients que je suis
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  // ---------- FONCTIONNALITÉ : charger les posts des clients ----------
  Future<void> _charger() async {
    try {
      final posts = await _postService.getPostsOuverts();
      final postules = await _candidatureService.getPostIdsPostules(
        widget.user.id!,
      );
      final suivis = await _abonnements.clientsSuivis(widget.user.id!);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _postules = postules;
        _suivis = suivis;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppMessage(context, 'Erreur : $e', error: true);
    }
  }

  // ---------- FONCTIONNALITÉ : suivre un client ----------
  Future<void> _basculerSuivi(Post post) async {
    final clientId = post.clientId;
    final nom = post.clientUsername ?? 'client';
    final suivait = _suivis.contains(clientId);
    // mise à jour immédiate de l'écran, annulée en cas d'erreur
    setState(() => suivait ? _suivis.remove(clientId) : _suivis.add(clientId));
    try {
      if (suivait) {
        await _abonnements.nePlusSuivre(
          freelancerId: widget.user.id!,
          clientId: clientId,
        );
      } else {
        await _abonnements.suivre(
          freelancerId: widget.user.id!,
          clientId: clientId,
        );
      }
      if (!mounted) return;
      showAppMessage(
        context,
        suivait
            ? 'Tu ne suis plus @$nom'
            : 'Tu suis @$nom : tu seras notifié de ses nouvelles missions',
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => suivait ? _suivis.add(clientId) : _suivis.remove(clientId),
      );
      showAppMessage(context, '$e', error: true);
    }
  }

  // ---------- FONCTIONNALITÉ : postuler ----------
  Future<void> _ouvrirPostuler(Post post) async {
    final envoye = await ouvrirPostuler(
      context,
      post: post,
      freelancerId: widget.user.id!,
    );
    if (envoye && mounted) {
      setState(() => _postules.add(post.id!));
      showAppMessage(context, 'Candidature envoyée !');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nb = _posts.length;

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
              title: 'Missions',
              apresNotifications: _charger, // a pu postuler depuis une notif
            ),
            const SizedBox(height: 18),
            if (!_loading && nb > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: '$nb mission${nb > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' ouverte${nb > 1 ? 's' : ''} en ce moment',
                      ),
                    ],
                  ),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.red),
                ),
              )
            else if (_posts.isEmpty)
              const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Aucune mission pour le moment',
                message: 'Les offres publiées par les clients apparaîtront ici. Tire vers le bas pour actualiser.',
              )
            else
              for (final post in _posts)
                _MissionCard(
                  post: post,
                  dejaPostule: _postules.contains(post.id),
                  suivi: _suivis.contains(post.clientId),
                  onPostuler: () => _ouvrirPostuler(post),
                  onSuivre: () => _basculerSuivi(post),
                ),
          ],
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final Post post;
  final bool dejaPostule;
  final bool suivi; // je suis ce client ?
  final VoidCallback onPostuler;
  final VoidCallback onSuivre;

  const _MissionCard({
    required this.post,
    required this.dejaPostule,
    required this.suivi,
    required this.onPostuler,
    required this.onSuivre,
  });

  @override
  Widget build(BuildContext context) {
    final client = post.clientUsername ?? 'client';

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
              UserAvatar(
                name: client,
                isClient: true,
                size: 34,
                withShadow: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$client',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      tempsEcoule(post.dateCreation),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.urgent) ...[
                const UrgentBadge(),
                const SizedBox(width: 6),
              ],
              _BoutonSuivre(suivi: suivi, onTap: onSuivre),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.titre,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            post.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          PostInfos(post: post),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: BudgetChip(
                      budget: post.budget,
                      horaire: post.estHoraire,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (dejaPostule)
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.cyan, width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.cyan,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Postulé',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyan,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: onPostuler,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Postuler'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// « Suivre » / « Suivi » : s'abonner aux nouvelles missions d'un client
class _BoutonSuivre extends StatelessWidget {
  final bool suivi;
  final VoidCallback onTap;
  const _BoutonSuivre({required this.suivi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // petit écran : icône seule (le texte reste dans l'info-bulle)
    if (MediaQuery.sizeOf(context).width < 360) {
      return IconButton(
        tooltip: suivi ? 'Ne plus suivre' : 'Suivre ce client',
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: suivi ? Colors.transparent : AppColors.cyan,
          foregroundColor: suivi ? AppColors.cyan : Colors.black,
          side: suivi ? const BorderSide(color: Color(0x8025F4EE)) : null,
        ),
        icon: Icon(
          suivi
              ? Icons.notifications_active_rounded
              : Icons.person_add_alt_1_rounded,
          size: 18,
        ),
      );
    }
    return SizedBox(
      height: 32,
      child: suivi
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.notifications_active_rounded, size: 15),
              label: const Text('Suivi'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.cyan,
                side: const BorderSide(color: Color(0x8025F4EE)),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Suivre'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyan,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}

// ===================== Panneau "Postuler" (bottom sheet) =====================

/// Ouvre le panneau « Postuler » ; renvoie true si la candidature est partie.
/// Utilisé par le fil des missions et par l'écran des notifications.
///
/// Il faut avoir réussi un test de compétences : sinon on propose d'abord
/// l'espace des tests, puis on revient au panneau si le test est réussi.
Future<bool> ouvrirPostuler(
  BuildContext context, {
  required Post post,
  required int freelancerId,
}) async {
  final tests = TestService();
  final etat = await tests.etat(freelancerId);
  if (!etat.certifie) {
    if (!context.mounted) return false;
    final passer = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // hauteur selon le contenu (petits écrans)
      backgroundColor: AppColors.surface,
      barrierColor: const Color(0xA6000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => TestRequisSheet(restantes: etat.restantes),
    );
    if (passer != true || !context.mounted) return false;
    final user = await UserService().getUserById(freelancerId);
    if (user == null || !context.mounted) return false;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TestsScreen(user: user)));
    // toujours pas certifié : pas de candidature
    if (!await tests.estCertifie(freelancerId)) return false;
  }
  if (!context.mounted) return false;
  final envoye = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true, // le panneau monte avec le clavier
    backgroundColor: AppColors.surface,
    barrierColor: const Color(0xA6000000),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => PostulerSheet(post: post, freelancerId: freelancerId),
  );
  return envoye == true;
}

/// Panneau affiché quand un freelancer non certifié veut postuler
class TestRequisSheet extends StatelessWidget {
  final int restantes; // tentatives restantes (0 : plus de test possible)
  const TestRequisSheet({super.key, required this.restantes});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.fieldBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 22),
            const Icon(
              Icons.workspace_premium_rounded,
              size: 52,
              color: Color(0xFFE9C46A),
            ),
            const SizedBox(height: 12),
            const Text(
              'Certification requise',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              restantes > 0
                  ? 'Pour postuler aux missions, réussis d\'abord un test de '
                        'compétences : ${TestService.nbQuestions} questions '
                        'chronométrées, au moins ${TestService.seuilReussite} '
                        '% de bonnes réponses. Il te reste $restantes '
                        'tentative${restantes > 1 ? 's' : ''}.'
                  : 'Tu as utilisé tes ${TestService.tentativesMax} '
                        'tentatives sans obtenir la certification : tu ne '
                        'peux pas postuler aux missions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            if (restantes > 0) ...[
              PrimaryButton(
                label: 'Passer le test',
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 6),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: Text(restantes > 0 ? 'Plus tard' : 'Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}

class PostulerSheet extends StatefulWidget {
  final Post post;
  final int freelancerId;

  const PostulerSheet({
    super.key,
    required this.post,
    required this.freelancerId,
  });

  @override
  State<PostulerSheet> createState() => PostulerSheetState();
}

class PostulerSheetState extends State<PostulerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _candidatureService = CandidatureService();
  bool _loading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _candidatureService.postuler(
        Candidature(
          postId: widget.post.id!,
          freelancerId: widget.freelancerId,
          message: _messageController.text.trim(),
          dateCandidature: DateTime.now().toIso8601String(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true); // succès
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppMessage(context, 'Erreur : $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final client = post.clientUsername ?? 'client';
    // Espace pris par le clavier, pour que le panneau monte au-dessus
    final clavier = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + clavier),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x40FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Postuler',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ton message sera envoyé au client.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Rappel de la mission
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          name: client,
                          isClient: true,
                          size: 30,
                          withShadow: false,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '@$client',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        BudgetChip(
                          budget: post.budget,
                          horaire: post.estHoraire,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      post.titre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Ton message au client',
                hint: 'Présente-toi, explique comment tu vas faire le travail et en combien de temps…',
                controller: _messageController,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLength: Validators.messageMax,
                validator: Validators.message,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Envoyer ma candidature',
                loading: _loading,
                onPressed: _envoyer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
