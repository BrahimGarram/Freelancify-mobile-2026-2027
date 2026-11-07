import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/post.dart';
import '../../models/post_options.dart';
import '../../models/user.dart';
import '../../services/ai/gemini_client.dart';
import '../../services/ai/post_ia_service.dart';
import '../../services/abonnement_service.dart';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/home_widgets.dart';

/// Formulaire pour que le Client publie un nouveau post.
/// Renvoie true à la page précédente si le post a été publié.
class PublierPostScreen extends StatefulWidget {
  final User user;

  /// Aide IA (remplaçable dans les tests)
  final PostIaService? ia;

  const PublierPostScreen({super.key, required this.user, this.ia});

  @override
  State<PublierPostScreen> createState() => _PublierPostScreenState();
}

class _PublierPostScreenState extends State<PublierPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetFieldKey = GlobalKey<FormFieldState<String>>();
  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _postService = PostService();
  late final PostIaService _ia = widget.ia ?? PostIaService();
  final _demandeKey = GlobalKey<FormState>();
  final _demandeController = TextEditingController();
  bool _iaLoading = false;
  BrouillonPost? _brouillon; // dernier remplissage par l'IA
  int _version = 0; // change → les champs à choix se recréent avec l'IA

  List<String> _categories = [];
  String _typeBudget = 'fixe';
  DateTime? _dateLimite;
  String _modeTravail = 'distance';
  String? _ville;
  List<String> _competences = [];
  bool _urgent = false;
  bool _loading = false;

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _demandeController.dispose();
    super.dispose();
  }

  // ---------- FONCTIONNALITÉ : remplir le post avec l'IA ----------
  Future<void> _remplirAvecIa() async {
    FocusScope.of(context).unfocus();
    if (!_demandeKey.currentState!.validate()) return;

    // le client a déjà écrit quelque chose : on demande avant d'écraser
    final dejaRempli =
        _titreController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty;
    if (dejaRempli && !await _confirmerRemplacement()) return;

    setState(() => _iaLoading = true);
    try {
      final b = await _ia.analyser(_demandeController.text);
      if (!mounted) return;
      _appliquer(b);
    } on PostIaException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } on GeminiException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _iaLoading = false);
    }
  }

  /// Met les valeurs comprises par l'IA dans le formulaire.
  /// Une information absente de la demande ne remplace pas ce qui existe.
  void _appliquer(BrouillonPost b) {
    setState(() {
      if (b.titre != null) _titreController.text = b.titre!;
      if (b.description != null) _descriptionController.text = b.description!;
      if (b.categories.isNotEmpty) _categories = b.categories;
      if (b.typeBudget != null) _typeBudget = b.typeBudget!;
      if (b.budget != null) {
        _budgetController.text = PostIaService.formatMontant(b.budget!);
      }
      if (b.dateLimite != null) _dateLimite = b.dateLimite;
      if (b.modeTravail != null) _modeTravail = b.modeTravail!;
      if (b.ville != null) _ville = b.ville;
      if (!PostOptions.besoinVille(_modeTravail)) _ville = null;
      if (b.competences.isNotEmpty) _competences = b.competences;
      if (b.urgent) _urgent = true;
      _brouillon = b;
      _version++;
    });
    // les champs encore vides passent en rouge : le client voit tout de
    // suite ce qu'il doit compléter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _formKey.currentState?.validate();
    });
  }

  Future<bool> _confirmerRemplacement() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remplacer le contenu ?'),
        content: const Text(
          "L'IA va réécrire le titre et la description déjà saisis.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remplacer',
              style: TextStyle(
                color: AppColors.cyan,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ---------- FONCTIONNALITÉ : publier ----------
  Future<void> _publier() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      showAppMessage(
        context,
        'Corrige les champs en rouge avant de publier',
        error: true,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final dl = _dateLimite!;
      await _postService.insertPost(
        Post(
          clientId: widget.user.id!,
          titre: _titreController.text.trim(),
          description: _descriptionController.text.trim(),
          categories: _categories,
          budget: Validators.lireBudget(_budgetController.text)!,
          typeBudget: _typeBudget,
          dateLimite:
              '${dl.year}-${dl.month.toString().padLeft(2, '0')}-'
              '${dl.day.toString().padLeft(2, '0')}',
          modeTravail: _modeTravail,
          ville: PostOptions.besoinVille(_modeTravail) ? _ville : null,
          competences: _competences,
          urgent: _urgent,
          dateCreation: DateTime.now().toIso8601String(),
        ),
      );
      if (!mounted) return;
      // les abonnés ont été notifiés par le pattern Observer
      final abonnes = await AbonnementService().nbAbonnes(widget.user.id!);
      if (!mounted) return;
      showAppMessage(
        context,
        abonnes == 0
            ? 'Post publié !'
            : 'Post publié ! $abonnes freelancer${abonnes > 1 ? 's' : ''} '
                  'abonné${abonnes > 1 ? 's' : ''} notifié${abonnes > 1 ? 's' : ''}.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final horaire = _typeBudget == 'horaire';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -100,
            left: -80,
            child: Halo(size: 260, color: Color(0x1F25F4EE)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEnTete(),
                    const SizedBox(height: 22),
                    _buildAideIa(),
                    if (_brouillon != null) ...[
                      const SizedBox(height: 12),
                      _BilanIa(brouillon: _brouillon!),
                    ],
                    const SizedBox(height: 26),

                    // ---------------- L'essentiel ----------------
                    const _Section('L\'essentiel', Icons.description_outlined),
                    AppTextField(
                      label: 'Titre',
                      hint: 'Logo pour ma boulangerie',
                      controller: _titreController,
                      maxLength: Validators.titreMax,
                      validator: Validators.titre,
                    ),
                    const SizedBox(height: 16),
                    MultiChoiceChipsField(
                      key: ValueKey('categories-$_version'),
                      initialValue: _categories,
                      label: "Catégories (jusqu'à ${Validators.categoriesMax})",
                      options: PostOptions.categories,
                      icones: iconesCategories,
                      max: Validators.categoriesMax,
                      validator: Validators.categories,
                      onChanged: (v) => _categories = v,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Description',
                      hint: 'Explique le travail et ce que tu attends du freelancer…',
                      controller: _descriptionController,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      maxLength: Validators.descriptionMax,
                      validator: Validators.description,
                    ),
                    const SizedBox(height: 28),

                    // ---------------- Budget & délai ----------------
                    const _Section('Budget et délai', Icons.payments_outlined),
                    ChoiceChipsField(
                      key: ValueKey('type-budget-$_version'),
                      label: 'Type de budget',
                      options: PostOptions.typesBudget,
                      icones: const {
                        'fixe': Icons.sell_outlined,
                        'horaire': Icons.schedule_rounded,
                      },
                      initialValue: _typeBudget,
                      validator: Validators.choix(
                        PostOptions.typesBudget,
                        'Choisis un type de budget',
                      ),
                      onChanged: (v) {
                        setState(() => _typeBudget = v);
                        // la limite du budget change : on revérifie le montant
                        if (_budgetController.text.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _budgetFieldKey.currentState?.validate(),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      fieldKey: _budgetFieldKey,
                      label: horaire ? 'Taux horaire' : 'Budget total',
                      hint: horaire ? '25' : '150',
                      controller: _budgetController,
                      suffixText: horaire ? 'DT/h' : 'DT',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      // seulement des chiffres et un séparateur décimal
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) =>
                          Validators.budget(v, typeBudget: _typeBudget),
                    ),
                    const SizedBox(height: 16),
                    DateLimiteField(
                      key: ValueKey('date-$_version'),
                      initialValue: _dateLimite,
                      label: 'Date limite',
                      onChanged: (d) => _dateLimite = d,
                    ),
                    const SizedBox(height: 28),

                    // ---------------- Lieu ----------------
                    const _Section('Lieu de travail', Icons.place_outlined),
                    ChoiceChipsField(
                      key: ValueKey('mode-$_version'),
                      label: 'Mode de travail',
                      options: PostOptions.modesTravail,
                      icones: iconesModes,
                      initialValue: _modeTravail,
                      validator: Validators.choix(
                        PostOptions.modesTravail,
                        'Choisis un mode de travail',
                      ),
                      onChanged: (v) => setState(() {
                        _modeTravail = v;
                        if (!PostOptions.besoinVille(v)) _ville = null;
                      }),
                    ),
                    if (PostOptions.besoinVille(_modeTravail)) ...[
                      const SizedBox(height: 16),
                      DropdownField(
                        key: ValueKey('ville-$_version'),
                        label: 'Ville',
                        hint: 'Choisir un gouvernorat',
                        icon: Icons.location_city_outlined,
                        options: PostOptions.villes,
                        value: _ville,
                        validator: (v) => Validators.ville(v, _modeTravail),
                        onChanged: (v) => _ville = v,
                      ),
                    ],
                    const SizedBox(height: 28),

                    // ---------------- Détails ----------------
                    const _Section('Détails', Icons.tune_rounded),
                    CompetencesField(
                      key: ValueKey('competences-$_version'),
                      initialValue: _competences,
                      label: 'Compétences recherchées',
                      onChanged: (l) => _competences = l,
                    ),
                    const SizedBox(height: 16),
                    SwitchField(
                      titre: 'Mission urgente',
                      sousTitre:
                          'Un badge « Urgent » sera affiché sur ton post',
                      icon: Icons.bolt_rounded,
                      value: _urgent,
                      onChanged: (v) => setState(() => _urgent = v),
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: 'Publier le post',
                      loading: _loading,
                      onPressed: _publier,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Carte « Décris ton besoin » : l'IA remplit le formulaire
  Widget _buildAideIa() {
    final disponible = _ia.estConfigure;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x5925F4EE)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x1A25F4EE), Color(0x14EE1D52)],
        ),
      ),
      child: Form(
        key: _demandeKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: AppColors.cyan,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Remplir avec l'IA",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Décris ton besoin avec tes mots : l'IA remplit les champs et "
              'rédige la description. Tu pourras tout modifier.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Ton besoin',
              hint:
                  "Ex : j'ouvre une pâtisserie à Sousse, je veux un logo et "
                  'une carte de visite avant le 30, budget 300 DT',
              controller: _demandeController,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              maxLength: PostIaService.demandeMax,
              validator: PostIaService.validerDemande,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: disponible && !_iaLoading ? _remplirAvecIa : null,
                icon: _iaLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _iaLoading ? 'Analyse en cours…' : 'Remplir le formulaire',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0x3325F4EE),
                  disabledForegroundColor: AppColors.textMuted,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              disponible
                  ? 'Nécessite une connexion Internet.'
                  : 'Aide IA non configurée : remplis le formulaire à la main.',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnTete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Material(
              color: AppColors.fieldFill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.fieldBorder),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).pop(false),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    semanticLabel: 'Retour',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'Nouveau post',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'De quoi as-tu\nbesoin ?',
          style: TextStyle(
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Les freelancers verront ton offre dans leur fil.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Titre de section du formulaire
class _Section extends StatelessWidget {
  final String titre;
  final IconData icon;
  const _Section(this.titre, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titre,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Résumé après le remplissage par l'IA : ce que le client doit encore
/// compléter (informations absentes de sa demande).
class _BilanIa extends StatelessWidget {
  final BrouillonPost brouillon;
  const _BilanIa({required this.brouillon});

  static const _orange = Color(0xFFFFB547);

  @override
  Widget build(BuildContext context) {
    final manquants = brouillon.manquants;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: AppColors.cyan),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Formulaire rempli par l'IA : relis avant de publier",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (manquants.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: _orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Non précisé dans ta demande, à compléter : '
                    '${manquants.join(', ')}.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: _orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
