import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user.dart';
import '../services/mot_de_passe_oublie_service.dart';
import '../services/verification_email_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Dernière étape de l'inscription : saisir le code reçu par email.
/// Le compte n'existe qu'après cette étape. Renvoie true s'il a été créé.
class VerificationEmailScreen extends StatefulWidget {
  final User user; // `password` en clair, gardé en mémoire seulement
  final VerificationEmailService service;
  final int attenteInitiale; // secondes avant de pouvoir renvoyer un code

  const VerificationEmailScreen({
    super.key,
    required this.user,
    required this.service,
    required this.attenteInitiale,
  });

  @override
  State<VerificationEmailScreen> createState() =>
      _VerificationEmailScreenState();
}

class _VerificationEmailScreenState extends State<VerificationEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _loading = false;
  int _attenteRenvoi = 0;
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _demarrerMinuteur(widget.attenteInitiale);
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _demarrerMinuteur(int secondes) {
    _minuteur?.cancel();
    _attenteRenvoi = secondes;
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_attenteRenvoi <= 1) t.cancel();
      setState(() => _attenteRenvoi--);
    });
  }

  // ---------- FONCTIONNALITÉ : vérifier le code et créer le compte ----------
  Future<void> _verifier() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.service.verifierEtCreer(
        user: widget.user,
        code: _codeController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on VerificationException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _renvoyer() async {
    setState(() => _loading = true);
    try {
      await widget.service.demanderCode(
        nom: widget.user.username,
        email: widget.user.email,
      );
      if (!mounted) return;
      _codeController.clear();
      setState(
        () => _demarrerMinuteur(VerificationEmailService.delaiRenvoi.inSeconds),
      );
      showAppMessage(context, 'Nouveau code envoyé ! Vérifie ta boîte mail.');
    } on AttenteRenvoiException catch (e) {
      if (!mounted) return;
      setState(() => _demarrerMinuteur(e.secondes));
      showAppMessage(context, e.message, error: true);
    } on VerificationException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppMessage(context, 'Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -100,
            right: -80,
            child: Halo(size: 260, color: Color(0x2E25F4EE)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: AppColors.fieldFill,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.fieldBorder),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(context).pop(false),
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
                    ),
                    const SizedBox(height: 28),
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 40,
                      color: AppColors.cyan,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Vérifie ton\nadresse email.',
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Un code à 6 chiffres a été envoyé à '
                      '${widget.user.email}. Il est valable '
                      '${VerificationEmailService.validiteMinutes} minutes. '
                      'Pense à regarder dans les spams.',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 26),
                    AppTextField(
                      label: 'Code reçu par email',
                      hint: '123456',
                      icon: Icons.pin_outlined,
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(
                          MotDePasseOublieService.longueurCode,
                        ),
                      ],
                      validator: MotDePasseOublieService.validerCode,
                      onSubmitted: (_) => _verifier(),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Vérifier et créer mon compte',
                      loading: _loading,
                      onPressed: _verifier,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _attenteRenvoi > 0 || _loading
                                ? null
                                : _renvoyer,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.cyan,
                            ),
                            child: Text(
                              _attenteRenvoi > 0
                                  ? 'Renvoyer le code ($_attenteRenvoi s)'
                                  : 'Renvoyer le code',
                            ),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: const Text("Changer d'email"),
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
}
