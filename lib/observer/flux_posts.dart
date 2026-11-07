import 'evenements.dart';
import 'observer.dart';

/// SUJET n°1 : le flux des posts publiés.
///
/// [PostService.insertPost] appelle [publier] après avoir enregistré un
/// post ; tous les observateurs abonnés sont alors prévenus. Le
/// PostService ne sait pas qui écoute (notifications, journal…).
class FluxPosts with Sujet<PostPublie> {
  FluxPosts._();
  static final instance = FluxPosts._(); // un seul flux pour toute l'app

  Future<void> publier(PostPublie evenement) => notifierObservateurs(evenement);
}
