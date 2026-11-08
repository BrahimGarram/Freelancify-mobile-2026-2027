/// Base de connaissances du chatbot : ce que l'application sait faire.
///
/// ⚠️ À mettre à jour à chaque nouvelle fonctionnalité : l'assistant ne
/// répond qu'avec ces informations (il ne doit rien inventer).
const guideApp = '''
# Application « freelance »
Plateforme qui met en relation des CLIENTS (qui publient des missions) et des
FREELANCERS (qui postulent). Monnaie : dinar tunisien (DT). Toutes les données
restent sur le téléphone : l'application fonctionne sans Internet, sauf
l'assistant IA et le remplissage automatique d'un post par l'IA.

## Compte
- Inscription : choisir le rôle Client ou Freelancer (le rôle ne peut pas être
  changé ensuite ; il faut créer un autre compte), nom d'utilisateur (3 à 20
  caractères : lettres, chiffres, . _ -), email, mot de passe (8 caractères
  minimum avec au moins une lettre et un chiffre, sans espace) et confirmation.
- Vérification de l'email à l'inscription (client et freelancer) : un code à
  6 chiffres est envoyé à l'adresse saisie (valable 15 minutes, 5 essais,
  regarder aussi les spams). Le compte n'est créé qu'une fois le code saisi.
  Bouton « Renvoyer le code » après 60 secondes. Nécessite Internet.
- Connexion avec email + mot de passe. La session reste ouverte au prochain
  lancement jusqu'à la déconnexion.
- « Mot de passe oublié ? » (écran de connexion) : entrer l'email du compte,
  un code à 6 chiffres est envoyé par email (valable 15 minutes, 5 essais,
  regarder aussi les spams), puis saisir le code et le nouveau mot de passe.
  Bouton « Renvoyer le code » après 60 secondes. Nécessite Internet.
- Les mots de passe sont chiffrés (hachés), jamais stockés en clair.

## Onglet Profil (client et freelancer)
- Carte avec nom, email, rôle ; statistiques.
- « Modifier le profil » : nom d'utilisateur, email, et changement du mot de
  passe (il faut le mot de passe actuel). Le freelancer y ajoute aussi son
  métier (facultatif, 2 à 50 caractères) et sa bio (500 caractères max.).
- « Se déconnecter » en bas (avec confirmation).

## CLIENT
Barre du bas : Mes posts, Candidatures, bouton « + », Messages, Profil.

### Publier un post (bouton « + »)
Champs : titre (5 à 80 caractères), 1 à 3 catégories (Design, Développement,
Vidéo, Photo, Rédaction, Marketing, Traduction, Autre), description (20 à 1000
caractères), type de budget (prix fixe ou par heure), budget (max 1 000 000 DT
en fixe, 500 DT/h en horaire), date limite (de demain à 1 an), mode de travail
(à distance, sur place, hybride), ville (un des 24 gouvernorats, seulement sur
place ou hybride), compétences recherchées (jusqu'à 5, facultatif), option
« Mission urgente » (badge Urgent). On publie avec le bouton
« Publier le post » tout en bas du formulaire ; les champs en rouge sont à
corriger avant.
- Aide IA : carte « Remplir avec l'IA » en haut du formulaire ; le client
  décrit son besoin avec ses mots puis touche « Remplir le formulaire » ;
  l'IA remplit les champs et rédige titre et description. Ce que le client n'a
  pas précisé reste vide. Il faut tout relire avant de publier. Nécessite
  Internet.

### Mes posts
Liste des posts avec statut (Ouvert, En cours, Terminé) et nombre de
candidatures. Un post peut être supprimé (icône corbeille, avec confirmation).

### Candidatures reçues
- À chaque nouvelle candidature, le client reçoit aussi un email (à l'adresse
  de son compte ; regarder les spams la première fois).
- Chaque carte : freelancer, mission, message de candidature (toucher pour le
  lire en entier), statut (En attente, Acceptée, Refusée).
- Toucher le nom ou l'avatar du freelancer ouvre son profil public : métier,
  bio, nombre de réalisations et de missions acceptées, portfolio.
- Accepter : la candidature est acceptée, les autres candidatures du même post
  sont refusées automatiquement et le post passe « En cours » (il disparaît du
  fil des freelancers). Refuser : la discussion est fermée.
- « Discuter » ouvre la conversation avec le freelancer.

## FREELANCER
Barre du bas : Missions, Candidatures, bouton « + », Messages, Profil.

### Missions
Fil des posts ouverts (titre, budget, catégories, lieu, date limite,
compétences, badge Urgent). Bouton « Postuler » : écrire un message au client
(20 à 500 caractères). On ne peut postuler qu'une fois par mission (« Postulé »).
Il faut d'abord avoir réussi un test de compétences : sans certification,
« Postuler » affiche « Certification requise » avec le bouton « Passer le test ».
Pas encore de recherche ni de filtres dans le fil.

### Tests et certifications (Profil > « Tests et certifications »)
- « Passer un test » : au 1er test, choisir un ou plusieurs domaines (Design,
  Développement, Vidéo, Photo, Rédaction, Marketing, Traduction). Ils sont
  ajoutés au profil et ne peuvent PLUS être changés : les tests suivants
  portent sur ces mêmes domaines.
- Quiz de 10 questions à 4 choix. Chaque question a son chronomètre (20 à
  60 s selon sa longueur). Temps écoulé : la question compte comme fausse et
  on passe à la suivante. Pas de retour aux questions précédentes.
- Résultat immédiat : score, détail par domaine et correction.
- 3 tentatives au maximum ; un test commencé compte, même abandonné. Une
  fois le test réussi, il ne se repasse pas.
- « Rapport de l'IA » après chaque test (Internet nécessaire) : synthèse,
  points forts, points à améliorer et conseils. Bouton « Afficher » /
  « Masquer ». On le retrouve sur l'écran du certificat et dans
  l'historique (toucher un test). Il est privé : les clients ne le voient
  pas.
- Au moins 50 % : certification « freelance » avec le nom du freelancer, son
  métier, les domaines, les compétences validées, le score, une mention
  (Passable, Bien, Très bien, Excellent), la date et un numéro unique.
- Moins de 50 % : « Refaire un test » (s'il reste des tentatives) ; les
  nouvelles questions sont différentes de celles déjà vues.
- Les certifications apparaissent sur le profil public, visibles par les
  clients (ils peuvent ouvrir le certificat).
- Sur le certificat : « Télécharger le PDF » (enregistré dans
  Téléchargements) et « Partager / imprimer ».

### Suivre un client et notifications
- Sur chaque mission du fil, bouton « Suivre » à côté du nom du client
  (devient « Suivi » ; toucher à nouveau pour ne plus suivre).
- Quand un client suivi publie une mission, le freelancer reçoit une
  notification dans l'app : cloche 🔔 en haut de l'écran, avec une pastille
  rouge pour les non lues. Toucher une notification ouvre directement
  « Postuler » pour cette mission. « Tout marquer comme lu » en haut.
- Profil > « Clients suivis » : la liste et « Ne plus suivre ».
- Côté client : le nombre d'« Abonnés » (freelancers qui le suivent) est
  affiché dans l'onglet Profil ; après une publication, l'app indique combien
  d'abonnés ont été notifiés.

### Mes candidatures
Statut de chaque candidature (En attente, Acceptée, Refusée) et bouton
« Discuter ».

### Portfolio (bouton « + » ou Profil > « Ajouter une réalisation »)
Une réalisation = projet, expérience ou site réalisé : photo facultative
(galerie ou appareil photo, jpg/png/webp, 5 Mo max), titre (5 à 80
caractères), catégorie, description (20 à 1000 caractères), client
(facultatif), lien (facultatif, adresse web valide). Elle apparaît sur le
profil public, visible par les clients. Supprimable depuis « Mon profil
public ».
- Le bloc « Complète ton profil » (onglet Profil) guide : métier, bio,
  première réalisation. Un profil complet inspire confiance aux clients.

## Messages (client et freelancer)
- Une discussion par candidature. Le message de candidature est le premier
  message.
- Messages de 1 à 1000 caractères. Pastille rouge = messages non lus.
- Le client peut accepter ou refuser depuis le bandeau de la discussion.
- Une discussion dont la candidature est refusée est fermée (lecture seule).
- Comme les données sont sur le téléphone, client et freelancer échangent
  sur le même appareil.

## Pas disponible actuellement
Paiement en ligne, notation/avis, notifications push (hors de l'app),
recherche de missions, modification d'un post publié, visio.
''';
