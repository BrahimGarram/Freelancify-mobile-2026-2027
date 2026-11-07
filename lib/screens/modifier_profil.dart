import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_widgets.dart';
import '../widgets/home_widgets.dart';

/// Modification du profil : nom d'utilisateur, email et (facultatif)
/// mot de passe. Renvoie l'utilisateur mis à jour via `Navigator.pop`.
class ModifierProfilScreen extends StatefulWidget {
  final User user;
  const ModifierProfilScreen({super.key, required this.user});

  @override
  State<ModifierProfilScreen> createState() => _ModifierProfilScreenState();
}

class _ModifierProfilScreenState extends State<ModifierProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _usernameController = TextEditingController(
    text: widget.user.username,
  );
  late final _emailController = TextEditingController(text: widget.user.email);
  late final _metierController = TextEditingController(
    text: widget.user.metier ?? '',
  );
  late final _bioController = TextEditingController(
    text: widget.user.bio ?? '',
  );
  final _actuelController = TextEditingController();
  final _nouveauController = TextEditingController();
  final _confirmController = TextEditingController();
  final _userService = UserService();
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _metierController.dispose();
    _bioController.dispose();
    _actuelController.dispose();
    _nouveauController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Vrai si l'utilisateur a commencé à remplir la partie "mot de passe"
  bool get _changeMotDePasse =>
      _actuelController.text.isNotEmpty ||
      _nouveauController.text.isNotEmpty ||
      _confirmController.text.isNotEmpty;

  // ---------- FONCTIONNALITÉ : enregistrer ----------
  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final freelancer = widget.user.isFreelancer;
    final metier = _metierController.text.trim();
    final bio = _bioController.text.trim();
    final rienAChanger =
        username == widget.user.username &&
        email == widget.user.email &&
        (!freelancer ||
            (metier == (widget.user.metier ?? '') &&
                bio == (widget.user.bio ?? ''))) &&
        !_changeMotDePasse;
    if (rienAChanger) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _loading = true);
    try {
      final misAJour = await _userService.updateProfil(
        id: widget.user.id!,
        username: username,
        email: email,
        motDePasseActuel: _changeMotDePasse ? _actuelController.text : null,
        nouveauMotDePasse: _changeMotDePasse ? _nouveauController.text : null,
        // profil public : seulement pour les freelancers
        metier: freelancer ? metier : null,
        bio: freelancer ? bio : null,
      );
      if (!mounted) return;
      showAppMessage(context, 'Profil mis à jour');
      Navigator.of(context).pop(misAJour);
    } on ProfilException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Validations de la partie mot de passe ----------
  // Ces champs sont facultatifs : ils ne sont contrôlés que si
  // l'utilisateur a commencé à en remplir un.
  String? _validerActuel(String? v) {
    if (!_changeMotDePasse) return null;
    if (v == null || v.isEmpty) return 'Entre ton mot de passe actuel';
    return null;
  }

  String? _validerNouveau(String? v) {
    if (!_changeMotDePasse) return null;
    final erreur = Validators.password(v);
    if (erreur != null) return erreur;
    if (v == _actuelController.text) {
      return "Choisis un mot de passe différent de l'actuel";
    }
    return null;
  }

  String? _validerConfirmation(String? v) {
    if (!_changeMotDePasse) return null;
    return Validators.confirmation(() => _nouveauController.text)(v);
  }

  // ---------- Interface ----------
  @override
  Widget build(BuildContext context) {
    final isClient = widget.user.role == 'client';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -100,
            right: -80,
            child: Halo(size: 260, color: Color(0x2EEE1D52)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _RetourButton(onTap: () => Navigator.of(context).pop()),
                        const SizedBox(width: 14),
                        const Text(
                          'Modifier le profil',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ValueListenableBuilder(
                        valueListenable: _usernameController,
                        builder: (_, value, _) => UserAvatar(
                          name: value.text.trim().isEmpty
                              ? widget.user.username
                              : value.text.trim(),
                          isClient: isClient,
                          size: 80,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const _SectionTitre('Informations'),
                    const SizedBox(height: 12),
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
                    if (widget.user.isFreelancer) ...[
                      const SizedBox(height: 28),
                      const _SectionTitre('Profil public'),
                      const SizedBox(height: 4),
                      const Text(
                        'Visible par les clients sur ta page de profil.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Métier (facultatif)',
                        hint: 'Graphiste, Développeur Flutter…',
                        icon: Icons.work_outline_rounded,
                        controller: _metierController,
                        maxLength: Validators.metierMax,
                        validator: Validators.metier,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Bio (facultatif)',
                        hint: 'Présente-toi : ton expérience, tes spécialités…',
                        controller: _bioController,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLength: Validators.bioMax,
                        validator: Validators.bio,
                      ),
                    ],
                    const SizedBox(height: 28),

                    const _SectionTitre('Changer le mot de passe'),
                    const SizedBox(height: 4),
                    const Text(
                      'Laisse ces champs vides pour garder ton mot de passe.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Mot de passe actuel',
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      controller: _actuelController,
                      isPassword: true,
                      maxLength: Validators.passwordMax,
                      validator: _validerActuel,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Nouveau mot de passe',
                      hint: '8 caractères, lettres et chiffres',
                      icon: Icons.lock_reset_outlined,
                      controller: _nouveauController,
                      isPassword: true,
                      maxLength: Validators.passwordMax,
                      validator: _validerNouveau,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Confirmer le nouveau mot de passe',
                      hint: 'Retape le nouveau mot de passe',
                      icon: Icons.lock_reset_outlined,
                      controller: _confirmController,
                      isPassword: true,
                      maxLength: Validators.passwordMax,
                      textInputAction: TextInputAction.done,
                      validator: _validerConfirmation,
                      onSubmitted: (_) => _enregistrer(),
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: 'Enregistrer',
                      loading: _loading,
                      onPressed: _enregistrer,
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

class _SectionTitre extends StatelessWidget {
  final String texte;
  const _SectionTitre(this.texte);

  @override
  Widget build(BuildContext context) {
    return Text(
      texte,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
    );
  }
}

class _RetourButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RetourButton({required this.onTap});

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
