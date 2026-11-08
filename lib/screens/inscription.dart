import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/verification_email_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_widgets.dart';
import 'verification_email.dart';

class InscriptionScreen extends StatefulWidget {
  final VerificationEmailService? service; // remplaçable dans les tests
  const InscriptionScreen({super.key, this.service});

  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final _verification = widget.service ?? VerificationEmailService();

  String _role = 'freelancer'; // 'freelancer' ou 'client'
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ---------- FONCTIONNALITÉ : inscription ----------
  Future<void> _creerCompte() async {
    // 1. Vérifier les champs
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final nom = _usernameController.text.trim();
    setState(() => _loading = true);

    try {
      // 2. Envoyer un code à cette adresse (le compte n'est pas encore créé)
      var attente = VerificationEmailService.delaiRenvoi.inSeconds;
      try {
        await _verification.demanderCode(nom: nom, email: email);
      } on AttenteRenvoiException catch (e) {
        attente = e.secondes; // un code vient de partir : il reste valable
      }
      if (!mounted) return;

      // 3. Saisie du code : c'est cet écran qui crée le compte
      final cree = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => VerificationEmailScreen(
            user: User(
              username: nom,
              email: email,
              password: _passwordController.text,
              role: _role,
            ),
            service: _verification,
            attenteInitiale: attente,
          ),
        ),
      );
      if (cree != true || !mounted) return;

      // 4. Succès → message + retour à la connexion (email pré-rempli)
      showAppMessage(
        context,
        'Email vérifié, compte créé ! Tu peux te connecter.',
      );
      Navigator.of(context).pop(email);
    } on VerificationException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
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
          const Positioned(
            top: -120,
            right: -80,
            child: Halo(size: 300, color: Color(0x38EE1D52)),
          ),
          const Positioned(
            bottom: -120,
            left: -100,
            child: Halo(size: 260, color: Color(0x2425F4EE)),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bouton retour
                    _BackButton(onTap: () => Navigator.of(context).pop()),
                    const SizedBox(height: 24),
                    const Text(
                      'Crée ton compte',
                      style: TextStyle(
                        fontSize: 32,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu es ici pour…',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Choix du rôle (les deux cartes gardent la même hauteur)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _RoleCard(
                              title: 'Freelancer',
                              description: 'Je cherche des missions',
                              icon: Icons.laptop_mac_rounded,
                              selected: _role == 'freelancer',
                              onTap: () => setState(() => _role = 'freelancer'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RoleCard(
                              title: 'Client',
                              description: 'Je publie des missions',
                              icon: Icons.work_outline_rounded,
                              selected: _role == 'client',
                              onTap: () => setState(() => _role = 'client'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    AppTextField(
                      label: "Nom d'utilisateur",
                      hint: 'fady.dev',
                      icon: Icons.person_outline,
                      controller: _usernameController,
                      maxLength: Validators.usernameMax,
                      validator: Validators.username,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Email',
                      hint: 'toi@exemple.com',
                      icon: Icons.mail_outline,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: Validators.emailMax,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Mot de passe',
                      hint: '8 caractères, lettres et chiffres',
                      icon: Icons.lock_outline,
                      controller: _passwordController,
                      isPassword: true,
                      maxLength: Validators.passwordMax,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Confirmer le mot de passe',
                      hint: 'Retape ton mot de passe',
                      icon: Icons.lock_outline,
                      controller: _confirmController,
                      isPassword: true,
                      maxLength: Validators.passwordMax,
                      textInputAction: TextInputAction.done,
                      validator: Validators.confirmation(
                        () => _passwordController.text,
                      ),
                      onSubmitted: (_) => _creerCompte(),
                    ),
                    const SizedBox(height: 20),

                    PrimaryButton(
                      label: _role == 'client'
                          ? 'Créer mon compte client'
                          : 'Créer mon compte freelancer',
                      loading: _loading,
                      onPressed: _creerCompte,
                    ),
                    const SizedBox(height: 20),

                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Déjà un compte ?',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.cyan,
                          ),
                          child: const Text(
                            'Se connecter',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
}

/// Bouton retour carré arrondi.
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.fieldBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
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
    );
  }
}

/// Carte de choix du rôle (Freelancer / Client).
class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 136),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.selectedCard : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.red : AppColors.fieldBorder,
              width: 2,
            ),
            // Ombre cyan décalée = effet glitch TikTok
            boxShadow: selected
                ? const [
                    BoxShadow(color: AppColors.cyan, offset: Offset(-3, -2)),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.red : AppColors.fieldBorder,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: selected ? Colors.white : AppColors.label,
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: selected ? AppColors.label : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
