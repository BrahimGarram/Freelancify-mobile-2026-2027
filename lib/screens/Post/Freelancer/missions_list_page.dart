import 'package:esprit/screens/Post/Client/CreateMissionPage.dart';
import 'package:flutter/material.dart';

import '../../LoginPage.dart' show AppColors;

/// Modèle d'une mission (à remplacer plus tard par vos données Firebase / API).
class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.company,
    required this.category,
    required this.postedAgo,
    required this.tags,
    required this.budget,
    required this.duration,
    required this.applicants,
    this.verified = false,
  });

  final String id;
  final String title;
  final String company;
  final String category;
  final String postedAgo;
  final List<String> tags;
  final String budget;
  final String duration;
  final int applicants;
  final bool verified;
}

const _sampleMissions = <Mission>[
  Mission(
    id: '1',
    title: 'Développeur Flutter',
    company: 'Société Atlas',
    category: 'Développement',
    postedAgo: 'il y a 2 h',
    tags: ['Flutter', 'Firebase', 'REST API'],
    budget: '1 200 – 1 800 TND',
    duration: '1 à 3 mois',
    applicants: 12,
    verified: true,
  ),
  Mission(
    id: '2',
    title: 'Identité visuelle et charte graphique',
    company: 'Café Medina',
    category: 'Design',
    postedAgo: 'il y a 5 h',
    tags: ['Logo', 'Illustrator'],
    budget: '400 – 600 TND',
    duration: '2 semaines',
    applicants: 3,
  ),
  Mission(
    id: '3',
    title: 'Rédacteur web SEO',
    company: 'Digitalis',
    category: 'Rédaction',
    postedAgo: 'hier',
    tags: ['SEO', 'Rédaction'],
    budget: '15 TND / article',
    duration: 'Long terme',
    applicants: 8,
    verified: true,
  ),
  Mission(
    id: '4',
    title: 'Community manager Instagram',
    company: 'Studio Nova',
    category: 'Marketing',
    postedAgo: 'il y a 2 jours',
    tags: ['Instagram', 'Canva'],
    budget: '600 TND / mois',
    duration: '3 mois +',
    applicants: 15,
  ),
  Mission(
    id: '5',
    title: 'Maquettes UI pour application mobile',
    company: 'Tunisia Pay',
    category: 'Design',
    postedAgo: 'il y a 3 jours',
    tags: ['Figma', 'UI/UX'],
    budget: '800 – 1 200 TND',
    duration: '1 mois',
    applicants: 9,
    verified: true,
  ),
];

class MissionsListPage extends StatefulWidget {
  const MissionsListPage({super.key});

  @override
  State<MissionsListPage> createState() => _MissionsListPageState();
}

class _MissionsListPageState extends State<MissionsListPage> {
  static const _categories = [
    'Toutes',
    'Développement',
    'Design',
    'Rédaction',
    'Marketing',
  ];

  String _category = 'Toutes';
  String _query = '';
  int _navIndex = 0;
  final Set<String> _saved = {};

  List<Mission> get _filtered {
    final q = _query.trim().toLowerCase();
    return _sampleMissions.where((m) {
      final okCategory = _category == 'Toutes' || m.category == _category;
      final okQuery = q.isEmpty ||
          m.title.toLowerCase().contains(q) ||
          m.company.toLowerCase().contains(q) ||
          m.tags.any((t) => t.toLowerCase().contains(q));
      return okCategory && okQuery;
    }).toList();
  }

  void _toggleSave(Mission mission) {
    setState(() {
      if (!_saved.remove(mission.id)) _saved.add(mission.id);
    });
  }

  void _openMission(Mission mission) {
    // TODO: naviguer vers la page détail / candidature de la mission
  }

  void _toClient() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateMissionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final missions = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
          // Bandeau bleu acier
          Container(
            height: topInset + 130,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _Header(
                    name: 'Amine',
                    onNotificationsTap: _toClient,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSearchBar(),
                ),
                const SizedBox(height: 16),
                _buildCategories(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${missions.length} mission${missions.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Row(
                        children: [
                          Text(
                            'Plus récentes',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: missions.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                    itemCount: missions.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final mission = missions[index];
                      return _MissionCard(
                        mission: mission,
                        saved: _saved.contains(mission.id),
                        onToggleSave: () => _toggleSave(mission),
                        onTap: () => _openMission(mission),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => setState(() => _query = value),
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Rechercher une mission',
          hintStyle: TextStyle(color: AppColors.hint, fontSize: 15),
          prefixIcon: Icon(Icons.search, color: AppColors.hint),
          suffixIcon: Icon(Icons.tune, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = _categories[index];
          final selected = label == _category;
          return GestureDetector(
            onTap: () => setState(() => _category = label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(19),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.label,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.hint,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Missions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            activeIcon: Icon(Icons.description),
            label: 'Candidatures',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

/// En-tête : salutation + cloche de notifications.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.onNotificationsTap});

  final String name;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bonjour,',
                style: TextStyle(fontSize: 14, color: Color(0xFFD6E4EB)),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onNotificationsTap,
            child: Stack(
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.notifications_none,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                Positioned(
                  top: 11,
                  right: 12,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Carte d'une mission.
class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.saved,
    required this.onToggleSave,
    required this.onTap,
  });

  final Mission mission;
  final bool saved;
  final VoidCallback onToggleSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withOpacity(0.07),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      mission.company.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mission.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                mission.company,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (mission.verified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                size: 15,
                                color: AppColors.primary,
                              ),
                            ],
                            Text(
                              ' · ${mission.postedAgo}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleSave,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      saved ? Icons.bookmark : Icons.bookmark_border,
                      color: saved ? AppColors.primary : AppColors.hint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in mission.tags) _Tag(label: tag),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mission.budget,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${mission.duration} · ${mission.applicants} candidats',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    child: const Text('POSTULER'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: AppColors.hint),
            SizedBox(height: 12),
            Text(
              'Aucune mission trouvée',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Essayez une autre recherche ou une autre catégorie.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}