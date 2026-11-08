import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'home_widgets.dart';

// Champs de formulaire "spéciaux" (choix, date, liste, étiquettes).
// Ce sont tous des FormField : ils participent à `_formKey.validate()`
// et affichent leur message d'erreur comme les champs texte.

/// Label au-dessus d'un champ (même style que AppTextField)
class FieldLabel extends StatelessWidget {
  final String texte;
  final bool facultatif;
  const FieldLabel(this.texte, {super.key, this.facultatif = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: texte,
          children: [
            if (facultatif)
              const TextSpan(
                text: '  (facultatif)',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.label,
        ),
      ),
    );
  }
}

/// Message d'erreur sous un champ personnalisé
class _ErrorText extends StatelessWidget {
  final String? erreur;
  const _ErrorText(this.erreur);

  @override
  Widget build(BuildContext context) {
    if (erreur == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: Text(
        erreur!,
        style: const TextStyle(fontSize: 12, color: AppColors.error),
      ),
    );
  }
}

/// Case à cocher avec contrôle de saisie (ex : engagement à accepter)
class CaseACocherField extends FormField<bool> {
  CaseACocherField({
    super.key,
    required String texte,
    super.validator,
    ValueChanged<bool>? onChanged,
  }) : super(
         initialValue: false,
         autovalidateMode: AutovalidateMode.onUserInteraction,
         builder: (state) {
           void basculer() {
             final v = !(state.value ?? false);
             state.didChange(v);
             onChanged?.call(v);
           }

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               InkWell(
                 borderRadius: BorderRadius.circular(12),
                 onTap: basculer,
                 child: Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Checkbox(
                       value: state.value ?? false,
                       activeColor: AppColors.cyan,
                       checkColor: Colors.black,
                       side: BorderSide(
                         color: state.hasError
                             ? AppColors.error
                             : AppColors.textMuted,
                         width: 1.5,
                       ),
                       onChanged: (_) => basculer(),
                     ),
                     Expanded(
                       child: Padding(
                         padding: const EdgeInsets.only(top: 12, right: 4),
                         child: Text(
                           texte,
                           style: const TextStyle(
                             fontSize: 13,
                             height: 1.4,
                             color: AppColors.label,
                           ),
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
               _ErrorText(state.errorText),
             ],
           );
         },
       );
}

// ============================ Choix en puces ============================

/// Un choix unique parmi des puces (catégorie, type de budget, mode…)
class ChoiceChipsField extends FormField<String> {
  ChoiceChipsField({
    super.key,
    required String label,
    required Map<String, String> options,
    Map<String, IconData> icones = const {},
    super.initialValue,
    super.validator,
    ValueChanged<String>? onChanged,
  }) : super(
         autovalidateMode: AutovalidateMode.onUserInteraction,
         builder: (state) => Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             FieldLabel(label),
             Wrap(
               spacing: 8,
               runSpacing: 8,
               children: [
                 for (final MapEntry(key: cle, value: texte) in options.entries)
                   _Puce(
                     texte: texte,
                     icone: icones[cle],
                     selected: state.value == cle,
                     erreur: state.hasError,
                     onTap: () {
                       state.didChange(cle);
                       onChanged?.call(cle);
                     },
                   ),
               ],
             ),
             _ErrorText(state.errorText),
           ],
         ),
       );
}

/// Plusieurs choix parmi des puces (ex : catégories d'un post).
/// Au-delà de [max], les puces non choisies sont désactivées.
/// La valeur suit l'ordre des [options].
class MultiChoiceChipsField extends FormField<List<String>> {
  MultiChoiceChipsField({
    super.key,
    required String label,
    required Map<String, String> options,
    Map<String, IconData> icones = const {},
    required int max,
    List<String> super.initialValue = const [],
    super.validator,
    ValueChanged<List<String>>? onChanged,
  }) : super(
         autovalidateMode: AutovalidateMode.onUserInteraction,
         builder: (state) {
           final choisis = state.value ?? const <String>[];
           final plein = choisis.length >= max;
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 children: [
                   Expanded(child: FieldLabel(label)),
                   Padding(
                     padding: const EdgeInsets.only(bottom: 8),
                     child: Text(
                       '${choisis.length}/$max',
                       style: TextStyle(
                         fontSize: 12,
                         fontWeight: FontWeight.w600,
                         color: plein ? AppColors.cyan : AppColors.textMuted,
                       ),
                     ),
                   ),
                 ],
               ),
               Wrap(
                 spacing: 8,
                 runSpacing: 8,
                 children: [
                   for (final MapEntry(key: cle, value: texte)
                       in options.entries)
                     Opacity(
                       opacity: plein && !choisis.contains(cle) ? 0.4 : 1,
                       child: _Puce(
                         texte: texte,
                         icone: icones[cle],
                         selected: choisis.contains(cle),
                         erreur: state.hasError,
                         onTap: () {
                           final dejaChoisi = choisis.contains(cle);
                           if (!dejaChoisi && plein) return; // limite atteinte
                           final nouveaux = [
                             for (final k in options.keys)
                               if (k == cle ? !dejaChoisi : choisis.contains(k))
                                 k,
                           ];
                           state.didChange(nouveaux);
                           onChanged?.call(nouveaux);
                         },
                       ),
                     ),
                 ],
               ),
               _ErrorText(state.errorText),
             ],
           );
         },
       );
}

class _Puce extends StatelessWidget {
  final String texte;
  final IconData? icone;
  final bool selected;
  final bool erreur;
  final VoidCallback onTap;

  const _Puce({
    required this.texte,
    this.icone,
    required this.selected,
    required this.erreur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleurBord = selected
        ? AppColors.cyan
        : (erreur ? AppColors.error : AppColors.fieldBorder);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0x1A25F4EE) : AppColors.fieldFill,
        shape: StadiumBorder(
          side: BorderSide(color: couleurBord, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icone != null) ...[
                  Icon(
                    icone,
                    size: 16,
                    color: selected ? AppColors.cyan : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    texte,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.cyan : AppColors.textPrimary,
                    ),
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

// ============================ Date limite ============================

/// Sélecteur de date (ouvre le calendrier). Les dates hors de
/// [demain ; dans 1 an] ne sont pas sélectionnables.
class DateLimiteField extends FormField<DateTime> {
  DateLimiteField({
    super.key,
    required String label,
    super.initialValue,
    ValueChanged<DateTime>? onChanged,
  }) : super(
         validator: Validators.dateLimite,
         autovalidateMode: AutovalidateMode.onUserInteraction,
         builder: (state) {
           final date = state.value;
           Future<void> choisir() async {
             final now = DateTime.now();
             final demain = DateTime(now.year, now.month, now.day + 1);
             final choisie = await showDatePicker(
               context: state.context,
               initialDate: date ?? demain.add(const Duration(days: 6)),
               firstDate: demain,
               lastDate: DateTime(
                 now.year,
                 now.month,
                 now.day + Validators.delaiMaxJours,
               ),
               helpText: 'Date limite de la mission',
             );
             if (choisie != null) {
               state.didChange(choisie);
               onChanged?.call(choisie);
             }
           }

           final bord = state.hasError
               ? AppColors.error
               : AppColors.fieldBorder;
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               FieldLabel(label),
               Material(
                 color: AppColors.fieldFill,
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(16),
                   side: BorderSide(color: bord),
                 ),
                 child: InkWell(
                   borderRadius: BorderRadius.circular(16),
                   onTap: choisir,
                   child: Padding(
                     padding: const EdgeInsets.symmetric(
                       horizontal: 14,
                       vertical: 16,
                     ),
                     child: Row(
                       children: [
                         const Icon(
                           Icons.event_outlined,
                           size: 20,
                           color: AppColors.textSecondary,
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                           child: Text(
                             date == null
                                 ? 'Choisir une date'
                                 : 'Avant le ${formatDate(date)}',
                             style: TextStyle(
                               fontSize: 15,
                               color: date == null
                                   ? AppColors.textMuted
                                   : AppColors.textPrimary,
                             ),
                           ),
                         ),
                         const Icon(
                           Icons.expand_more_rounded,
                           color: AppColors.textSecondary,
                         ),
                       ],
                     ),
                   ),
                 ),
               ),
               _ErrorText(state.errorText),
             ],
           );
         },
       );
}

// ============================ Liste déroulante ============================

/// Liste déroulante simple (ex : la ville)
class DropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final List<String> options;
  final String? value;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String?> onChanged;

  const DropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.options,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true, // évite le débordement sur petit écran
          items: [
            for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: onChanged,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          dropdownColor: AppColors.surface,
          menuMaxHeight: 360,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.expand_more_rounded),
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
          ),
        ),
      ],
    );
  }
}

// ============================ Compétences ============================

/// Étiquettes : on tape une compétence puis Entrée (ou +) pour l'ajouter.
/// Chaque compétence est contrôlée avant d'être ajoutée.
class CompetencesField extends FormField<List<String>> {
  CompetencesField({
    super.key,
    required String label,
    super.initialValue = const [],
    ValueChanged<List<String>>? onChanged,
  }) : super(
         validator: Validators.competences,
         builder: (state) => _CompetencesInput(
           label: label,
           state: state,
           onChanged: onChanged,
         ),
       );
}

class _CompetencesInput extends StatefulWidget {
  final String label;
  final FormFieldState<List<String>> state;
  final ValueChanged<List<String>>? onChanged;

  const _CompetencesInput({
    required this.label,
    required this.state,
    this.onChanged,
  });

  @override
  State<_CompetencesInput> createState() => _CompetencesInputState();
}

class _CompetencesInputState extends State<_CompetencesInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _erreurSaisie; // erreur de la compétence en cours de saisie

  List<String> get _liste => widget.state.value ?? const [];

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changer(List<String> nouvelle) {
    widget.state.didChange(nouvelle);
    widget.onChanged?.call(nouvelle);
  }

  void _ajouter() {
    final texte = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final erreur = Validators.competence(texte, _liste);
    setState(() => _erreurSaisie = erreur);
    if (erreur != null) return;
    _changer([..._liste, texte]);
    _controller.clear();
    _focus.requestFocus(); // on peut enchaîner la suivante
  }

  void _retirer(String c) {
    setState(() => _erreurSaisie = null);
    _changer(_liste.where((x) => x != c).toList());
  }

  @override
  Widget build(BuildContext context) {
    final plein = _liste.length >= Validators.competencesMax;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(
          '${widget.label} (${_liste.length}/${Validators.competencesMax})',
          facultatif: true,
        ),
        if (_liste.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _liste)
                InputChip(
                  label: Text(c),
                  onDeleted: () => _retirer(c),
                  deleteButtonTooltipMessage: 'Retirer $c',
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cyan,
                  ),
                  deleteIconColor: AppColors.cyan,
                  backgroundColor: const Color(0x1A25F4EE),
                  side: const BorderSide(color: Color(0x6625F4EE)),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (!plein)
          TextField(
            controller: _controller,
            focusNode: _focus,
            maxLength: Validators.competenceMax,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _ajouter(),
            onChanged: (_) {
              if (_erreurSaisie != null) setState(() => _erreurSaisie = null);
            },
            cursorColor: AppColors.cyan,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ex : Figma, Flutter, Montage…',
              counterText: '',
              prefixIcon: const Icon(Icons.sell_outlined, size: 20),
              errorText: _erreurSaisie,
              suffixIcon: IconButton(
                tooltip: 'Ajouter la compétence',
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: AppColors.cyan,
                onPressed: _ajouter,
              ),
            ),
          ),
        _ErrorText(widget.state.errorText),
      ],
    );
  }
}

// ============================ Interrupteur ============================

/// Ligne avec un interrupteur (ex : « Mission urgente »)
class SwitchField extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchField({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? const Color(0x1AEE1D52) : AppColors.fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: value ? const Color(0x99EE1D52) : AppColors.fieldBorder,
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.red,
        secondary: Icon(
          icon,
          color: value ? AppColors.red : AppColors.textSecondary,
        ),
        title: Text(
          titre,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          sousTitre,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
