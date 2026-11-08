import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Écran d'ouverture animé : le logo « F » (identique à l'écran natif
/// Android, donc sans saut visuel) a un effet glitch, puis le nom apparaît.
/// Il reste affiché tant que [chargement] n'est pas terminé, puis ouvre
/// l'écran donné par [suivant] en fondu.
class SplashScreen<T> extends StatefulWidget {
  final Future<T> chargement;
  final Widget Function(T resultat) suivant;

  const SplashScreen({
    super.key,
    required this.chargement,
    required this.suivant,
  });

  @override
  State<SplashScreen<T>> createState() => _SplashScreenState<T>();
}

class _SplashScreenState<T> extends State<SplashScreen<T>>
    with SingleTickerProviderStateMixin {
  static const _dureeIntro = Duration(milliseconds: 1700);
  static const _tailleTuile = 120.0;
  static const _decalageFinal = 3.0; // effet glitch au repos

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: _dureeIntro,
  );

  // Le logo grossit brièvement, puis remonte pour laisser la place au nom
  late final Animation<double> _echelle = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(1), weight: 8),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.14,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 14,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.14,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 18,
    ),
    TweenSequenceItem(tween: ConstantTween(1), weight: 60),
  ]).animate(_intro);

  late final Animation<double> _montee = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.42, 0.72, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _nom = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.52, 0.82, curve: Curves.easeOut),
  );
  late final Animation<double> _halos = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
  );

  bool _introFinie = false;
  bool _ouvert = false;

  @override
  void initState() {
    super.initState();
    // après la 1re image : l'animation ne saute pas pendant le démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) => _demarrer());
  }

  Future<void> _demarrer() async {
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1; // option d'accessibilité : pas d'animation
    } else {
      await _intro.forward();
    }
    if (!mounted) return;
    setState(() => _introFinie = true);
    final resultat = await widget.chargement;
    if (!mounted || _ouvert) return;
    _ouvert = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => widget.suivant(resultat),
        transitionsBuilder: (_, animation, _, enfant) =>
            FadeTransition(opacity: animation, child: enfant),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  /// Écart des copies cyan et rouge : deux secousses, puis retour au repos
  double get _decalage {
    final t = _intro.value;
    if (t < 0.08 || t > 0.4) return _decalageFinal;
    final phase = (t - 0.08) / 0.32;
    final secousse = (phase * 6).floor().isEven ? 11.0 : 5.0;
    return _decalageFinal + secousse * (1 - phase);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _intro,
        // SizedBox.expand : le Stack occupe tout l'écran, logo bien centré
        builder: (context, _) => SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: -110,
                right: -90,
                child: Opacity(
                  opacity: _halos.value,
                  child: const Halo(size: 300, color: Color(0x38EE1D52)),
                ),
              ),
              Positioned(
                bottom: -120,
                left: -100,
                child: Opacity(
                  opacity: _halos.value,
                  child: const Halo(size: 280, color: Color(0x2B25F4EE)),
                ),
              ),
              Transform.translate(
                offset: Offset(0, -42 * _montee.value),
                child: Transform.scale(
                  scale: _echelle.value,
                  child: _Tuile(taille: _tailleTuile, decalage: _decalage),
                ),
              ),
              Transform.translate(
                offset: Offset(0, 78 + 14 * (1 - _nom.value)),
                child: Opacity(
                  opacity: _nom.value,
                  child: const GlitchText(
                    'freelance',
                    offset: 2,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              // chargement anormalement long : l'utilisateur voit que ça travaille
              if (_introFinie)
                const Positioned(
                  bottom: 64,
                  width: 120,
                  child: _BarreChargement(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tuile extends StatelessWidget {
  final double taille;
  final double decalage;
  const _Tuile({required this.taille, required this.decalage});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
      ),
      child: GlitchText(
        'F',
        offset: decalage,
        style: const TextStyle(
          fontSize: 72,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// N'apparaît qu'après un court délai : invisible si l'app est déjà prête
class _BarreChargement extends StatelessWidget {
  const _BarreChargement();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: const Interval(0.6, 1),
      builder: (_, opacite, enfant) => Opacity(opacity: opacite, child: enfant),
      child: const ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(99)),
        child: LinearProgressIndicator(
          minHeight: 3,
          color: AppColors.red,
          backgroundColor: AppColors.fieldBorder,
        ),
      ),
    );
  }
}
