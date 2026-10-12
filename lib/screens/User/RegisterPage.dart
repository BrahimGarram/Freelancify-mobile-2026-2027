import 'package:flutter/material.dart';

// Même dossier que LoginPage.dart (lib/screens/).
// Si vous avez déplacé AppColors dans lib/theme/app_colors.dart, remplacez par :
// import '../theme/app_colors.dart';
import '../LoginPage.dart' show AppColors;

/// Type de compte choisi à l'inscription.
enum UserRole { freelance, client }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _role = UserRole.freelance;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _showTermsError = !_acceptedTerms);
    if (!formOk || !_acceptedTerms) return;

    setState(() => _isLoading = true);

    // TODO: créer le compte (Firebase, API, etc.) avec :
    // _nameController.text, _emailController.text,
    // _passwordController.text et _role (freelance ou client)
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() => _isLoading = false);

    // TODO: naviguer selon le rôle :
    // freelance -> MissionsListPage, client -> page "Mes missions"
  }

  void _signUpWithGoogle() {
    // TODO: inscription avec Google
  }

  void _goToLogin() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Bandeau bleu acier
          Container(
            height: topInset + 250,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BackButton(onTap: _goToLogin),
                    const SizedBox(height: 20),
                    const Text(
                      'Créer un compte',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Rejoignez Freelancify en quelques instants.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: Color(0xFFD6E4EB),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _buildCard(),
                    const SizedBox(height: 24),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            'Déjà un compte ? ',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: _goToLogin,
                            child: const Text(
                              'Se connecter',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
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
        ],
      ),
    );
  }

  /// Carte blanche qui contient le formulaire.
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
          // Choix du profil
          const _FieldLabel(text: 'Je suis'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RoleTile(
                  icon: Icons.laptop_mac,
                  title: 'Freelance',
                  subtitle: 'Je cherche des missions',
                  selected: _role == UserRole.freelance,
                  onTap: () => setState(() => _role = UserRole.freelance),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RoleTile(
                  icon: Icons.business_center_outlined,
                  title: 'Client',
                  subtitle: 'Je publie des missions',
                  selected: _role == UserRole.client,
                  onTap: () => setState(() => _role = UserRole.client),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Nom complet
          const _FieldLabel(text: 'Nom complet'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: _inputDecoration(
              hint: 'Prénom et nom',
              icon: Icons.person_outline,
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Veuillez saisir votre nom';
              if (v.length < 2) return 'Nom trop court';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Email
          const _FieldLabel(text: 'Adresse email'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: _inputDecoration(
              hint: 'nom@entreprise.com',
              icon: Icons.mail_outline,
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Veuillez saisir votre email';
              final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!regex.hasMatch(v)) return 'Email invalide';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Mot de passe
          const _FieldLabel(text: 'Mot de passe'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _submit(),
            decoration: _inputDecoration(
              hint: '••••••••',
              icon: Icons.lock_outline,
              helper: '8 caractères minimum, avec un chiffre.',
            ).copyWith(
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.hint,
                  size: 22,
                ),
              ),
            ),
            validator: (value) {
              final v = value ?? '';
              if (v.isEmpty) return 'Veuillez saisir un mot de passe';
              if (v.length < 8) return 'Au moins 8 caractères';
              if (!RegExp(r'\d').hasMatch(v)) return 'Ajoutez au moins un chiffre';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Conditions d'utilisation
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _acceptedTerms = !_acceptedTerms;
              if (_acceptedTerms) _showTermsError = false;
            }),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: _acceptedTerms ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _showTermsError
                          ? AppColors.error
                          : (_acceptedTerms
                          ? AppColors.primary
                          : AppColors.border),
                      width: 1.5,
                    ),
                  ),
                  child: _acceptedTerms
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(text: "J'accepte les "),
                        // TODO: ouvrir la page des conditions au clic
                        TextSpan(
                          text: "Conditions d'utilisation",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(text: ' et la '),
                        TextSpan(
                          text: 'Politique de confidentialité',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showTermsError)
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 34),
              child: Text(
                'Vous devez accepter les conditions pour continuer.',
                style: TextStyle(fontSize: 12.5, color: AppColors.error),
              ),
            ),
          const SizedBox(height: 22),

          // Bouton créer un compte
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
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
              child: _isLoading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
                  : const Text('CRÉER MON COMPTE'),
            ),
          ),
          const SizedBox(height: 22),

          // Séparateur "OU"
          const _OrDivider(),
          const SizedBox(height: 22),

          // Bouton Google
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _signUpWithGoogle,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Remplacez par le logo Google officiel (SVG/PNG) si besoin.
              icon: const Icon(Icons.g_mobiledata, size: 32),
              label: const Text("S'inscrire avec Google"),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? helper,
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
      helperStyle: const TextStyle(
        fontSize: 12.5,
        color: AppColors.textSecondary,
      ),
      prefixIcon: Icon(icon, color: AppColors.hint, size: 22),
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

/// Bouton retour semi-transparent sur le bandeau.
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

/// Tuile de choix du type de compte (Freelance / Client).
class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                if (selected)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 13, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.label,
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OU',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.hint,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
      ],
    );
  }
}