import 'package:flutter/material.dart';

/// Toutes les couleurs de l'app (thème TikTok).
/// Pour changer une couleur partout, on la change ici.
class AppColors {
  static const background = Color(0xFF000000); // fond noir pur
  static const surface = Color(0xFF121212); // cartes, bulles
  static const red = Color(0xFFEE1D52); // couleur principale (boutons)
  static const cyan = Color(0xFF25F4EE); // accent (liens, champ actif)

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFF71717A);
  static const label = Color(0xFFD4D4D8);

  static const fieldFill = Color(0x0DFFFFFF); // blanc à 5 %
  static const fieldBorder = Color(0x1AFFFFFF); // blanc à 10 %
  static const selectedCard = Color(0xFF1A0A10); // carte de rôle choisie
  static const error = Color(0xFFFF6B8A);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      // Police embarquée (assets/fonts) : aucun téléchargement au lancement
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.red,
        secondary: AppColors.cyan,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'PlusJakartaSans',
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldFill,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        enabledBorder: border(AppColors.fieldBorder),
        focusedBorder: border(AppColors.cyan, 1.5),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.5),
        errorStyle: const TextStyle(color: AppColors.error),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}
