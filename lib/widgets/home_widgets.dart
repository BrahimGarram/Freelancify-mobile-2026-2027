import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/post_options.dart';
import '../models/user.dart';
import '../screens/assistant/assistant_screen.dart';
import 'cloche_notifications.dart';
import '../theme/app_theme.dart';

// ======================= Petites fonctions utiles =======================

/// "il y a 2 h", "hier", "il y a 3 j"… à partir d'une date ISO
String tempsEcoule(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  final d = DateTime.now().difference(date);
  if (d.inMinutes < 1) return "à l'instant";
  if (d.inMinutes < 60) return 'il y a ${d.inMinutes} min';
  if (d.inHours < 24) return 'il y a ${d.inHours} h';
  if (d.inDays == 1) return 'hier';
  if (d.inDays < 30) return 'il y a ${d.inDays} j';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// 150.0 → "150 DT" ; 99.5 → "99.50 DT" ; horaire → "15 DT/h"
String formatBudget(double budget, {bool horaire = false}) {
  final texte = budget == budget.roundToDouble()
      ? budget.toStringAsFixed(0)
      : budget.toStringAsFixed(2);
  return horaire ? '$texte DT/h' : '$texte DT';
}

const _moisCourts = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// DateTime → "15 déc. 2026"
String formatDate(DateTime date) =>
    '${date.day} ${_moisCourts[date.month - 1]} ${date.year}';

/// "2026-12-15" → "15 déc." (+ l'année si ce n'est pas l'année en cours)
String formatDateLimite(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  final base = '${date.day} ${_moisCourts[date.month - 1]}';
  return date.year == DateTime.now().year ? base : '$base ${date.year}';
}

/// Icônes des catégories et des modes de travail
const iconesCategories = {
  'design': Icons.palette_outlined,
  'dev': Icons.code_rounded,
  'video': Icons.movie_outlined,
  'photo': Icons.photo_camera_outlined,
  'redaction': Icons.edit_note_rounded,
  'marketing': Icons.campaign_outlined,
  'traduction': Icons.translate_rounded,
  'autre': Icons.more_horiz_rounded,
};

const iconesModes = {
  'distance': Icons.laptop_mac_outlined,
  'sur_place': Icons.place_outlined,
  'hybride': Icons.sync_alt_rounded,
};

// ======================= Widgets partagés =======================

/// Statut d'une candidature : En attente / Acceptée / Refusée
class StatutCandidatureChip extends StatelessWidget {
  final String statut;
  const StatutCandidatureChip({super.key, required this.statut});

  @override
  Widget build(BuildContext context) {
    final couleur = switch (statut) {
      'acceptee' => AppColors.cyan,
      'refusee' => AppColors.error,
      _ => AppColors.label,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: couleur.withValues(alpha: 0.6)),
      ),
      child: Text(
        PostOptions.statutsCandidature[statut] ?? statut,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: couleur,
        ),
      ),
    );
  }
}

/// Demande confirmation avant d'accepter / refuser une candidature.
Future<bool> confirmerDecision(
  BuildContext context, {
  required bool accepter,
  required String freelancer,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        accepter ? 'Accepter @$freelancer ?' : 'Refuser @$freelancer ?',
      ),
      content: Text(
        accepter
            ? 'Le post passera « En cours » et les autres candidatures '
                  'pour ce post seront refusées.'
            : 'La discussion avec ce freelancer sera fermée.',
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
          style: TextButton.styleFrom(
            foregroundColor: accepter ? AppColors.cyan : AppColors.red,
          ),
          child: Text(accepter ? 'Accepter' : 'Refuser'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Badge rouge « Urgent »
class UrgentBadge extends StatelessWidget {
  const UrgentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 13, color: Colors.white),
          SizedBox(width: 2),
          Text(
            'Urgent',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Infos d'un post : catégorie, lieu, date limite (+ compétences)
class PostInfos extends StatelessWidget {
  final Post post;
  final bool avecCompetences;
  const PostInfos({super.key, required this.post, this.avecCompetences = true});

  @override
  Widget build(BuildContext context) {
    final lieu = post.ville == null
        ? PostOptions.modesTravail[post.modeTravail] ?? ''
        : '${PostOptions.modesTravail[post.modeTravail]} · ${post.ville}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final c in post.categories)
              _Info(
                iconesCategories[c] ?? Icons.more_horiz_rounded,
                PostOptions.categories[c] ?? 'Autre',
              ),
            _Info(iconesModes[post.modeTravail] ?? Icons.place_outlined, lieu),
            if (post.dateLimite != null)
              _Info(
                Icons.event_outlined,
                'Avant le ${formatDateLimite(post.dateLimite!)}',
              ),
          ],
        ),
        if (avecCompetences && post.competences.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in post.competences)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1425F4EE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    c,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cyan,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String texte;
  const _Info(this.icon, this.texte);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          texte,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Rond avec l'initiale. Client = rouge, Freelancer = cyan.
class UserAvatar extends StatelessWidget {
  final String name;
  final bool isClient;
  final double size;
  final bool withShadow; // ombre décalée "glitch"

  const UserAvatar({
    super.key,
    required this.name,
    required this.isClient,
    this.size = 44,
    this.withShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final initiale = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isClient ? AppColors.red : AppColors.cyan,
        boxShadow: withShadow
            ? [
                BoxShadow(
                  color: isClient ? AppColors.cyan : AppColors.red,
                  offset: isClient ? const Offset(-3, -1) : const Offset(3, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        initiale,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: isClient ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}

/// En-tête des pages d'accueil : "Salut xxx" + titre + avatar
class HomeHeader extends StatelessWidget {
  final User user;
  final String title;

  /// Appelé au retour de l'écran des notifications (freelancer)
  final VoidCallback? apresNotifications;

  const HomeHeader({
    super.key,
    required this.user,
    required this.title,
    this.apresNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Salut ${user.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              // le titre rétrécit si l'écran est trop étroit
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // l'assistant IA, accessible depuis chaque onglet
        IconButton(
          tooltip: 'Assistant',
          onPressed: () => ouvrirAssistant(context, user: user),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.fieldFill,
            side: const BorderSide(color: Color(0x5925F4EE)),
            fixedSize: const Size(44, 44),
          ),
          icon: const Icon(
            Icons.auto_awesome_rounded,
            size: 20,
            color: AppColors.cyan,
          ),
        ),
        if (user.isFreelancer) ...[
          const SizedBox(width: 8),
          ClocheNotifications(user: user, apresFermeture: apresNotifications),
        ],
        const SizedBox(width: 10),
        UserAvatar(name: user.username, isClient: user.role == 'client'),
      ],
    );
  }
}

/// Petite carte chiffre + libellé (ex : "3 Posts ouverts")
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Le budget en pastille rose
class BudgetChip extends StatelessWidget {
  final double budget;
  final bool horaire;
  const BudgetChip({super.key, required this.budget, this.horaire = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x26EE1D52),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        formatBudget(budget, horaire: horaire),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFF5C82),
        ),
      ),
    );
  }
}

/// Message quand une liste est vide
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Onglet vide, à remplir plus tard (Candidatures, Messages…)
class PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderTab({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const Spacer(),
            Center(
              child: EmptyState(
                icon: icon,
                title: 'Bientôt disponible',
                message: 'Cette section est en cours de construction.',
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

// ======================= Barre de navigation du bas =======================

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

/// Barre du bas. Si [onPlus] est donné, le bouton "+" style TikTok
/// est inséré à la position [plusPosition].
class AppBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onPlus;
  final int plusPosition;

  /// Pastille sur un onglet : {index de l'onglet: nombre} (0 = rien)
  final Map<int, int> badges;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onPlus,
    this.plusPosition = 2,
    this.badges = const {},
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (onPlus != null && i == plusPosition) {
        children.add(
          Expanded(
            child: Center(child: _PlusButton(onTap: onPlus!)),
          ),
        );
      }
      children.add(
        Expanded(
          child: _NavButton(
            item: items[i],
            badge: badges[i] ?? 0,
            selected: i == currentIndex,
            onTap: () => onTap(i),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.fieldBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(height: 64, child: Row(children: children)),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    this.badge = 0,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text(badge > 99 ? '99+' : '$badge'),
            backgroundColor: AppColors.red,
            textColor: Colors.white,
            child: Icon(
              item.icon,
              size: 24,
              color: selected ? AppColors.red : AppColors.textMuted,
              semanticLabel: badge > 0 ? '$badge non lu(s)' : null,
            ),
          ),
          const SizedBox(height: 4),
          // une seule ligne, rétrécie si l'écran est étroit (« Candidatures »)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le bouton "+" façon TikTok : blanc, avec du cyan à gauche et du rouge à droite
class _PlusButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlusButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget couche(Color color, double dx) => Transform.translate(
      offset: Offset(dx, 0),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Publier un post',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 34,
          child: Stack(
            fit: StackFit.expand,
            children: [
              couche(AppColors.cyan, -4),
              couche(AppColors.red, 4),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
