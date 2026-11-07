import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/mot_de_passe_oublie_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_widgets.dart';

/// Mot de passe oublié, en 2 étapes :
/// 1. email → un code à 6 chiffres est envoyé par email ;
/// 2. code + nouveau mot de passe.
/// Renvoie l'email (pour pré-remplir la connexion) si tout a réussi.
class MotDePasseOublieScreen extends StatefulWidget {
  final String? emailInitial;
  final MotDePasseOublieService? service; // remplaçable dans les tests

  const MotDePasseOublieScreen({super.key, this.emailInitial, this.service});

  @override
  State<MotDePasseOublieScreen> createState() => _MotDePasseOublieScreenState();
}

class _MotDePasseOublieScreenState extends State<MotDePasseOublieScreen> {
  late final MotDePasseOublieService _service =
      widget.service ?? MotDePasseOublieService();
  final _formEmail = GlobalKey<FormState>();
  final _formCode = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.emailInitial ?? '',
  );
  final _codeController = TextEditingController();
  final _mdpController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _codeEnvoye = false; // étape 2 ?
  String? _emailInconnu; // adresse refusée (aucun compte)
  bool _loading = false;
  int _attenteRenvoi = 0; // secondes avant de pouvoir renvoyer
  Timer? _minuteur;

  @override
  void dispose() {
    _minuteur?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _mdpController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ---------- Étape 1 : envoyer le code ----------
  Future<void> _envoyerCode() async {
    FocusScope.of(context).unfocus();
    if (!_codeEnvoye && !_formEmail.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _service.demanderCode(_emailController.text);
      if (!mounted) return;
      setState(() => _codeEnvoye = true);
      _demarrerMinuteur();
      showAppMessage(context, 'Code envoyé ! Vérifie ta boîte mail.');
    } on EmailInconnuException catch (e) {
      if (!mounted) return;
      // on reste à l'étape 1, l'erreur s'affiche sous le champ email
      setState(() {
        _codeEnvoye = false;
        _emailInconnu = _emailController.text.trim().toLowerCase();
      });
      _formEmail.currentState?.validate();
      showAppMessage(context, e.message, error: true);
    } on ReinitialisationException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _demarrerMinuteur() {
    _minuteur?.cancel();
    setState(
      () => _attenteRenvoi = MotDePasseOublieService.delaiRenvoi.inSeconds,
    );
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _attenteRenvoi <= 1) {
        t.cancel();
        if (mounted) setState(() => _attenteRenvoi = 0);
        return;
      }
      setState(() => _attenteRenvoi--);
    });
  }

  // ---------- Étape 2 : nouveau mot de passe ----------
  Future<void> _reinitialiser() async {
    FocusScope.of(context).unfocus();
    if (!_formCode.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _service.reinitialiser(
        email: _emailController.text,
        code: _codeController.text,
        nouveauMotDePasse: _mdpController.text,
      );
      if (!mounted) return;
      showAppMessage(context, 'Mot de passe modifié ! Connecte-toi.');
      Navigator.of(context).pop(_emailController.text.trim().toLowerCase());
    } on ReinitialisationException catch (e) {
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
            top: -100,
            right: -80,
            child: Halo(size: 260, color: Color(0x2EEE1D52)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BoutonRetour(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(height: 28),
                  _Etapes(etape: _codeEnvoye ? 2 : 1),
                  const SizedBox(height: 18),
                  Text(
                    _codeEnvoye
                        ? 'Nouveau mot\nde passe.'
                        : 'Mot de passe\noublié ?',
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _codeEnvoye
                        ? 'Un code à 6 chiffres vient d\'être envoyé à '
                              '${_emailController.text.trim()}. Il est '
                              'valable ${MotDePasseOublieService.validiteMinutes} '
                              'minutes. Pense à regarder dans les spams.'
                        : 'Entre l\'email de ton compte : on t\'envoie un code '
                              'pour choisir un nouveau mot de passe.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (_codeEnvoye) _buildEtapeCode() else _buildEtapeEmail(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtapeEmail() {
    return Form(
      key: _formEmail,
      child: Column(
        children: [
          AppTextField(
            label: 'Email',
            hint: 'toi@exemple.com',
            icon: Icons.mail_outline,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            maxLength: Validators.emailMax,
            validator: (v) =>
                Validators.email(v) ??
                (v?.trim().toLowerCase() == _emailInconnu
                    ? "Aucun compte n'utilise cette adresse"
                    : null),
            onSubmitted: (_) => _envoyerCode(),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Envoyer le code',
            loading: _loading,
            onPressed: _envoyerCode,
          ),
        ],
      ),
    );
  }

  Widget _buildEtapeCode() {
    return Form(
      key: _formCode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'Code reçu par email',
            hint: '123456',
            icon: Icons.pin_outlined,
            controller: _codeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(
                MotDePasseOublieService.longueurCode,
              ),
            ],
            validator: MotDePasseOublieService.validerCode,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Nouveau mot de passe',
            hint: '8 caractères, lettres et chiffres',
            icon: Icons.lock_reset_outlined,
            controller: _mdpController,
            isPassword: true,
            maxLength: Validators.passwordMax,
            validator: Validators.password,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Confirmer le mot de passe',
            hint: 'Retape le nouveau mot de passe',
            icon: Icons.lock_reset_outlined,
            controller: _confirmController,
            isPassword: true,
            maxLength: Validators.passwordMax,
            textInputAction: TextInputAction.done,
            validator: Validators.confirmation(() => _mdpController.text),
            onSubmitted: (_) => _reinitialiser(),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Changer le mot de passe',
            loading: _loading,
            onPressed: _reinitialiser,
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: _attenteRenvoi > 0 || _loading
                      ? null
                      : _envoyerCode,
                  style: TextButton.styleFrom(foregroundColor: AppColors.cyan),
                  child: Text(
                    _attenteRenvoi > 0
                        ? 'Renvoyer le code ($_attenteRenvoi s)'
                        : 'Renvoyer le code',
                  ),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                          _codeEnvoye = false;
                          _codeController.clear();
                        }),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Changer d\'email'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur « Étape 1 / 2 »
class _Etapes extends StatelessWidget {
  final int etape;
  const _Etapes({required this.etape});

  @override
  Widget build(BuildContext context) {
    Widget barre(bool active) => Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: active ? AppColors.red : AppColors.fieldBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
    return Row(
      children: [
        barre(true),
        const SizedBox(width: 6),
        barre(etape == 2),
        const SizedBox(width: 12),
        Text(
          'Étape $etape / 2',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _BoutonRetour extends StatelessWidget {
  final VoidCallback onTap;
  const _BoutonRetour({required this.onTap});

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
