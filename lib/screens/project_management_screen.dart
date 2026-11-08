import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/project.dart';
import '../models/project_task.dart';
import '../models/user.dart';
import '../services/message_service.dart';
import '../services/project_service.dart';
import '../services/project_task_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/home_widgets.dart';
import 'client/publier_post.dart';
import 'freelancer/publier_realisation.dart';

class ProjectManagementScreen extends StatefulWidget {
  final User user;

  const ProjectManagementScreen({super.key, required this.user});

  @override
  State<ProjectManagementScreen> createState() =>
      _ProjectManagementScreenState();
}

class _ProjectManagementScreenState extends State<ProjectManagementScreen> {
  late Future<List<Project>> _projects;
  int _nonLus = 0;

  bool get _isClient => widget.user.role == 'client';

  @override
  void initState() {
    super.initState();
    _projects = ProjectService().getProjectsForUser(widget.user.id!);
    _rafraichirNonLus();
  }

  Future<void> _rafraichirNonLus() async {
    final count = await MessageService().nbNonLus(widget.user.id!);
    if (mounted) setState(() => _nonLus = count);
  }

  Future<void> _refresh() async {
    setState(() {
      _projects = ProjectService().getProjectsForUser(widget.user.id!);
    });
    await _projects;
  }

  Future<void> _ouvrirActionPrincipale() async {
    if (_isClient) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PublierPostScreen(user: widget.user)),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublierRealisationScreen(user: widget.user),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestion des projets'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBar: _ProjetBottomNav(
        isClient: _isClient,
        nonLus: _nonLus,
        onPlus: _ouvrirActionPrincipale,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: widget.user.isFreelancer ? -100 : null,
            right: widget.user.isFreelancer ? null : -100,
            child: Halo(
              size: 280,
              color: widget.user.isFreelancer
                  ? const Color(0x2425F4EE)
                  : const Color(0x2EEE1D52),
            ),
          ),
          RefreshIndicator(
            color: AppColors.red,
            backgroundColor: AppColors.surface,
            onRefresh: _refresh,
            child: FutureBuilder<List<Project>>(
              future: _projects,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.cyan),
                  );
                }
                if (snapshot.hasError) {
                  return _Message(
                    icon: Icons.error_outline,
                    text: 'Impossible de charger les projets.',
                  );
                }
                final projects = snapshot.data ?? const <Project>[];
                if (projects.isEmpty) {
                  return _Message(
                    icon: Icons.folder_open_outlined,
                    text: 'Aucun projet accepté pour le moment.',
                  );
                }
                final isClient = widget.user.role == 'client';
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    if (isClient) ...[
                      _ClientWorkflowDashboard(projects: projects),
                      const SizedBox(height: 18),
                    ],
                    for (final project in projects) ...[
                      _ProjectCard(
                        project: project,
                        isClient: isClient,
                        user: widget.user,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProjectTasksScreen(
                                project: project,
                                user: widget.user,
                              ),
                            ),
                          );
                          if (mounted) await _refresh();
                        },
                      ),
                      if (project != projects.last) const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre du bas des écrans de projet : chaque bouton ramène à l'accueil,
/// sur le bon onglet, quel que soit le nombre d'écrans ouverts.
class _ProjetBottomNav extends StatelessWidget {
  final bool isClient;
  final int nonLus;
  final VoidCallback onPlus;

  const _ProjetBottomNav({
    required this.isClient,
    required this.nonLus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return AppBottomNav(
      items: isClient
          ? const [
              NavItem(Icons.work_outline_rounded, 'Mes posts'),
              NavItem(Icons.people_outline_rounded, 'Candidatures'),
              NavItem(Icons.chat_bubble_outline_rounded, 'Messages'),
              NavItem(Icons.person_outline_rounded, 'Profil'),
            ]
          : const [
              NavItem(Icons.home_outlined, 'Missions'),
              NavItem(Icons.send_outlined, 'Candidatures'),
              NavItem(Icons.chat_bubble_outline_rounded, 'Messages'),
              NavItem(Icons.person_outline_rounded, 'Profil'),
            ],
      currentIndex: 3,
      onTap: (onglet) => ouvrirOngletAccueil(context, onglet),
      badges: {2: nonLus},
      onPlus: onPlus,
      plusPosition: 2,
    );
  }
}

class _ClientWorkflowDashboard extends StatelessWidget {
  final List<Project> projects;

  const _ClientWorkflowDashboard({required this.projects});

  @override
  Widget build(BuildContext context) {
    final totalTasks = projects.fold<int>(
      0,
      (total, project) => total + project.totalTasks,
    );
    final completedTasks = projects.fold<int>(
      0,
      (total, project) => total + project.validatedTasks,
    );
    final projectsCompleted = projects
        .where((project) => project.status == 'termine')
        .length;
    final tasksToReview = projects.fold<int>(
      0,
      (total, project) => total + project.totalTasks - project.validatedTasks,
    );
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D1020), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vue d’ensemble',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Suivi global de ton activité client',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _WorkflowMetric(
                  icon: Icons.folder_copy_outlined,
                  value: '${projects.length}',
                  label: 'Projets',
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WorkflowMetric(
                  icon: Icons.task_alt_outlined,
                  value: '$completedTasks',
                  label: 'Tâches terminées',
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _WorkflowMetric(
                  icon: Icons.rate_review_outlined,
                  value: '$tasksToReview',
                  label: 'À suivre / revoir',
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WorkflowMetric(
                  icon: Icons.emoji_events_outlined,
                  value: '$projectsCompleted',
                  label: 'Projets clôturés',
                  color: const Color(0xFFE9C46A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progression globale',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()} %',
                style: const TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.cyan,
            backgroundColor: AppColors.fieldBorder,
          ),
          const SizedBox(height: 7),
          Text(
            '$completedTasks tâche(s) validée(s) sur $totalTasks',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _WorkflowMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _WorkflowMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final bool isClient;
  final User user;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.project,
    required this.isClient,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherUser = isClient
        ? project.freelancerUsername
        : project.clientUsername;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
                  child: Text(
                    project.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusBadge(project.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isClient
                  ? 'Freelancer : @${otherUser ?? 'inconnu'}'
                  : 'Client : @${otherUser ?? 'inconnu'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (project.deadline != null) ...[
              const SizedBox(height: 4),
              Text(
                'Échéance : ${_date(project.deadline!)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: project.totalTasks == 0 ? 0 : project.progress / 100,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.cyan,
                    backgroundColor: AppColors.fieldBorder,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${project.progress} %',
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${project.validatedTasks}/${project.totalTasks} tâche(s) validée(s)',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (isClient) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProjectProgressScreen(
                        project: project,
                        clientId: project.clientId,
                        user: user,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: const Text('Voir la progression'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _date(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class ProjectProgressScreen extends StatefulWidget {
  final Project project;
  final int clientId;
  final User user;

  const ProjectProgressScreen({
    super.key,
    required this.project,
    required this.clientId,
    required this.user,
  });

  @override
  State<ProjectProgressScreen> createState() => _ProjectProgressScreenState();
}

class _ProjectProgressScreenState extends State<ProjectProgressScreen> {
  late Future<List<ProjectTask>> _tasks;
  late Future<bool> _rewarded;
  bool _closed = false;
  int _nonLus = 0;

  bool get _isClient => widget.user.role == 'client';

  @override
  void initState() {
    super.initState();
    _reload();
    _rafraichirNonLus();
  }

  Future<void> _rafraichirNonLus() async {
    final count = await MessageService().nbNonLus(widget.user.id!);
    if (mounted) setState(() => _nonLus = count);
  }

  void _reload() {
    final service = ProjectService();
    _tasks = service.getTasks(widget.project.id);
    _rewarded = service.hasProjectReward(widget.project.id);
  }

  Future<void> _ouvrirActionPrincipale() async {
    if (_isClient) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PublierPostScreen(user: widget.user)),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublierRealisationScreen(user: widget.user),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Progression du projet')),
    bottomNavigationBar: _ProjetBottomNav(
      isClient: _isClient,
      nonLus: _nonLus,
      onPlus: _ouvrirActionPrincipale,
    ),
    body: FutureBuilder<List<ProjectTask>>(
      future: _tasks,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.cyan),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('Impossible de charger la progression.'),
          );
        }
        final tasks = snapshot.data ?? const <ProjectTask>[];
        final completed = tasks
            .where((task) => task.status == 'validee')
            .length;
        final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              widget.project.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Freelancer : @${widget.project.freelancerUsername ?? 'inconnu'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              '$completed/${tasks.length} tâche(s) terminée(s)',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(10),
              color: AppColors.cyan,
              backgroundColor: AppColors.fieldBorder,
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).round()} % terminé',
              style: const TextStyle(
                color: AppColors.cyan,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tâches terminées',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (tasks.isEmpty)
              const Text(
                'Aucune tâche dans ce projet.',
                style: TextStyle(color: AppColors.textMuted),
              )
            else
              ...tasks.map(
                (task) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    task.status == 'validee'
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: task.status == 'validee'
                        ? AppColors.cyan
                        : AppColors.textMuted,
                  ),
                  title: Text(task.title),
                  subtitle: Text(_taskStatus(task.status)),
                ),
              ),
            const SizedBox(height: 18),
            FutureBuilder<bool>(
              future: _rewarded,
              builder: (context, rewardSnapshot) {
                if (rewardSnapshot.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                final rewarded = rewardSnapshot.data ?? false;
                if (rewarded || _closed) {
                  return FilledButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('Projet clôturé'),
                  );
                }
                if (tasks.isEmpty || completed != tasks.length) {
                  return FilledButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.hourglass_empty_outlined),
                    label: Text('Validez toutes les tâches pour clôturer'),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _giftCofeeCoin,
                      icon: const Icon(Icons.local_cafe_outlined),
                      label: const Text('Offrir 1 CofeeCoin'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _endProject,
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Terminer le projet sans CofeeCoin'),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    ),
  );

  Future<void> _giftCofeeCoin() async {
    final service = ProjectService();
    final balance = await service.getClientCoinBalance(widget.clientId);
    if (balance < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu ne possèdes aucun CofeeCoin à offrir.'),
          ),
        );
      }
      return;
    }
    try {
      final freelancerBalance = await service.rewardCompletedProject(
        projectId: widget.project.id,
        clientId: widget.clientId,
        coins: 1,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '1 CofeeCoin envoyé. Solde du freelancer : $freelancerBalance',
            ),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _closed = true;
        _reload();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Récompense impossible : $error')),
        );
      }
    }
  }

  Future<void> _endProject() async {
    try {
      await ProjectService().closeProjectWithoutReward(
        projectId: widget.project.id,
        clientId: widget.clientId,
      );
      if (!mounted) return;
      setState(() {
        _closed = true;
        _reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projet clôturé sans CofeeCoin.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Clôture impossible : $error')));
      }
    }
  }

  String _taskStatus(String status) => switch (status) {
    'validee' => 'Terminée et validée',
    'a_valider' => 'En attente de validation',
    'refusee' => 'À reprendre',
    'en_cours' => 'En cours',
    _ => 'À faire',
  };
}

class ProjectTasksScreen extends StatefulWidget {
  final Project project;
  final User user;

  const ProjectTasksScreen({
    super.key,
    required this.project,
    required this.user,
  });

  @override
  State<ProjectTasksScreen> createState() => _ProjectTasksScreenState();
}

class _ProjectTasksScreenState extends State<ProjectTasksScreen> {
  late Future<List<ProjectTask>> _tasks;
  int _nonLus = 0;

  bool get _isClient => widget.user.id == widget.project.clientId;

  @override
  void initState() {
    super.initState();
    _reload();
    _rafraichirNonLus();
  }

  Future<void> _rafraichirNonLus() async {
    final count = await MessageService().nbNonLus(widget.user.id!);
    if (mounted) setState(() => _nonLus = count);
  }

  void _reload() {
    _tasks = ProjectTaskService().getTasks(widget.project.id);
  }

  Future<void> _ouvrirActionPrincipale() async {
    if (_isClient) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PublierPostScreen(user: widget.user)),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublierRealisationScreen(user: widget.user),
        ),
      );
    }
  }

  Future<void> _addTask() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProjectTaskEditorScreen(
          projectId: widget.project.id,
          clientId: widget.project.clientId,
        ),
      ),
    );
    if (created == true && mounted) {
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.project.title)),
      bottomNavigationBar: _ProjetBottomNav(
        isClient: _isClient,
        nonLus: _nonLus,
        onPlus: _ouvrirActionPrincipale,
      ),
      floatingActionButton: _isClient && widget.project.status != 'termine'
          ? FloatingActionButton.extended(
              onPressed: _addTask,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une tâche'),
            )
          : null,
      body: FutureBuilder<List<ProjectTask>>(
        future: _tasks,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.cyan),
            );
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger les tâches.'),
            );
          }
          final tasks = snapshot.data ?? const <ProjectTask>[];
          if (tasks.isEmpty) {
            return Center(
              child: Text(
                _isClient
                    ? 'Aucune tâche. Ajoute la première tâche du projet.'
                    : 'Le client n’a pas encore ajouté de tâche.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _TaskCard(
              task: tasks[index],
              isClient: _isClient,
              clientId: widget.project.clientId,
              freelancerId: widget.project.freelancerId,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaskDetailsScreen(
                    task: tasks[index],
                    isClient: _isClient,
                  ),
                ),
              ),
              onChanged: () => setState(_reload),
            ),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final ProjectTask task;
  final bool isClient;
  final int clientId;
  final int freelancerId;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  const _TaskCard({
    required this.task,
    required this.isClient,
    required this.clientId,
    required this.freelancerId,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.fieldBorder),
          boxShadow: [
            BoxShadow(
              color: _priorityColor(task.priority).withValues(alpha: 0.2),
              blurRadius: 0,
              spreadRadius: 1,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _TaskStatusBadge(task.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TaskMetaChip(
                  icon: Icons.flag_outlined,
                  label: _priorityLabel(task.priority),
                  color: _priorityColor(task.priority),
                ),
                if (task.dueDate != null)
                  _TaskMetaChip(
                    icon: Icons.event_outlined,
                    label: _date(task.dueDate!),
                    color: AppColors.textSecondary,
                  ),
                if (task.attachmentName != null)
                  const _TaskMetaChip(
                    icon: Icons.attach_file_rounded,
                    label: 'Fichier joint',
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                task.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (task.driveUrl != null || task.githubUrl != null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () =>
                    _openResource(context, task.driveUrl ?? task.githubUrl!),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link_outlined,
                        size: 16,
                        color: AppColors.cyan,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          task.driveUrl != null
                              ? 'Ouvrir Google Drive'
                              : 'Ouvrir le dépôt GitHub',
                          style: const TextStyle(
                            color: AppColors.cyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (task.workDescription?.trim().isNotEmpty == true ||
                task.workLink?.trim().isNotEmpty == true ||
                task.workAttachmentName != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.cyan,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Travail déjà déposé',
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (task.attachmentName != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await ProjectTaskService().downloadAttachment(task);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Téléchargement impossible : $e'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.download_outlined),
                label: const Text('Télécharger le fichier joint'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],
            if (isClient && !_hasSubmission) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.fieldBorder),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final updated = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ProjectTaskEditorScreen(
                              projectId: task.projectId,
                              clientId: clientId,
                              existing: task,
                            ),
                          ),
                        );
                        if (updated == true) onChanged();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Supprimer cette tâche ?'),
                            content: const Text(
                              'Cette action est définitive et supprimera aussi ses commentaires.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Annuler'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                ),
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                        await ProjectTaskService().deleteTask(
                          taskId: task.id,
                          clientId: clientId,
                        );
                        onChanged();
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Supprimer'),
                    ),
                  ),
                ],
              ),
            ],
            if (!isClient && task.status == 'a_faire')
              _ActionButton(
                label: 'Accepter la tâche',
                icon: Icons.play_arrow_rounded,
                onPressed: () async {
                  await ProjectTaskService().acceptTask(
                    taskId: task.id,
                    freelancerId: freelancerId,
                  );
                  onChanged();
                },
              ),
            if (!isClient &&
                (task.status == 'en_cours' ||
                    task.status == 'refusee' ||
                    task.status == 'a_valider'))
              _ActionButton(
                label: task.status == 'a_valider'
                    ? 'Modifier la soumission'
                    : task.status == 'refusee'
                    ? 'Soumettre une nouvelle version'
                    : 'Soumettre le travail',
                icon: task.status == 'a_valider'
                    ? Icons.edit_outlined
                    : task.status == 'refusee'
                    ? Icons.refresh_rounded
                    : Icons.upload_file_outlined,
                onPressed: () async {
                  final ok = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => SubmitTaskScreen(
                        taskId: task.id,
                        freelancerId: freelancerId,
                        dueDate: task.dueDate,
                        existingTask: task,
                      ),
                    ),
                  );
                  if (ok == true) onChanged();
                },
              ),
            if (isClient && task.status == 'a_valider')
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Valider',
                      icon: Icons.check_circle_outline,
                      onPressed: () => _review(context, true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: 'Refuser',
                      icon: Icons.replay_outlined,
                      onPressed: () => _review(context, false),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _priorityLabel(String value) => switch (value) {
    'basse' => 'Basse',
    'haute' => 'Haute',
    'urgente' => 'Urgente',
    _ => 'Normale',
  };

  bool get _hasSubmission =>
      task.status == 'a_valider' ||
      task.status == 'validee' ||
      task.status == 'refusee' ||
      task.workDescription?.trim().isNotEmpty == true ||
      task.workLink?.trim().isNotEmpty == true ||
      task.workAttachmentName != null;

  Color _priorityColor(String value) => switch (value) {
    'urgente' => AppColors.error,
    'haute' => Colors.orangeAccent,
    'basse' => AppColors.cyan,
    _ => AppColors.textMuted,
  };

  String _date(String value) {
    final date = DateTime.tryParse(value);
    return date == null
        ? value
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _review(BuildContext context, bool accepted) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewTaskDialog(accepted: accepted),
    );
    if (note == null) return;
    await ProjectTaskService().reviewTask(
      taskId: task.id,
      clientId: clientId,
      accepted: accepted,
      note: note,
    );
    onChanged();
  }
}

class _TaskMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TaskMetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.24)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class TaskDetailsScreen extends StatelessWidget {
  final ProjectTask task;
  final bool isClient;

  const TaskDetailsScreen({
    super.key,
    required this.task,
    required this.isClient,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubmission =
        task.workDescription?.trim().isNotEmpty == true ||
        task.workLink?.trim().isNotEmpty == true ||
        task.workAttachmentName != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Détails de la tâche')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            task.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TaskStatusBadge(task.status),
              const SizedBox(width: 8),
              Text(
                'Priorité ${_priorityLabel(task.priority)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          if (task.dueDate != null) ...[
            const SizedBox(height: 12),
            _DetailLine(
              icon: Icons.event_outlined,
              label: 'Échéance',
              value: _date(task.dueDate!),
            ),
          ],
          const SizedBox(height: 20),
          _Section(
            title: 'Description',
            icon: Icons.description_outlined,
            child: Text(
              task.description.isEmpty
                  ? 'Aucune description.'
                  : task.description,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          if (task.driveUrl != null || task.githubUrl != null) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Ressources',
              icon: Icons.link_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.driveUrl != null)
                    _ResourceLink(
                      label: 'Ouvrir Google Drive',
                      url: task.driveUrl!,
                    ),
                  if (task.githubUrl != null)
                    _ResourceLink(
                      label: 'Ouvrir le dépôt GitHub',
                      url: task.githubUrl!,
                    ),
                  if (task.attachmentName != null)
                    _DownloadButton(
                      label: task.attachmentName!,
                      onPressed: () => _download(context, task, work: false),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Section(
            title: 'Travail soumis',
            icon: Icons.upload_file_outlined,
            child: !hasSubmission
                ? const Text(
                    'Aucun travail soumis pour le moment.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.workDescription?.trim().isNotEmpty == true)
                        Text(task.workDescription!),
                      if (task.workLink?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        _ResourceLink(
                          label: 'Ouvrir le lien du travail',
                          url: task.workLink!,
                        ),
                      ],
                      if (task.workAttachmentName != null)
                        _DownloadButton(
                          label: task.workAttachmentName!,
                          onPressed: () => _download(context, task, work: true),
                        ),
                      if (task.reviewNote?.trim().isNotEmpty == true) ...[
                        const Divider(height: 24),
                        Text(
                          isClient ? 'Votre note de revue' : 'Note du client',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(task.reviewNote!),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _download(
    BuildContext context,
    ProjectTask task, {
    required bool work,
  }) async {
    try {
      final service = ProjectTaskService();
      if (work) {
        await service.downloadWorkAttachment(task);
      } else {
        await service.downloadAttachment(task);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier prêt à être enregistré.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Téléchargement impossible : $error')),
        );
      }
    }
  }

  String _priorityLabel(String value) => switch (value) {
    'basse' => 'Basse',
    'haute' => 'Haute',
    'urgente' => 'Urgente',
    _ => 'Normale',
  };

  String _date(String value) {
    final date = DateTime.tryParse(value);
    return date == null
        ? value
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.fieldBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.cyan),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.textMuted),
      const SizedBox(width: 8),
      Text('$label : ', style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(value, style: const TextStyle(color: AppColors.textSecondary)),
    ],
  );
}

class _DownloadButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DownloadButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.download_outlined),
      label: Text(label),
    ),
  );
}

class _ResourceLink extends StatelessWidget {
  final String label;
  final String url;

  const _ResourceLink({required this.label, required this.url});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => _openResource(context, url),
    icon: const Icon(Icons.open_in_new_rounded, size: 18),
    label: Text(label),
  );
}

Future<void> _openResource(BuildContext context, String value) async {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Lien invalide.')));
    return;
  }
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir ce lien.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lien inaccessible : $error')));
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
    ),
  );
}

class SubmitTaskScreen extends StatefulWidget {
  final int taskId;
  final int freelancerId;
  final String? dueDate;
  final ProjectTask? existingTask;

  const SubmitTaskScreen({
    super.key,
    required this.taskId,
    required this.freelancerId,
    this.dueDate,
    this.existingTask,
  });

  @override
  State<SubmitTaskScreen> createState() => _SubmitTaskScreenState();
}

class _SubmitTaskScreenState extends State<SubmitTaskScreen> {
  final _description = TextEditingController();
  final _link = TextEditingController();
  PlatformFile? _file;
  bool _sending = false;
  bool _showValidation = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTask;
    if (existing != null) {
      _description.text = existing.workDescription ?? '';
      _link.text = existing.workLink ?? '';
    }
  }

  bool get _deadlinePassed {
    final dueDate = DateTime.tryParse(widget.dueDate ?? '');
    if (dueDate == null) return false;
    final deadlineEnd = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      23,
      59,
      59,
      999,
    );
    return DateTime.now().isAfter(deadlineEnd);
  }

  @override
  void dispose() {
    _description.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soumettre le travail')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text(
              'Présente ton travail au client',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoute une description, un lien ou un fichier ZIP. '
              'Le client pourra ensuite valider ou demander des corrections.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
            if (_deadlinePassed) ...[
              const SizedBox(height: 16),
              const _DeadlineWarning(),
            ],
            const SizedBox(height: 28),
            TextField(
              controller: _description,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_showValidation) setState(() {});
              },
              decoration: InputDecoration(
                labelText: 'Description du travail réalisé',
                hintText:
                    'Explique ce que tu as réalisé et les éléments livrés.',
                alignLabelWithHint: true,
                errorText:
                    _showValidation && _description.text.trim().length < 30
                    ? 'Minimum 30 caractères'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              onChanged: (_) {
                if (_showValidation) setState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'Lien GitHub, Google Drive ou démo',
                prefixIcon: Icon(Icons.link_outlined),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _sending
                  ? null
                  : () async {
                      final files = await FilePicker.pickFiles();
                      if (files.isNotEmpty) setState(() => _file = files.first);
                    },
              icon: const Icon(Icons.folder_zip_outlined),
              label: Text(
                _file?.name ??
                    widget.existingTask?.workAttachmentName ??
                    'Joindre un fichier ZIP',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            if (_showValidation &&
                _link.text.trim().isEmpty &&
                _file == null &&
                widget.existingTask?.workAttachmentBytes == null) ...[
              const SizedBox(height: 6),
              const Text(
                'Ajoute au moins un lien ou un fichier.',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _sending || _deadlinePassed ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Envoyer au client'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final descriptionLength = _description.text.trim().length;
    final hasLink = _link.text.trim().isNotEmpty;
    final hasFile =
        _file != null ||
        (widget.existingTask?.workAttachmentName?.trim().isNotEmpty == true &&
            widget.existingTask?.workAttachmentBytes?.isNotEmpty == true);
    if (descriptionLength < 30 || (!hasLink && !hasFile)) {
      setState(() => _showValidation = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La description doit contenir au moins 30 caractères et ajoute un lien ou un fichier.',
          ),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await ProjectTaskService().submitTask(
        taskId: widget.taskId,
        freelancerId: widget.freelancerId,
        description: _description.text,
        link: _link.text,
        attachmentName: _file?.name ?? widget.existingTask?.workAttachmentName,
        attachmentMime:
            _file?.extension ?? widget.existingTask?.workAttachmentMime,
        attachmentBytes: _file == null
            ? widget.existingTask?.workAttachmentBytes
            : await _file!.xFile.readAsBytes(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Soumission impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _DeadlineWarning extends StatelessWidget {
  const _DeadlineWarning();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.error),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Vous ne respectez pas la date limite. '
            'La soumission n’est plus possible.',
            style: TextStyle(color: AppColors.error, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _ReviewTaskDialog extends StatefulWidget {
  final bool accepted;

  const _ReviewTaskDialog({required this.accepted});

  @override
  State<_ReviewTaskDialog> createState() => _ReviewTaskDialogState();
}

class _ReviewTaskDialogState extends State<_ReviewTaskDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.accepted ? 'Valider le travail' : 'Refuser le travail'),
    content: TextField(
      controller: _note,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: widget.accepted
            ? 'Message de remerciement'
            : 'Note pour le freelancer',
        hintText: widget.accepted
            ? 'Merci pour ce travail...'
            : 'Indique les corrections à faire...',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (_note.text.trim().isNotEmpty) {
            Navigator.pop(context, _note.text.trim());
          }
        },
        child: Text(widget.accepted ? 'Valider' : 'Refuser'),
      ),
    ],
  );
}

class ProjectTaskEditorScreen extends StatefulWidget {
  final int projectId;
  final int clientId;
  final ProjectTask? existing;

  const ProjectTaskEditorScreen({
    super.key,
    required this.projectId,
    required this.clientId,
    this.existing,
  });

  @override
  State<ProjectTaskEditorScreen> createState() =>
      _ProjectTaskEditorScreenState();
}

class _ProjectTaskEditorScreenState extends State<ProjectTaskEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _drive;
  late final TextEditingController _github;
  String _priority = 'normale';
  DateTime? _deadline;
  PlatformFile? _file;
  late String? _attachmentName;
  late String? _attachmentMime;
  late List<int>? _attachmentBytes;
  bool _saving = false;
  bool _showValidation = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final task = widget.existing;
    _title = TextEditingController(text: task?.title);
    _description = TextEditingController(text: task?.description);
    _drive = TextEditingController(text: task?.driveUrl);
    _github = TextEditingController(text: task?.githubUrl);
    _priority = task?.priority ?? 'normale';
    _deadline = task?.dueDate == null
        ? null
        : DateTime.tryParse(task!.dueDate!);
    _attachmentName = task?.attachmentName;
    _attachmentMime = task?.attachmentMime;
    _attachmentBytes = task?.attachmentBytes;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _drive.dispose();
    _github.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    final result = await FilePicker.pickFiles();
    if (result.isNotEmpty) {
      setState(() => _file = result.first);
    }
  }

  Future<void> _save() async {
    final titleLength = _title.text.trim().length;
    final descriptionLength = _description.text.trim().length;
    final hasLink =
        _drive.text.trim().isNotEmpty || _github.text.trim().isNotEmpty;
    final hasFile =
        _file != null ||
        (_attachmentName?.trim().isNotEmpty == true &&
            _attachmentBytes?.isNotEmpty == true);
    if (titleLength < 8 || descriptionLength < 30 || (!hasLink && !hasFile)) {
      setState(() => _showValidation = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ajoute au moins un lien ou un fichier comme ressource.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = _file == null
          ? _attachmentBytes
          : await _file!.xFile.readAsBytes();
      final values = {
        'projectId': widget.projectId,
        'clientId': widget.clientId,
        'title': _title.text,
        'description': _description.text,
        'priority': _priority,
        'dueDate': _deadline?.toIso8601String(),
        'driveUrl': _drive.text,
        'githubUrl': _github.text,
        'attachmentName': _file?.name ?? _attachmentName,
        'attachmentMime': _file?.extension ?? _attachmentMime,
        'attachmentBytes': bytes,
      };
      if (_editing) {
        await ProjectTaskService().updateTask(
          taskId: widget.existing!.id,
          title: values['title'] as String,
          description: values['description'] as String,
          priority: values['priority'] as String,
          dueDate: values['dueDate'] as String?,
          driveUrl: values['driveUrl'] as String?,
          githubUrl: values['githubUrl'] as String?,
          attachmentName: values['attachmentName'] as String?,
          attachmentMime: values['attachmentMime'] as String?,
          attachmentBytes: values['attachmentBytes'] as List<int>?,
          clientId: widget.clientId,
        );
      } else {
        await ProjectTaskService().createTask(
          projectId: values['projectId'] as int,
          clientId: values['clientId'] as int,
          title: values['title'] as String,
          description: values['description'] as String,
          priority: values['priority'] as String,
          dueDate: values['dueDate'] as String?,
          driveUrl: values['driveUrl'] as String?,
          githubUrl: values['githubUrl'] as String?,
          attachmentName: values['attachmentName'] as String?,
          attachmentMime: values['attachmentMime'] as String?,
          attachmentBytes: values['attachmentBytes'] as List<int>?,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enregistrement impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifier la tâche' : 'Nouvelle tâche'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              _editing
                  ? 'Mets à jour les informations de cette tâche.'
                  : 'Décris clairement le travail à réaliser.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Informations principales',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_showValidation) setState(() {});
              },
              decoration: InputDecoration(
                labelText: 'Titre de la tâche',
                hintText: 'Ex. Préparer la maquette de la page d’accueil',
                errorText: _showValidation && _title.text.trim().length < 8
                    ? 'Minimum 8 caractères'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 5,
              onChanged: (_) {
                if (_showValidation) setState(() {});
              },
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Explique les objectifs et le résultat attendu',
                errorText:
                    _showValidation && _description.text.trim().length < 30
                    ? 'Minimum 30 caractères'
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Planification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priorité'),
              items: const [
                DropdownMenuItem(value: 'basse', child: Text('Basse')),
                DropdownMenuItem(value: 'normale', child: Text('Normale')),
                DropdownMenuItem(value: 'haute', child: Text('Haute')),
                DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
              ],
              onChanged: (value) => setState(() => _priority = value!),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              tileColor: AppColors.fieldFill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                _deadline == null
                    ? 'Ajouter une échéance'
                    : 'Échéance : ${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
              ),
              leading: const Icon(Icons.event_outlined),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                  initialDate: DateTime.now(),
                );
                if (date != null) setState(() => _deadline = date);
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Ressources',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _drive,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Lien Google Drive',
                prefixIcon: Icon(Icons.cloud_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _github,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Lien GitHub',
                prefixIcon: Icon(Icons.code_outlined),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _chooseFile,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _file?.name ?? _attachmentName ?? 'Joindre un fichier',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (_showValidation &&
                _drive.text.trim().isEmpty &&
                _github.text.trim().isEmpty &&
                _file == null &&
                (_attachmentName == null || _attachmentBytes == null)) ...[
              const SizedBox(height: 6),
              const Text(
                'Ajoute au moins un lien ou un fichier.',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _editing ? 'Enregistrer les modifications' : 'Créer la tâche',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'en_cours' => 'En cours',
      'en_pause' => 'En pause',
      'termine' => 'Terminé',
      'annule' => 'Annulé',
      _ => status,
    };
    final color = status == 'termine'
        ? AppColors.cyan
        : status == 'annule'
        ? AppColors.error
        : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TaskStatusBadge extends StatelessWidget {
  final String status;

  const _TaskStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'en_cours' => ('En cours', AppColors.cyan, Icons.timelapse_outlined),
      'validee' => ('Terminée', AppColors.cyan, Icons.check_circle_outline),
      'a_valider' => ('À valider', AppColors.red, Icons.rate_review_outlined),
      'refusee' => ('À reprendre', AppColors.error, Icons.replay_outlined),
      _ => ('À faire', AppColors.textSecondary, Icons.circle_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 14),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
