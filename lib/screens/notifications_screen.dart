import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/user.dart';
import '../observer/evenements.dart';
import '../observer/observer.dart';
import '../services/candidature_service.dart';
import '../services/notification_service.dart';
import '../services/post_service.dart';
import '../services/project_service.dart';
import '../services/project_task_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/home_widgets.dart';
import 'freelancer/freelancer_home.dart' show ouvrirPostuler;
import 'project_management_screen.dart';

/// Liste des notifications de l'utilisateur.
/// OBSERVATEUR du [NotificationService] : la liste se rafraîchit seule.
class NotificationsScreen extends StatefulWidget {
  final User user;
  const NotificationsScreen({super.key, required this.user});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    implements Observateur<NotificationsModifiees> {
  final _service = NotificationService.instance;
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service.abonner(this);
    _charger();
  }

  @override
  void dispose() {
    _service.desabonner(this);
    super.dispose();
  }

  @override
  void mettreAJour(NotificationsModifiees e) {
    if (e.userId == widget.user.id) _charger();
  }

  Future<void> _charger() async {
    final liste = await _service.getNotifications(widget.user.id!);
    if (mounted) {
      setState(() {
        _notifications = liste;
        _loading = false;
      });
    }
  }

  // ---------- FONCTIONNALITÉ : ouvrir une notification ----------
  Future<void> _ouvrir(AppNotification n) async {
    await _service.marquerLue(n);
    if (n.type == AppNotification.typeProjet) return _ouvrirProjet(n);
    if (n.postId == null || !mounted) return;

    final post = await PostService().getPostById(n.postId!);
    if (!mounted) return;
    if (post == null || post.statut != 'ouvert') {
      showAppMessage(context, "Cette mission n'est plus ouverte.", error: true);
      return;
    }
    final postules = await CandidatureService().getPostIdsPostules(
      widget.user.id!,
    );
    if (!mounted) return;
    if (postules.contains(post.id)) {
      showAppMessage(context, 'Tu as déjà postulé à cette mission.');
      return;
    }
    final envoye = await ouvrirPostuler(
      context,
      post: post,
      freelancerId: widget.user.id!,
    );
    if (envoye && mounted) showAppMessage(context, 'Candidature envoyée !');
  }

  /// Notification de projet : ouvre la tâche concernée. Le retour passe par
  /// la liste des tâches du projet, où se trouvent les actions (soumettre,
  /// valider). Sans tâche liée : la liste des projets.
  Future<void> _ouvrirProjet(AppNotification n) async {
    final navigateur = Navigator.of(context);
    void ouvrir(Widget ecran) =>
        navigateur.push(MaterialPageRoute(builder: (_) => ecran));

    if (n.taskId == null) {
      if (mounted) ouvrir(ProjectManagementScreen(user: widget.user));
      return;
    }
    final tache = await ProjectTaskService().getTask(n.taskId!);
    final projets = await ProjectService().getProjectsForUser(widget.user.id!);
    if (!mounted) return;
    final projet = projets.where((p) => p.id == tache?.projectId).firstOrNull;
    if (tache == null || projet == null) {
      showAppMessage(context, "Cette tâche n'existe plus.", error: true);
      return;
    }
    ouvrir(ProjectTasksScreen(project: projet, user: widget.user));
    ouvrir(
      TaskDetailsScreen(
        task: tache,
        isClient: projet.clientId == widget.user.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nonLues = _notifications.where((n) => !n.lu).length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (nonLues > 0)
            TextButton(
              onPressed: () => _service.marquerToutesLues(widget.user.id!),
              style: TextButton.styleFrom(foregroundColor: AppColors.cyan),
              child: const Text('Tout marquer comme lu'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.red))
          : RefreshIndicator(
              color: AppColors.red,
              backgroundColor: AppColors.surface,
              onRefresh: _charger,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_notifications.isEmpty)
                    const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'Aucune notification',
                      message:
                          'Suis des clients depuis le fil des missions : tu '
                          'seras prévenu dès qu\'ils publient une offre.',
                    )
                  else
                    for (final n in _notifications)
                      _NotificationTile(
                        notification: n,
                        onTap: () => _ouvrir(n),
                      ),
                ],
              ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: n.lu ? AppColors.surface : const Color(0x1425F4EE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: n.lu ? AppColors.fieldBorder : const Color(0x5925F4EE),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  name: n.acteurNom ?? '?',
                  isClient: true,
                  size: 40,
                  withShadow: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.titre,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: n.lu ? FontWeight.w500 : FontWeight.w700,
                          color: n.lu
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.contenu,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyan,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tempsEcoule(n.dateCreation),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!n.lu)
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 4, left: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
