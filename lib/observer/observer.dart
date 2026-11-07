import 'dart:async';

import 'package:flutter/foundation.dart';

/// ============================================================
///  DESIGN PATTERN OBSERVER
/// ============================================================
///
/// Un SUJET (l'observé) garde une liste d'OBSERVATEURS. Quand un
/// événement se produit, il les prévient tous en appelant leur méthode
/// [Observateur.mettreAJour]. Le sujet ne connaît pas les classes
/// concrètes de ses observateurs : seulement cette interface.
///
///   Sujet ──notifie──► Observateur 1
///         ──notifie──► Observateur 2 …
///
/// Avantage : on ajoute un nouveau comportement (notification, journal,
/// email…) en ajoutant un observateur, SANS modifier le sujet.

/// L'OBSERVATEUR : reçoit les événements de type [E].
abstract interface class Observateur<E> {
  /// Appelé par le sujet à chaque événement
  FutureOr<void> mettreAJour(E evenement);
}

/// Le SUJET : gère ses abonnés et les notifie.
/// S'utilise comme mixin : `class X with Sujet<MonEvenement>`.
mixin Sujet<E> {
  final List<Observateur<E>> _observateurs = [];

  /// Ajoute un observateur (sans doublon)
  void abonner(Observateur<E> observateur) {
    if (!_observateurs.contains(observateur)) _observateurs.add(observateur);
  }

  /// Retire un observateur (ex : un écran qui se ferme)
  void desabonner(Observateur<E> observateur) =>
      _observateurs.remove(observateur);

  /// Retire tous les observateurs
  void desabonnerTous() => _observateurs.clear();

  int get nbObservateurs => _observateurs.length;

  /// Prévient chaque observateur, dans l'ordre d'abonnement.
  /// Si un observateur plante, les suivants sont quand même prévenus.
  @protected
  Future<void> notifierObservateurs(E evenement) async {
    // copie : un observateur peut se désabonner pendant la notification
    for (final o in List.of(_observateurs)) {
      try {
        await o.mettreAJour(evenement);
      } catch (e) {
        debugPrint('[OBSERVER] ❌ ${o.runtimeType} : $e');
      }
    }
  }
}
