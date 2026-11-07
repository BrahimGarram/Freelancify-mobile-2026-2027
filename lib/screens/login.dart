import 'package:flutter/material.dart';

import '../services/session_manager.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_widgets.dart';
import 'assistant/assistant_screen.dart';
import 'home_router.dart';
import 'inscription.dart';
import 'mot_de_passe_oublie.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userService = UserService();
  bool _loading = false;

  // Les "stories" de catégories en haut de l'écran
  static const _categories = [
    ('UI', 'Design'),
    ('</>', 'Dev'),
    ('Vid', 'Vidéo'),
    ('Ph', 'Photo'),
    ('Aa', 'Rédaction'),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------- FONCTIONNALITÉ : connexion ----------
  // ---------- FONCTIONNALITÉ : mot de passe oublié ----------
  Future<void> _motDePasseOublie() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            MotDePasseOublieScreen(emailInitial: _emailController.text.trim()),
      ),
    );
    if (email == null || !mounted) return;
    // mot de passe changé : on pré-remplit l'email pour se connecter
    _emailController.text = email;
    _passwordController.clear();
  }

  Future<void> _seConnecter() async {
    // 1. Vérifier que les champs sont bien remplis
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // 2. Appeler le service
      final user = await _userService.login(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text,
      );
      if (!mounted) return;

      // 3. Mauvais identifiants
      if (user == null) {
        showAppMessage(context, 'Email ou mot de passe incorrect', error: true);
        return;
      }

      // 4. Connexion réussie → on mémorise la session (connexion automatique
      //    au prochain lancement), puis espace Client ou Freelancer
      await SessionManager.saveSession(userId: user.id!, role: user.role);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => accueilPour(user)));
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Interface ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Halos de couleur en arrière-plan
          const Positioned(
            top: -120,
            left: -90,
            child: Halo(size: 320, color: Color(0x2925F4EE)),
          ),
          const Positioned(
            top: -60,
            right: -120,
            child: Halo(size: 280, color: Color(0x38EE1D52)),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: ConstrainedBox(
                  // permet de coller le lien "S'inscrire" en bas de l'écran
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppLogo(),
                          const SizedBox(height: 32),
                          _buildStories(),
                          const SizedBox(height: 36),
                          const Text(
                            'Content de\nte revoir.',
                            style: TextStyle(
                              fontSize: 34,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Connecte-toi pour retrouver tes missions.',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          AppTextField(
                            label: 'Email',
                            hint: 'toi@exemple.com',
                            icon: Icons.mail_outline,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            maxLength: Validators.emailMax,
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            label: 'Mot de passe',
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            controller: _passwordController,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            validator: Validators.passwordLogin,
                            onSubmitted: (_) => _seConnecter(),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _motDePasseOublie,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.cyan,
                              ),
                              child: const Text(
                                'Mot de passe oublié ?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          PrimaryButton(
                            label: 'Se connecter',
                            loading: _loading,
                            onPressed: _seConnecter,
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => ouvrirAssistant(context),
                              icon: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                              ),
                              label: const Text('Comment ça marche ?'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 24),
                          // rétrécit sur les très petits écrans
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Pas encore de compte ?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const InscriptionScreen(),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.cyan,
                                  ),
                                  child: const Text(
                                    "S'inscrire",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStories() {
    // Une simple Row (pas de scroll horizontal : IntrinsicHeight ne
    // supporte pas les widgets qui scrollent à l'intérieur)
    // largeur disponible (écran moins les marges de 24 de chaque côté)
    final largeur = MediaQuery.sizeOf(context).width - 48;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        // largeur minimale pour les 5 pastilles, réduite si l'écran est petit
        width: largeur < 340 ? 340 : largeur,
        child: _rangeeStories(),
      ),
    );
  }

  Widget _rangeeStories() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (short, label) in _categories)
          Column(
            children: [
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.red,
                  boxShadow: [
                    BoxShadow(color: AppColors.cyan, offset: Offset(-3, -1)),
                  ],
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.background, width: 2.5),
                  ),
                  child: Text(
                    short,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
