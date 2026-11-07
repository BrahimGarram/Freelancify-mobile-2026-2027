import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/post_options.dart';
import '../models/realisation.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';
import 'home_widgets.dart';

/// Photo d'une réalisation (fichier local), avec un visuel de secours
/// si le fichier n'existe plus.
class RealisationImage extends StatelessWidget {
  final String path;
  final double? height;
  final BoxFit fit;

  const RealisationImage({
    super.key,
    required this.path,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      height: height,
      width: double.infinity,
      fit: fit,
      cacheWidth: 1200, // évite de charger une photo énorme en mémoire
      semanticLabel: 'Photo de la réalisation',
      errorBuilder: (_, _, _) => Container(
        height: height ?? 160,
        color: AppColors.fieldFill,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: AppColors.textMuted,
          size: 32,
        ),
      ),
    );
  }
}

/// Carte d'une réalisation dans le portfolio
class RealisationCard extends StatelessWidget {
  final Realisation realisation;
  final VoidCallback? onDelete; // seulement pour le propriétaire

  const RealisationCard({super.key, required this.realisation, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final r = realisation;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: InkWell(
        onTap: () => afficherRealisation(context, r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.imagePath != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: RealisationImage(path: r.imagePath!),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                onDelete == null ? 16 : 4,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        iconesCategories[r.categorie] ??
                            Icons.more_horiz_rounded,
                        size: 14,
                        color: AppColors.cyan,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        PostOptions.categories[r.categorie] ?? 'Autre',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cyan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tempsEcoule(r.dateCreation),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      if (onDelete != null)
                        IconButton(
                          tooltip: 'Supprimer',
                          onPressed: onDelete,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(right: onDelete == null ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.titre,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (r.client != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Pour ${r.client}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.label,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          r.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (r.lien != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                size: 16,
                                color: AppColors.cyan,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _sansProtocole(r.lien!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.cyan,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sansProtocole(String lien) =>
    lien.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');

/// Détail complet d'une réalisation (panneau du bas)
Future<void> afficherRealisation(BuildContext context, Realisation r) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    barrierColor: const Color(0xA6000000),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: r.imagePath != null ? 0.85 : 0.6,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.fieldBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (r.imagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RealisationImage(path: r.imagePath!, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            PostOptions.categories[r.categorie] ?? 'Autre',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.cyan,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            r.titre,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (r.client != null) ...[
            const SizedBox(height: 4),
            Text(
              'Pour ${r.client}',
              style: const TextStyle(fontSize: 14, color: AppColors.label),
            ),
          ],
          const SizedBox(height: 12),
          SelectableText(
            r.description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (r.lien != null) ...[
            const SizedBox(height: 16),
            Material(
              color: AppColors.fieldFill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.fieldBorder),
              ),
              child: ListTile(
                leading: const Icon(Icons.link_rounded, color: AppColors.cyan),
                title: Text(
                  _sansProtocole(r.lien!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: AppColors.cyan),
                ),
                trailing: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                // copie le lien (l'app fonctionne hors connexion)
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: r.lien!));
                  if (ctx.mounted) showAppMessage(ctx, 'Lien copié');
                },
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
