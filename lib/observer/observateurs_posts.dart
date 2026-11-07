import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../services/abonnement_service.dart';
import '../services/notification_service.dart';
import 'evenements.dart';
import 'flux_posts.dart';
import 'observer.dart';

/// OBSERVATEUR n°1 du flux des posts :
/// quand un client publie, crée une notification pour chacun des
/// freelancers qui le suivent.
class NotifieurAbonnes implements Observateur<PostPublie> {
  final AbonnementService _abonnements;
  final NotificationService _notifications;

  NotifieurAbonnes({
    AbonnementService? abonnements,
    NotificationService? notifications,
  }) : _abonnements = abonnements ?? AbonnementService(),
       _notifications = notifications ?? NotificationService.instance;

  @override
  Future<void> mettreAJour(PostPublie e) async {
    final abonnes = await _abonnements.abonnes(e.post.clientId);
    debugPrint(
      '[OBSERVER] NotifieurAbonnes : post #${e.postId} de @${e.clientNom} '
      '→ ${abonnes.length} abonné(s) à notifier',
    );
    final date = DateTime.now().toIso8601String();
    await _notifications.creerPour(
      abonnes,
      (freelancerId) => AppNotification(
        userId: freelancerId,
        type: AppNotification.typeNouveauPost,
        titre: '@${e.clientNom} a publié une nouvelle mission',
        contenu: e.post.titre,
        postId: e.postId,
        acteurId: e.post.clientId,
        dateCreation: date,
      ),
    );
  }
}

/// OBSERVATEUR n°2 : écrit chaque publication dans le terminal.
/// Montre qu'on ajoute un comportement sans toucher au PostService.
class JournalPublications implements Observateur<PostPublie> {
  @override
  void mettreAJour(PostPublie e) => debugPrint(
    '[OBSERVER] JournalPublications : « ${e.post.titre} » publié par '
    '@${e.clientNom} (post #${e.postId})',
  );
}

/// Branche les observateurs sur le flux des posts (appelé au démarrage).
void configurerObservateurs() {
  FluxPosts.instance
    ..desabonnerTous()
    ..abonner(NotifieurAbonnes())
    ..abonner(JournalPublications());
  debugPrint(
    '[OBSERVER] FluxPosts : ${FluxPosts.instance.nbObservateurs} '
    'observateur(s) abonné(s)',
  );
}
