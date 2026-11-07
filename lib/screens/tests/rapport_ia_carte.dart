import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/test_competences.dart';
import '../../services/ai/gemini_client.dart';
import '../../services/ai/rapport_test_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home_widgets.dart';

/// « Rapport de l'IA » d'un test : synthèse, points forts, points à
/// améliorer, conseils. Se replie / se déplie (choix mémorisé).
///
/// [generationAuto] : true juste après le test (le rapport est demandé à
/// l'IA tout de suite) ; false ailleurs (bouton « Générer mon rapport »).
class RapportIaCarte extends StatefulWidget {
  final int tentativeId;
  final int freelancerId;
  final bool generationAuto;
  final RapportTestService? service; // remplaçable dans les tests

  const RapportIaCarte({
    super.key,
    required this.tentativeId,
    required this.freelancerId,
    this.generationAuto = false,
    this.service,
  });

  @override
  State<RapportIaCarte> createState() => _RapportIaCarteState();
}

enum _Etape { chargement, absent, generation, pret, erreur }

class _RapportIaCarteState extends State<RapportIaCarte> {
  static const _cleVisible = 'rapport_ia_visible';
  static const _violet = Color(0xFFB794F6);

  late final RapportTestService _service =
      widget.service ?? RapportTestService();
  _Etape _etape = _Etape.chargement;
  RapportTest? _rapport;
  String _erreur = '';
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _visible = prefs.getBool(_cleVisible) ?? true;
    } catch (_) {}
    final r = await _service.lire(widget.tentativeId);
    if (!mounted) return;
    if (r != null) {
      setState(() {
        _rapport = r;
        _etape = _Etape.pret;
      });
    } else if (widget.generationAuto) {
      _generer();
    } else {
      setState(() => _etape = _Etape.absent);
    }
  }

  // ---------- FONCTIONNALITÉ : demander le rapport à l'IA ----------
  Future<void> _generer() async {
    setState(() {
      _etape = _Etape.generation;
      _visible = true;
    });
    try {
      final r = await _service.obtenir(
        tentativeId: widget.tentativeId,
        freelancerId: widget.freelancerId,
      );
      if (mounted) {
        setState(() {
          _rapport = r;
          _etape = _Etape.pret;
        });
      }
    } on GeminiException catch (e) {
      _echec(e.message);
    } on RapportException catch (e) {
      _echec(e.message);
    } catch (e) {
      debugPrint('[IA] ❌ Rapport : $e');
      _echec('Le rapport n\'a pas pu être généré. Réessaie.');
    }
  }

  void _echec(String message) {
    if (!mounted) return;
    setState(() {
      _erreur = message;
      _etape = _Etape.erreur;
    });
  }

  Future<void> _basculer() async {
    setState(() => _visible = !_visible);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cleVisible, _visible);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final repliable = _etape == _Etape.pret;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x59B794F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête : titre + Afficher / Masquer
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: repliable ? _basculer : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color: _violet,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Rapport de l'IA",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (repliable)
                    TextButton.icon(
                      onPressed: _basculer,
                      icon: Icon(
                        _visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      label: Text(_visible ? 'Masquer' : 'Afficher'),
                      style: TextButton.styleFrom(foregroundColor: _violet),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !_visible && repliable
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _contenu(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _contenu() {
    switch (_etape) {
      case _Etape.chargement:
        return const SizedBox(height: 8);
      case _Etape.generation:
        return const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _violet),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "L'IA analyse tes réponses…",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        );
      case _Etape.absent:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Obtiens l'analyse de tes réponses : points forts, points à "
              'améliorer et conseils. Connexion Internet nécessaire.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _generer,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Générer mon rapport'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _violet,
                side: const BorderSide(color: Color(0x80B794F6)),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        );
      case _Etape.erreur:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _erreur,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _generer,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
              style: TextButton.styleFrom(foregroundColor: _violet),
            ),
          ],
        );
      case _Etape.pret:
        final r = _rapport!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.synthese,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.label,
              ),
            ),
            if (r.pointsForts.isNotEmpty)
              _Rubrique(
                titre: 'Points forts',
                icone: Icons.check_circle_rounded,
                couleur: AppColors.cyan,
                points: r.pointsForts,
              ),
            if (r.pointsFaibles.isNotEmpty)
              _Rubrique(
                titre: 'Points à améliorer',
                icone: Icons.trending_up_rounded,
                couleur: const Color(0xFFFFB86B),
                points: r.pointsFaibles,
              ),
            _Rubrique(
              titre: 'Conseils',
              icone: Icons.lightbulb_outline_rounded,
              couleur: _violet,
              points: r.conseils,
            ),
            const SizedBox(height: 12),
            Text(
              'Analyse générée par IA le '
              '${formatDate(DateTime.parse(r.dateCreation))}, à titre indicatif.',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        );
    }
  }
}

class _Rubrique extends StatelessWidget {
  final String titre;
  final IconData icone;
  final Color couleur;
  final List<String> points;
  const _Rubrique({
    required this.titre,
    required this.icone,
    required this.couleur,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: couleur,
            ),
          ),
          const SizedBox(height: 6),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(icone, size: 16, color: couleur),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(fontSize: 13.5, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
