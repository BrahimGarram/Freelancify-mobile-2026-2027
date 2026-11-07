import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Texte avec l'effet "glitch" TikTok : une copie cyan décalée à gauche,
/// une copie rouge décalée à droite, et le texte blanc par-dessus.
class GlitchText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double offset;

  const GlitchText(
    this.text, {
    super.key,
    required this.style,
    this.offset = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(-offset, -offset / 2),
          child: Text(text, style: style.copyWith(color: AppColors.cyan)),
        ),
        Transform.translate(
          offset: Offset(offset, offset / 2),
          child: Text(text, style: style.copyWith(color: AppColors.red)),
        ),
        Text(text, style: style.copyWith(color: Colors.white)),
      ],
    );
  }
}

/// Logo de l'app : carré sombre + "F" glitch + nom.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: const GlitchText(
            'F',
            offset: 2,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        const GlitchText(
          'freelance',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

/// Halo de couleur flou en arrière-plan (à placer dans un Stack).
class Halo extends StatelessWidget {
  final double size;
  final Color color; // couleur avec transparence, ex : Color(0x38EE1D52)

  const Halo({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: 80,
          sigmaY: 80,
          tileMode: TileMode.decal,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

/// Champ de saisie avec son label au-dessus.
/// Si [isPassword] est vrai, un bouton "œil" permet d'afficher le mot de passe.
class AppTextField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData? icon; // optionnel (pas d'icône pour une description)
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final int maxLines; // > 1 pour un champ multi-lignes
  final String? suffixText; // ex : "DT" pour le budget
  final int? maxLength; // nombre max de caractères (compteur si multi-lignes)
  final List<TextInputFormatter>? inputFormatters; // filtre la saisie
  final GlobalKey<FormFieldState<String>>? fieldKey; // pour revalider ce champ

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    this.icon,
    required this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onSubmitted,
    this.maxLines = 1,
    this.suffixText,
    this.maxLength,
    this.inputFormatters,
    this.fieldKey,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.label,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: widget.fieldKey,
          controller: widget.controller,
          obscureText: widget.isPassword && _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          // l'erreur s'affiche (et disparaît) pendant la saisie
          autovalidateMode: AutovalidateMode.onUserInteraction,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          onFieldSubmitted: widget.onSubmitted,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          cursorColor: AppColors.cyan,
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintMaxLines: widget.maxLines,
            alignLabelWithHint: true,
            // compteur "12/500" seulement pour les champs multi-lignes
            counterText: widget.maxLines > 1 ? null : '',
            suffixText: widget.suffixText,
            suffixStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
            prefixIcon: widget.icon != null
                ? Icon(widget.icon, size: 20)
                : null,
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _hidden
                        ? 'Afficher le mot de passe'
                        : 'Masquer le mot de passe',
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Bouton principal rouge, avec un loader pendant le chargement.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Petite fonction pour afficher un message en bas de l'écran.
void showAppMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: error ? AppColors.red : AppColors.cyan,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
