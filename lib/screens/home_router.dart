import 'package:flutter/material.dart';

import '../models/user.dart';
import 'client/client_home.dart';
import 'freelancer/freelancer_home.dart';

/// Renvoie l'espace qui correspond au rôle de l'utilisateur.
Widget accueilPour(User user) =>
    user.role == 'client' ? ClientHome(user: user) : FreelancerHome(user: user);
