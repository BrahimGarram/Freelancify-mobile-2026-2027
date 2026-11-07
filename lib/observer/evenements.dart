import '../models/post.dart';

/// Événement : un client vient de publier un post.
/// Émis par le sujet [FluxPosts].
class PostPublie {
  final int postId;
  final Post post;
  final String clientNom;

  const PostPublie({
    required this.postId,
    required this.post,
    required this.clientNom,
  });
}

/// Événement : les notifications d'un utilisateur ont changé
/// (nouvelle notification, lue, toutes lues…).
/// Émis par le sujet [NotificationService].
class NotificationsModifiees {
  final int userId;
  const NotificationsModifiees(this.userId);
}
