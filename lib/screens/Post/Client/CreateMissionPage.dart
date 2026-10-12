import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Fichier placé dans lib/screens/Post/ -> LoginPage.dart est un dossier plus haut.
// Si AppColors est dans lib/theme/app_colors.dart, utilisez plutôt :
// import '../../theme/app_colors.dart';
import '../../LoginPage.dart' show AppColors;

/// Type de budget d'une mission.
enum BudgetType { fixed, hourly }

/// Durée estimée d'une mission.
enum MissionDuration { lessThanMonth, oneToThree, moreThanThree }

class CreateMissionPage extends StatefulWidget {
  const CreateMissionPage({super.key});

  @override
  State<CreateMissionPage> createState() => _CreateMissionPageState();
}

class _CreateMissionPageState extends State<CreateMissionPage> {
  static const _maxSkills = 8;
  static const _categories = [
    'Développement',
    'Design',
    'Rédaction',
    'Marketing',
    'Traduction',
    'Autre',
  ];
  static const _suggestedSkills = [
    'Flutter',
    'Dart',
    'Firebase',
    'UI/UX',
    'Figma',
    'SEO',
    'Rédaction',
    'Illustrator',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();

  String? _category;
  final List<String> _skills = [];
  bool _skillsError = false;

  BudgetType _budgetType = BudgetType.fixed;
  bool _negotiable = false;
  MissionDuration _duration = MissionDuration.oneToThree;
  bool _remote = true;
  DateTime? _deadline;

  /// 'publiee' ou 'brouillon' pendant l'enregistrement, sinon null.
  String? _savingStatus;
  bool get _isSaving => _savingStatus != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _skillCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _cityCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Actions

  void _addSkill(String raw) {
    final skill = raw.trim();
    if (skill.isEmpty) return;
    final exists = _skills.any((s) => s.toLowerCase() == skill.toLowerCase());
    if (exists || _skills.length >= _maxSkills) {
      setState(() => _skillCtrl.clear());
      return;
    }
    setState(() {
      _skills.add(skill);
      _skillsError = false;
      _skillCtrl.clear();
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _publish() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _skillsError = _skills.isEmpty);
    if (!formOk || _skills.isEmpty) return;
    await _save(status: 'publiee');
  }

  Future<void> _saveDraft() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez au moins un titre pour enregistrer le brouillon.'),
        ),
      );
      return;
    }
    await _save(status: 'brouillon');
  }

  Future<void> _save({required String status}) async {
    FocusScope.of(context).unfocus();
    setState(() => _savingStatus = status);

    final payload = _buildPayload(status);

    // TODO: envoyer `payload` à Firebase / votre API.
    // Ajoutez côté serveur : id, clientId (utilisateur connecté), createdAt.
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() => _savingStatus = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'publiee'
              ? 'Mission publiée avec succès.'
              : 'Brouillon enregistré.',
        ),
      ),
    );

    if (status == 'publiee') {
      // Retourne les données à la page précédente (ex. "Mes missions").
      Navigator.of(context).pop(payload);
    }
  }

  Map<String, dynamic> _buildPayload(String status) {
    return {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'category': _category,
      'skills': List<String>.from(_skills),
      'budgetType': _budgetType == BudgetType.fixed ? 'fixed' : 'hourly',
      'budgetMin': int.tryParse(_minCtrl.text),
      'budgetMax': int.tryParse(_maxCtrl.text),
      'currency': 'TND',
      'isNegotiable': _negotiable,
      'duration': _duration.name,
      'isRemote': _remote,
      'city': _remote ? null : _cityCtrl.text.trim(),
      'deadline': _deadline?.toIso8601String(),
      'referenceUrl':
      _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim(),
      'status': status,
    };
  }

  // ------------------------------------------------------------------ Build

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildBottomBar(),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Stack(
          children: [
            // Bandeau bleu acier (défile avec la page)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + 250,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _BackButton(onTap: () => Navigator.of(context).pop()),
                          const _StatusPill(label: 'Brouillon'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Nouvelle mission',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Décrivez votre besoin pour recevoir des candidatures de qualité.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: Color(0xFFD6E4EB),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _buildCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Titre
          _LabelRow(
            label: 'Titre de la mission',
            trailing: _CharCounter(controller: _titleCtrl, max: 80),
          ),
          TextFormField(
            controller: _titleCtrl,
            maxLength: 80,
            buildCounter: _hideCounter,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(hint: 'Ex. Développeur Flutter'),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Veuillez saisir un titre';
              if (v.length < 5) return 'Titre trop court';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // ---- Catégorie
          const _LabelRow(label: 'Catégorie'),
          DropdownButtonFormField<String>(
            value: _category,
            isExpanded: true,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.hint),
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            hint: const Text(
              'Choisir une catégorie',
              style: TextStyle(color: AppColors.hint, fontSize: 15),
            ),
            decoration: _inputDecoration(),
            items: [
              for (final c in _categories)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (value) => setState(() => _category = value),
            validator: (value) =>
            value == null ? 'Veuillez choisir une catégorie' : null,
          ),
          const SizedBox(height: 18),

          // ---- Description
          _LabelRow(
            label: 'Description',
            trailing: _CharCounter(controller: _descCtrl, max: 2000),
          ),
          TextFormField(
            controller: _descCtrl,
            maxLength: 2000,
            buildCounter: _hideCounter,
            minLines: 4,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDecoration(
              hint: 'Contexte, livrables attendus, contraintes techniques…',
              helper: 'Précisez les livrables et la date de fin souhaitée.',
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Veuillez décrire la mission';
              if (v.length < 30) return 'Au moins 30 caractères';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // ---- Compétences
          _LabelRow(
            label: 'Compétences requises',
            trailing: Text(
              '${_skills.length} / $_maxSkills',
              style: const TextStyle(fontSize: 12, color: AppColors.hint),
            ),
          ),
          TextField(
            controller: _skillCtrl,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: _addSkill,
            decoration: _inputDecoration(
              hint: 'Rechercher ou ajouter une compétence',
              prefix: Icons.search,
            ).copyWith(
              suffixIcon: IconButton(
                onPressed: () => _addSkill(_skillCtrl.text),
                icon: const Icon(Icons.add_circle_outline,
                    color: AppColors.primary),
              ),
            ),
          ),
          if (_skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in _skills)
                  _SkillChip(
                    label: skill,
                    onRemove: () => setState(() => _skills.remove(skill)),
                  ),
              ],
            ),
          ],
          if (_skillsError)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Ajoutez au moins une compétence.',
                style: TextStyle(fontSize: 12.5, color: AppColors.error),
              ),
            ),
          if (_skills.length < _maxSkills && _suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Suggestions',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _suggestions)
                  GestureDetector(
                    onTap: () => _addSkill(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            s,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],

          const _SectionDivider(),

          // ---- Budget
          const _LabelRow(label: 'Type de budget'),
          _Segmented<BudgetType>(
            value: _budgetType,
            options: const {
              BudgetType.fixed: 'Prix fixe',
              BudgetType.hourly: 'Taux horaire',
            },
            onChanged: (v) => setState(() => _budgetType = v),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LabelRow(label: 'Minimum'),
                    TextFormField(
                      controller: _minCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(hint: '1200').copyWith(
                        suffixText:
                        _budgetType == BudgetType.fixed ? 'TND' : 'TND/h',
                        suffixStyle: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      validator: (value) {
                        final n = int.tryParse(value ?? '');
                        if (n == null) return 'Requis';
                        if (n <= 0) return 'Invalide';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LabelRow(label: 'Maximum'),
                    TextFormField(
                      controller: _maxCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(hint: '1800').copyWith(
                        suffixText:
                        _budgetType == BudgetType.fixed ? 'TND' : 'TND/h',
                        suffixStyle: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      validator: (value) {
                        final max = int.tryParse(value ?? '');
                        if (max == null) return 'Requis';
                        final min = int.tryParse(_minCtrl.text);
                        if (min != null && max < min) return '≥ minimum';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CheckRow(
            label: 'Budget négociable',
            value: _negotiable,
            onChanged: (v) => setState(() => _negotiable = v),
          ),

          const _SectionDivider(),

          // ---- Durée
          const _LabelRow(label: 'Durée estimée'),
          _Segmented<MissionDuration>(
            value: _duration,
            options: const {
              MissionDuration.lessThanMonth: '< 1 mois',
              MissionDuration.oneToThree: '1 à 3 mois',
              MissionDuration.moreThanThree: '3 mois +',
            },
            onChanged: (v) => setState(() => _duration = v),
          ),

          const _SectionDivider(),

          // ---- Télétravail / ville
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Télétravail accepté',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'La ville s\'affiche si désactivé',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _remote,
                onChanged: (v) => setState(() => _remote = v),
                activeColor: Colors.white,
                activeTrackColor: AppColors.primary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: AppColors.border,
              ),
            ],
          ),
          if (!_remote) ...[
            const SizedBox(height: 14),
            const _LabelRow(label: 'Ville'),
            TextFormField(
              controller: _cityCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                hint: 'Ex. Tunis',
                prefix: Icons.location_on_outlined,
              ),
              validator: (value) {
                if (!_remote && (value?.trim().isEmpty ?? true)) {
                  return 'Veuillez saisir la ville';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 18),

          // ---- Date limite
          const _LabelRow(label: 'Date limite des candidatures', optional: true),
          GestureDetector(
            onTap: _pickDeadline,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _deadline == null
                          ? 'JJ/MM/AAAA'
                          : _formatDate(_deadline!),
                      style: TextStyle(
                        fontSize: 15,
                        color: _deadline == null
                            ? AppColors.hint
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_deadline != null)
                    GestureDetector(
                      onTap: () => setState(() => _deadline = null),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(Icons.close,
                            size: 20, color: AppColors.hint),
                      ),
                    ),
                  const Icon(Icons.calendar_today_outlined,
                      size: 20, color: AppColors.hint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ---- Lien de référence
          const _LabelRow(label: 'Lien de référence', optional: true),
          TextFormField(
            controller: _linkCtrl,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(
              hint: 'Cahier des charges, maquettes (Drive, Figma…)',
              prefix: Icons.link,
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return null;
              final uri = Uri.tryParse(v);
              final ok = uri != null &&
                  (uri.scheme == 'http' || uri.scheme == 'https') &&
                  uri.host.contains('.');
              return ok ? null : 'Lien invalide (commence par https://)';
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _publish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                    AppColors.primary.withOpacity(0.6),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  child: _savingStatus == 'publiee'
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Text('PUBLIER LA MISSION'),
                ),
              ),
              TextButton(
                onPressed: _isSaving ? null : _saveDraft,
                child: _savingStatus == 'brouillon'
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
                    : const Text(
                  'Enregistrer comme brouillon',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Helpers

  List<String> get _suggestions {
    final q = _skillCtrl.text.trim().toLowerCase();
    return _suggestedSkills
        .where((s) =>
    !_skills.any((x) => x.toLowerCase() == s.toLowerCase()) &&
        (q.isEmpty || s.toLowerCase().contains(q)))
        .take(5)
        .toList();
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  /// Masque le compteur natif (on affiche le nôtre à côté du libellé).
  static Widget? _hideCounter(
      BuildContext context, {
        required int currentLength,
        required bool isFocused,
        required int? maxLength,
      }) =>
      null;

  InputDecoration _inputDecoration({
    String? hint,
    String? helper,
    IconData? prefix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.hint, fontSize: 15),
      helperText: helper,
      helperMaxLines: 2,
      helperStyle: const TextStyle(
        fontSize: 12.5,
        color: AppColors.textSecondary,
      ),
      prefixIcon:
      prefix == null ? null : Icon(prefix, color: AppColors.hint, size: 22),
      filled: true,
      fillColor: AppColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 1.5),
    );
  }
}

// ================================================================ Widgets

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Libellé d'un champ, avec compteur ou mention "Facultatif" à droite.
class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, this.trailing, this.optional = false});

  final String label;
  final Widget? trailing;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.label,
              ),
            ),
          ),
          if (optional)
            const Text(
              'Facultatif',
              style: TextStyle(fontSize: 12, color: AppColors.hint),
            )
          else if (trailing != null)
            trailing!,
        ],
      ),
    );
  }
}

/// Compteur de caractères "12 / 80" mis à jour en direct.
class _CharCounter extends StatelessWidget {
  const _CharCounter({required this.controller, required this.max});

  final TextEditingController controller;
  final int max;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, __) => Text(
        '${value.text.length} / $max',
        style: const TextStyle(fontSize: 12, color: AppColors.hint),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 16, color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }
}

/// Choix entre plusieurs options (prix fixe / taux horaire, durée…).
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entry.key == value
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: entry.key == value
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: entry.key == value
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14.5, color: AppColors.label),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Divider(height: 1, thickness: 1, color: AppColors.divider),
    );
  }
}