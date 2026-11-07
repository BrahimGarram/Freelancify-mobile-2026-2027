import 'package:flutter/material.dart';

import '../models/user.dart';
import '../observer/evenements.dart';
import '../observer/observer.dart';
import '../screens/notifications_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Cloche 🔔 de l'en-tête avec le nombre de notifications non lues.
///
/// OBSERVATEUR du [NotificationService] : elle s'abonne quand elle
/// apparaît et se désabonne quand elle disparaît. Dès qu'une
/// notification est créée ou lue, le service la prévient et la pastille
/// se met à jour toute seule (sans recharger la page).
class ClocheNotifications extends StatefulWidget {
  final User user;

  /// Appelé au retour de l'écran des notifications (ex : recharger le fil)
  final VoidCallback? apresFermeture;

  const ClocheNotifications({
    super.key,
    required this.user,
    this.apresFermeture,
  });

  @override
  State<ClocheNotifications> createState() => _ClocheNotificationsState();
}

class _ClocheNotificationsState extends State<ClocheNotifications>
    implements Observateur<NotificationsModifiees> {
  final _service = NotificationService.instance;
  int _nonLues = 0;

  @override
  void initState() {
    super.initState();
    _service.abonner(this); // ← s'abonne au sujet
    _charger();
  }

  @override
  void dispose() {
    _service.desabonner(this); // ← se désabonne (évite les fuites)
    super.dispose();
  }

  /// Appelé par le sujet quand les notifications changent
  @override
  void mettreAJour(NotificationsModifiees e) {
    if (e.userId == widget.user.id) _charger();
  }

  Future<void> _charger() async {
    final n = await _service.nbNonLues(widget.user.id!);
    if (mounted) setState(() => _nonLues = n);
  }

  Future<void> _ouvrir() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationsScreen(user: widget.user)),
    );
    widget.apresFermeture?.call();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _nonLues > 0
          ? 'Notifications ($_nonLues non lues)'
          : 'Notifications',
      onPressed: _ouvrir,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.fieldFill,
        side: const BorderSide(color: AppColors.fieldBorder),
        fixedSize: const Size(44, 44),
      ),
      icon: Badge(
        isLabelVisible: _nonLues > 0,
        label: Text(_nonLues > 99 ? '99+' : '$_nonLues'),
        backgroundColor: AppColors.red,
        child: Icon(
          _nonLues > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          size: 21,
          color: _nonLues > 0 ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}
