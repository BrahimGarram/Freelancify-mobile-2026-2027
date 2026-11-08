import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'database/database_helper.dart';
import 'models/user.dart';
import 'observer/observateurs_posts.dart';
import 'screens/home_router.dart';
import 'screens/login.dart';
import 'screens/splash_screen.dart';
import 'services/ai/ai_config.dart';
import 'services/mail/mail_service.dart';
import 'services/secrets.dart';
import 'services/session_manager.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Secrets.charger(); // clés Gemini + mot de passe Gmail
  configurerObservateurs(); // pattern Observer : notifications des abonnés
  runApp(const FreelanceApp());
  // état de la configuration, visible dans le terminal
  MailService.instance.journaliserConfiguration();
  debugPrint(
    '[IA] Chatbot : ${AiConfig.cleChatbot.isEmpty ? 'clé MANQUANTE' : 'clé OK'}'
    ' · Post : ${AiConfig.clePost.isEmpty ? 'clé MANQUANTE' : 'clé OK'}'
    ' · Rapport test : ${AiConfig.cleRapportDediee ? 'clé OK' : (AiConfig.cleRapport.isEmpty ? 'clé MANQUANTE' : 'clé du post (GEMINI_RAPPORT_KEY absente)')}'
    ' (${Secrets.chemin})',
  );
  // renvoie les emails qui n'avaient pas pu partir (pas de réseau…)
  unawaited(
    MailService.instance.envoyerEnAttente().catchError(
      (Object e) => debugPrint('[MAIL] ❌ Envoi en attente impossible : $e'),
    ),
  );
}

class FreelanceApp extends StatelessWidget {
  const FreelanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freelance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // Application en français (calendrier, textes des boutons système…)
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const DemarrageScreen(),
    );
  }
}

/// Au lancement : logo animé pendant la préparation, puis l'espace de
/// l'utilisateur si une session existe, sinon l'écran de connexion.
class DemarrageScreen extends StatefulWidget {
  const DemarrageScreen({super.key});

  @override
  State<DemarrageScreen> createState() => _DemarrageScreenState();
}

class _DemarrageScreenState extends State<DemarrageScreen> {
  late final Future<User?> _session = _restaurerSession();

  Future<User?> _restaurerSession() async {
    try {
      // la base (et ses 140 questions au 1er lancement) se prépare sous le logo
      await DatabaseHelper.instance.database;
      final id = await SessionManager.getUserId();
      if (id == null) return null;
      final user = await UserService().getUserById(id);
      // Compte supprimé entre-temps : on nettoie la session
      if (user == null) await SessionManager.logout();
      return user;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen<User?>(
      chargement: _session,
      suivant: (user) => user == null ? const LoginScreen() : accueilPour(user),
    );
  }
}
