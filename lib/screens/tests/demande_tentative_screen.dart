import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/test_competences.dart';
import '../../models/user.dart';
import '../../services/test_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';
import 'tests_screen.dart' show PucesDomaines;

/// Formulaire « Demander une tentative supplémentaire », accessible après
/// 3 tentatives échouées. Renvoie true si la tentative a été accordée.
class DemandeTentativeScreen extends StatefulWidget {
  final User user;
  final List<String> domaines;
  final TestService? service; // remplaçable dans les tests

  const DemandeTentativeScreen({
    super.key,
    required this.user,
    required this.domaines,
    this.service,
  });

  @override
  State<DemandeTentativeScreen> createState() => _DemandeTentativeScreenState();
}

class _DemandeTentativeScreenState extends State<DemandeTentativeScreen> {
  late final TestService _service = widget.service ?? TestService();
  final _formKey = GlobalKey<FormState>();
  final _precisionController = TextEditingController();
  final _explicationController = TextEditingController();
  final _revisionsController = TextEditingController();
  final _heuresController = TextEditingController();
  String? _motif;
  bool _engagement = false;
  bool _loading = false;

  @override
  void dispose() {
    _precisionController.dispose();
    _explicationController.dispose();
    _revisionsController.dispose();
    _heuresController.dispose();
    super.dispose();
  }

  // ---------- FONCTIONNALITÉ : envoyer la demande ----------
  Future<void> _envoyer() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      showAppMessage(context, 'Corrige les champs en rouge', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.demanderTentative(
        freelancerId: widget.user.id!,
        motif: _motif,
        precision: _precisionController.text,
        explication: _explicationController.text,
        revisions: _revisionsController.text,
        heures: _heuresController.text,
        engagement: _engagement,
      );
      if (!mounted) return;
      showAppMessage(context, 'Demande envoyée : tu as 1 nouvelle tentative.');
      Navigator.of(context).pop(true);
    } on TestException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final autre = _motif == DemandeTentative.motifAutre;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Tentative supplémentaire',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Une dernière\nchance ?',
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu as utilisé tes ${TestService.tentativesMax} tentatives. '
                  'Explique ce qui s\'est passé : une seule demande est '
                  'possible, et elle donne droit à 1 tentative de plus.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                PucesDomaines(domaines: widget.domaines),
                const SizedBox(height: 24),
                ChoiceChipsField(
                  label: 'Motif de la demande',
                  options: DemandeTentative.motifs,
                  validator: Validators.choix(
                    DemandeTentative.motifs,
                    'Choisis un motif',
                  ),
                  onChanged: (v) => setState(() => _motif = v),
                ),
                if (autre) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Précise le motif',
                    hint: 'Ex : coupure de courant',
                    icon: Icons.edit_note_rounded,
                    controller: _precisionController,
                    maxLength: Validators.precisionMotifMax,
                    validator: (v) => Validators.precisionMotif(v, _motif),
                  ),
                ],
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Que s\'est-il passé ?',
                  hint: 'Explique pourquoi tes tests n\'ont pas réussi',
                  controller: _explicationController,
                  maxLines: 4,
                  maxLength: Validators.explicationDemandeMax,
                  validator: Validators.explicationDemande,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Qu\'as-tu révisé depuis ?',
                  hint: 'Les notions travaillées, grâce au rapport de l\'IA',
                  controller: _revisionsController,
                  maxLines: 3,
                  maxLength: Validators.revisionsDemandeMax,
                  validator: Validators.revisionsDemande,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Heures de révision',
                  hint: 'Ex : 6',
                  icon: Icons.schedule_rounded,
                  controller: _heuresController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  suffixText: 'h',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: Validators.heuresRevision,
                ),
                const SizedBox(height: 16),
                CaseACocherField(
                  texte:
                      'Je m\'engage à passer ce test seul, sans aide '
                      'extérieure. Je sais que c\'est ma dernière tentative.',
                  validator: Validators.engagement,
                  onChanged: (v) => _engagement = v,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Envoyer ma demande',
                  loading: _loading,
                  onPressed: _envoyer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
