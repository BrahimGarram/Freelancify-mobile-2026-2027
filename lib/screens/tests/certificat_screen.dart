import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/test_competences.dart';
import '../../services/certificat_pdf.dart';
import 'rapport_ia_carte.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/home_widgets.dart';

/// Le certificat délivré par « freelance » (nom, score, compétences…),
/// téléchargeable en PDF.
class CertificatScreen extends StatefulWidget {
  final Certification certification;

  /// Rapport de l'IA : visible seulement par le freelancer lui-même
  final bool afficherRapport;

  const CertificatScreen({
    super.key,
    required this.certification,
    this.afficherRapport = false,
  });

  @override
  State<CertificatScreen> createState() => _CertificatScreenState();
}

class _CertificatScreenState extends State<CertificatScreen> {
  bool _telechargement = false;

  Certification get _c => widget.certification;

  // ---------- FONCTIONNALITÉ : télécharger le certificat (PDF) ----------
  Future<void> _telecharger() async {
    setState(() => _telechargement = true);
    try {
      final chemin = await CertificatPdf.telecharger(_c);
      debugPrint('[PDF] ✅ Certificat enregistré : $chemin');
      if (!mounted) return;
      final dossier = chemin.contains('/Download/')
          ? 'Téléchargements'
          : "le dossier de l'application";
      showAppMessage(
        context,
        'Certificat enregistré dans $dossier : ${CertificatPdf.nomFichier(_c)}',
      );
    } catch (e) {
      debugPrint('[PDF] ❌ Téléchargement impossible : $e');
      if (mounted) {
        showAppMessage(context, 'Téléchargement impossible', error: true);
      }
    } finally {
      if (mounted) setState(() => _telechargement = false);
    }
  }

  Future<void> _partager() async {
    try {
      await CertificatPdf.partager(_c);
    } catch (e) {
      debugPrint('[PDF] ❌ Partage impossible : $e');
      if (mounted) showAppMessage(context, 'Partage impossible', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Certification',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Partager',
            onPressed: _partager,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              CarteCertificat(certification: _c),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Télécharger le PDF',
                loading: _telechargement,
                onPressed: _telecharger,
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _partager,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Partager / imprimer'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _c.numero));
                      if (context.mounted) {
                        showAppMessage(context, 'Numéro du certificat copié');
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text('Copier le n° ${_c.numero}'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.cyan,
                    ),
                  ),
                ],
              ),
              if (widget.afficherRapport) ...[
                const SizedBox(height: 14),
                RapportIaCarte(
                  tentativeId: _c.tentativeId,
                  freelancerId: _c.freelancerId,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Le visuel du certificat (réutilisable)
class CarteCertificat extends StatelessWidget {
  final Certification certification;
  const CarteCertificat({super.key, required this.certification});

  static const _or = Color(0xFFE9C46A);

  @override
  Widget build(BuildContext context) {
    final c = certification;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [AppColors.cyan, _or, AppColors.red],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0B),
          borderRadius: BorderRadius.circular(23),
        ),
        child: Column(
          children: [
            const FittedBox(fit: BoxFit.scaleDown, child: AppLogo()),
            const SizedBox(height: 18),
            const Icon(Icons.workspace_premium_rounded, size: 46, color: _or),
            const SizedBox(height: 8),
            const Text(
              'CERTIFICAT DE COMPÉTENCES',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: _or,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Décerné à',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              '@${c.nomFreelancer}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            if (c.metier != null) ...[
              const SizedBox(height: 2),
              Text(
                c.metier!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cyan,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'pour avoir réussi le test de compétences en\n'
              '${c.domainesLisibles}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.label,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Valeur(
                    titre: 'Score',
                    valeur: '${c.score}/${c.total}',
                  ),
                ),
                Expanded(
                  child: _Valeur(
                    titre: 'Réussite',
                    valeur: '${c.pourcentage} %',
                  ),
                ),
                Expanded(
                  child: _Valeur(titre: 'Mention', valeur: c.mention),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text(
                    'Compétences validées',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.competences,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: AppColors.fieldBorder),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Délivré le ${formatDate(DateTime.parse(c.dateObtention))}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'N° ${c.numero}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'freelance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      "L'équipe freelance",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Valeur extends StatelessWidget {
  final String titre;
  final String valeur;
  const _Valeur({required this.titre, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          titre,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            valeur,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
