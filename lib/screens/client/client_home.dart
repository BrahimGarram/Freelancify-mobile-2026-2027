import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../models/post_options.dart';
import '../../models/user.dart';
import '../../services/message_service.dart';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/home_widgets.dart';
import '../candidatures_tab.dart';
import '../messages/messages_tab.dart';
import '../profil_tab.dart';
import 'publier_post.dart';

/// Page principale du Client, avec la barre de navigation du bas.
class ClientHome extends StatefulWidget {
  final User user;
  const ClientHome({super.key, required this.user});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  // Copie modifiable : mise à jour après « Modifier le profil »
  late User _user = widget.user;
  int _nonLus = 0; // pastille sur l'onglet Messages

  @override
  void initState() {
    super.initState();
    _rafraichirNonLus();
  }

  Future<void> _rafraichirNonLus() async {
    final n = await MessageService().nbNonLus(_user.id!);
    if (mounted) setState(() => _nonLus = n);
  }

  int _index = 0;
  int _refresh = 0; // change → "Mes posts" se recharge

  static const _items = [
    NavItem(Icons.work_outline_rounded, 'Mes posts'),
    NavItem(Icons.people_outline_rounded, 'Candidatures'),
    NavItem(Icons.chat_bubble_outline_rounded, 'Messages'),
    NavItem(Icons.person_outline_rounded, 'Profil'),
  ];

  // Bouton "+" → formulaire de publication
  Future<void> _ouvrirPublier() async {
    final publie = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PublierPostScreen(user: _user)),
    );
    if (publie == true && mounted) {
      setState(() {
        _index = 0; // on revient sur "Mes posts"
        _refresh++; // et on recharge la liste
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget page = switch (_index) {
      0 => MesPostsTab(key: ValueKey(_refresh), user: _user),
      1 => CandidaturesTab(
        user: _user,
        onChanged: () {
          _rafraichirNonLus();
          _refresh++; // « Mes posts » se recharge (statut du post)
        },
      ),
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
            right: -100,
            child: Halo(size: 280, color: Color(0x2EEE1D52)),
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
        onPlus: _ouvrirPublier,
        plusPosition: 2,
      ),
    );
  }
}

// =========================== Onglet "Mes posts" ===========================

class MesPostsTab extends StatefulWidget {
  final User user;
  const MesPostsTab({super.key, required this.user});

  @override
  State<MesPostsTab> createState() => _MesPostsTabState();
}

class _MesPostsTabState extends State<MesPostsTab> {
  final _postService = PostService();
  List<Post> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  // ---------- FONCTIONNALITÉ : charger les posts du client ----------
  Future<void> _charger() async {
    try {
      final posts = await _postService.getPostsByClient(widget.user.id!);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppMessage(context, 'Erreur : $e', error: true);
    }
  }

  // ---------- FONCTIONNALITÉ : supprimer un post ----------
  Future<void> _supprimer(Post post) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Supprimer ce post ?'),
        content: const Text(
          'Les candidatures reçues pour ce post seront aussi supprimées.',
          style: TextStyle(color: AppColors.textSecondary),
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
    if (confirme != true) return;

    await _postService.deletePost(post.id!);
    if (!mounted) return;
    showAppMessage(context, 'Post supprimé');
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final nbOuverts = _posts.where((p) => p.statut == 'ouvert').length;
    final nbCandidatures = _posts.fold<int>(
      0,
      (total, p) => total + p.nbCandidatures,
    );

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
            HomeHeader(user: widget.user, title: 'Mes posts'),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StatCard(value: '$nbOuverts', label: 'Posts ouverts'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    value: '$nbCandidatures',
                    label: 'Candidatures reçues',
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
            else if (_posts.isEmpty)
              const EmptyState(
                icon: Icons.post_add_rounded,
                title: 'Aucun post pour le moment',
                message: 'Appuie sur le bouton + en bas pour publier ta première offre.',
              )
            else
              for (final post in _posts)
                _ClientPostCard(post: post, onDelete: () => _supprimer(post)),
          ],
        ),
      ),
    );
  }
}

class _ClientPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onDelete;

  const _ClientPostCard({required this.post, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final nb = post.nbCandidatures;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
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
              Text(
                tempsEcoule(post.dateCreation),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              if (post.urgent) ...[
                const SizedBox(width: 8),
                const UrgentBadge(),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x6625F4EE)),
                ),
                child: Text(
                  PostOptions.statuts[post.statut] ?? post.statut,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cyan,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.titre,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  post.description,
                  maxLines: 2,
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
                    BudgetChip(budget: post.budget, horaire: post.estHoraire),
                    const Spacer(),
                    const Icon(
                      Icons.people_outline_rounded,
                      size: 16,
                      color: AppColors.label,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$nb candidature${nb > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.label,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
