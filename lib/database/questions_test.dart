/// Banque de questions des tests de compétences (table `test`).
///
/// Une question = domaine (clé de PostOptions.categories), énoncé,
/// la BONNE réponse puis 3 mauvaises. À l'insertion en base, la bonne
/// réponse est placée à une position différente selon la question
/// (colonne `bonne_reponse`), et l'écran mélange encore les choix.
///
/// 20 questions par domaine : un freelancer qui échoue reçoit un
/// nouveau test avec des questions qu'il n'a pas encore vues.
typedef QuestionSource = (
  String domaine,
  String question,
  String bonne,
  List<String> fausses,
);

const List<QuestionSource> questionsTest = [
  // ============================ DESIGN ============================
  (
    'design',
    "Quelle est la principale différence entre une image vectorielle et une image matricielle ?",
    "L'image vectorielle peut être agrandie sans perte de qualité",
    [
      "L'image matricielle est toujours plus légère",
      "L'image vectorielle ne gère pas les couleurs",
      "Il n'y a aucune différence à l'écran",
    ],
  ),
  (
    'design',
    "Quel mode colorimétrique utilise-t-on pour l'impression ?",
    'CMJN',
    ['RVB', 'HSL', 'Hexadécimal'],
  ),
  (
    'design',
    'Quel format est le plus adapté pour un logo qui doit être redimensionné ?',
    'SVG',
    ['JPEG', 'BMP', 'GIF'],
  ),
  (
    'design',
    'En typographie, que signifie « kerning » ?',
    "L'ajustement de l'espace entre deux lettres précises",
    [
      'La hauteur des lettres minuscules',
      "L'épaisseur d'un caractère",
      "L'espace entre deux lignes",
    ],
  ),
  (
    'design',
    "Que désigne l'« interlignage » ?",
    "L'espace entre les lignes d'un texte",
    [
      "L'espace entre les mots",
      "La largeur d'une colonne",
      'La marge autour de la page',
    ],
  ),
  (
    'design',
    "Quelle résolution est généralement recommandée pour l'impression ?",
    '300 dpi',
    ['72 dpi', '30 dpi', '1 dpi'],
  ),
  (
    'design',
    'Une police « serif » se reconnaît…',
    'À ses empattements au bout des traits',
    [
      "À l'absence de tout empattement",
      'À ses lettres manuscrites',
      'À ses majuscules uniquement',
    ],
  ),
  (
    'design',
    'Quelles couleurs sont complémentaires sur le cercle chromatique ?',
    'Bleu et orange',
    ['Bleu et violet', 'Rouge et rose', 'Vert et jaune'],
  ),
  (
    'design',
    "Qu'est-ce qu'une charte graphique ?",
    "Un document qui fixe les règles visuelles d'une marque",
    [
      'Un contrat entre le client et le designer',
      'Un logiciel de dessin',
      'Un format de fichier',
    ],
  ),
  (
    'design',
    "En design d'interface, à quoi sert un « wireframe » ?",
    "À schématiser la structure d'une page avant le design final",
    [
      'À ajouter des animations',
      'À imprimer une maquette',
      'À compresser les images',
    ],
  ),
  (
    'design',
    'Que signifie « UX » ?',
    'Expérience utilisateur',
    ['Interface utilisateur', 'Extension universelle', 'Export unique'],
  ),
  (
    'design',
    'Quel logiciel est surtout utilisé pour le dessin vectoriel ?',
    'Adobe Illustrator',
    ['Adobe Premiere Pro', 'Audacity', 'Microsoft Excel'],
  ),
  (
    'design',
    'Quel outil collaboratif est très utilisé pour maquetter des interfaces ?',
    'Figma',
    ['Lightroom', 'DaVinci Resolve', 'Audacity'],
  ),
  (
    'design',
    'À quoi sert la « règle des tiers » ?',
    "À composer une image de façon équilibrée",
    [
      "À calculer le prix d'un projet",
      'À choisir trois polices',
      "À réduire le poids d'un fichier",
    ],
  ),
  (
    'design',
    "Qu'est-ce que l'« espace négatif » ?",
    "L'espace vide autour et entre les éléments",
    ['Une couleur sombre', "Une erreur d'impression", 'Une zone floue'],
  ),
  (
    'design',
    'À quelle couleur correspond le code #FFFFFF ?',
    'Blanc',
    ['Noir', 'Rouge', 'Gris moyen'],
  ),
  (
    'design',
    'En impression, le « fond perdu » est…',
    "Une marge de l'image qui dépasse la zone de coupe",
    ['Une page blanche ajoutée', 'Une encre qui bave', "Le dos d'un document"],
  ),
  (
    'design',
    'Quel format garde la transparence et convient au web ?',
    'PNG',
    ['JPEG', 'BMP', 'TIFF CMJN'],
  ),
  (
    'design',
    'Que désigne la « hiérarchie visuelle » ?',
    "L'ordre dans lequel l'œil lit les éléments",
    [
      'Le classement des designers',
      'La taille du fichier',
      'Le nombre de couleurs',
    ],
  ),
  (
    'design',
    'Un « moodboard » est…',
    "Une planche d'inspiration visuelle",
    ['Un tableau de facturation', 'Un logo animé', "Une police d'écriture"],
  ),

  // ========================= DÉVELOPPEMENT =========================
  (
    'dev',
    'Que signifie HTML ?',
    'HyperText Markup Language',
    [
      'High Tech Modern Language',
      'Hyperlink Transfer Main Logic',
      'Home Tool Markup Language',
    ],
  ),
  (
    'dev',
    'Quel langage sert à mettre en forme une page web ?',
    'CSS',
    ['SQL', 'Python', 'Bash'],
  ),
  (
    'dev',
    'Quelle commande Git envoie les commits vers le dépôt distant ?',
    'git push',
    ['git pull', 'git commit', 'git init'],
  ),
  (
    'dev',
    'Que signifie « API » ?',
    "Interface de programmation d'application",
    [
      'Application pour Internet',
      'Adresse IP automatique',
      'Algorithme de programmation interne',
    ],
  ),
  (
    'dev',
    'Quel code HTTP signifie « ressource introuvable » ?',
    '404',
    ['200', '500', '301'],
  ),
  (
    'dev',
    'Quel langage sert à interroger une base de données relationnelle ?',
    'SQL',
    ['CSS', 'HTML', 'Markdown'],
  ),
  (
    'dev',
    'Quel framework permet de créer des applis Android et iOS avec un seul code en Dart ?',
    'Flutter',
    ['Django', 'Laravel', 'Spring'],
  ),
  (
    'dev',
    'Que permet une requête SQL « SELECT » ?',
    'Lire des données',
    ['Supprimer une table', 'Créer un utilisateur', 'Sauvegarder le serveur'],
  ),
  (
    'dev',
    'Que signifie « responsive design » ?',
    "Un site qui s'adapte à toutes les tailles d'écran",
    [
      'Un site très rapide',
      'Un site sans images',
      'Un site uniquement pour mobile',
    ],
  ),
  (
    'dev',
    'Sur un site web, où JavaScript s’exécute-t-il principalement ?',
    'Dans le navigateur',
    [
      'Dans la base de données uniquement',
      "Dans l'imprimante",
      'Seulement sur Windows',
    ],
  ),
  (
    'dev',
    'Quel format est le plus utilisé pour échanger des données entre une API et une application ?',
    'JSON',
    ['DOCX', 'MP3', 'PSD'],
  ),
  (
    'dev',
    "Qu'apporte HTTPS par rapport à HTTP ?",
    'Il chiffre les échanges entre le navigateur et le serveur',
    [
      'Il rend le site plus coloré',
      'Il augmente la taille des images',
      'Il supprime les cookies',
    ],
  ),
  (
    'dev',
    'À quoi sert une boucle « for » ?',
    'À répéter des instructions',
    [
      'À déclarer une couleur',
      'À fermer un programme',
      'À créer une base de données',
    ],
  ),
  (
    'dev',
    "En programmation orientée objet, qu'est-ce qu'une « classe » ?",
    'Un modèle pour créer des objets',
    ['Une erreur de compilation', 'Un type de serveur', 'Une base de données'],
  ),
  (
    'dev',
    'Quelle faille consiste à injecter du code dans une requête de base de données ?',
    'Injection SQL',
    ['Phishing', 'Attaque DDoS', 'Spam'],
  ),
  (
    'dev',
    'Que fait la commande « git clone » ?',
    'Elle copie un dépôt distant sur sa machine',
    [
      'Elle supprime une branche',
      'Elle fusionne deux branches',
      'Elle annule un commit',
    ],
  ),
  (
    'dev',
    'Que désigne le « front-end » ?',
    "La partie visible de l'application, côté utilisateur",
    [
      'Le serveur et la base de données',
      'Le réseau électrique',
      'La facturation',
    ],
  ),
  (
    'dev',
    'Dans une table SQL, une clé primaire…',
    'Identifie chaque ligne de façon unique',
    [
      'Chiffre la base de données',
      'Contient le mot de passe',
      'Trie automatiquement les colonnes',
    ],
  ),
  (
    'dev',
    'Quel outil permet de lancer une application et ses dépendances dans un conteneur ?',
    'Docker',
    ['Photoshop', 'Excel', 'Zoom'],
  ),
  (
    'dev',
    "Quel est l'intérêt principal des tests automatisés ?",
    'Détecter les régressions quand on modifie le code',
    [
      "Rendre l'application plus belle",
      'Remplacer la documentation',
      'Accélérer Internet',
    ],
  ),

  // ============================= VIDÉO =============================
  (
    'video',
    "Combien d'images par seconde utilise le standard du cinéma ?",
    '24',
    ['10', '48 obligatoirement', '120'],
  ),
  (
    'video',
    'Quelle est la résolution Full HD ?',
    '1920 × 1080',
    ['1280 × 720', '3840 × 2160', '640 × 480'],
  ),
  (
    'video',
    'À quelle résolution correspond la « 4K UHD » ?',
    '3840 × 2160',
    ['1920 × 1080', '2560 × 1440', '7680 × 4320'],
  ),
  (
    'video',
    "Qu'est-ce que l'étalonnage (color grading) ?",
    "L'ajustement des couleurs et de l'ambiance des images",
    [
      'La coupe des séquences',
      "L'ajout de sous-titres",
      'La compression du son',
    ],
  ),
  (
    'video',
    'Quel format d’image convient à YouTube ou à un écran de télévision ?',
    '16:9',
    ['9:16', '1:1', '4:5'],
  ),
  (
    'video',
    'Quel format convient aux Reels et aux vidéos TikTok ?',
    '9:16 vertical',
    ['16:9 horizontal', '21:9', '4:3'],
  ),
  (
    'video',
    'Un « jump cut » est…',
    'Une coupe brusque dans un même plan',
    ['Un fondu enchaîné', 'Un ralenti', 'Un plan aérien'],
  ),
  (
    'video',
    'À quoi sert un fond vert ?',
    "À remplacer l'arrière-plan en post-production",
    ['À améliorer le son', 'À éclairer le visage', "À stabiliser l'image"],
  ),
  (
    'video',
    'Lequel de ces logiciels est un logiciel de montage vidéo ?',
    'Adobe Premiere Pro',
    ['Adobe Illustrator', 'Microsoft Word', 'Figma'],
  ),
  (
    'video',
    'Le « B-roll » désigne…',
    'Les plans de coupe qui illustrent le sujet principal',
    [
      'La deuxième caméra en panne',
      'La musique de fond',
      'Le générique de fin',
    ],
  ),
  (
    'video',
    'À quoi sert le codec H.264 ?',
    'À compresser la vidéo',
    [
      'À enregistrer uniquement le son',
      "À colorer l'image",
      'À créer des sous-titres',
    ],
  ),
  (
    'video',
    'Que montre un « plan rapproché » ?',
    'Le personnage environ du buste à la tête',
    ['Tout le paysage', 'Uniquement les pieds', 'La salle entière'],
  ),
  (
    'video',
    'Que signifie « dérusher » ?',
    'Trier et sélectionner les meilleures prises',
    ['Exporter la vidéo finale', 'Ajouter des effets', 'Acheter du matériel'],
  ),
  (
    'video',
    'Pour obtenir un ralenti fluide, il faut filmer…',
    'À une cadence élevée (60 ou 120 images/s)',
    ['À 12 images/s', 'En noir et blanc', 'Sans lumière'],
  ),
  (
    'video',
    'En vidéo, que sont les « LUT » ?',
    "Des tables de couleurs utilisées pour l'étalonnage",
    ['Des micros', 'Des objectifs', 'Des sous-titres'],
  ),
  (
    'video',
    'Le « motion design » est…',
    "L'animation de graphismes et de textes",
    [
      'Le montage de mariages uniquement',
      'La prise de son',
      "L'éclairage d'un plateau",
    ],
  ),
  (
    'video',
    'Quel logiciel est réputé pour le motion design ?',
    'Adobe After Effects',
    ['Audacity', 'Excel', 'Lightroom'],
  ),
  (
    'video',
    'Que contient un fichier .SRT ?',
    'Des sous-titres',
    ['Une vidéo 4K', 'Un projet Premiere', 'Une musique'],
  ),
  (
    'video',
    'En montage, le « raccord » consiste à…',
    'Assurer la continuité entre deux plans',
    [
      'Brancher une rallonge électrique',
      "Choisir un format d'export",
      'Ajouter un filtre de couleur',
    ],
  ),
  (
    'video',
    'Que change surtout le débit binaire (bitrate) d’une vidéo ?',
    'La qualité et le poids du fichier',
    ['La durée de la vidéo', 'La langue', 'Le nombre de caméras'],
  ),

  // ============================= PHOTO =============================
  (
    'photo',
    "Quels sont les trois réglages du triangle d'exposition ?",
    "L'ouverture, la vitesse d'obturation et les ISO",
    [
      'Le zoom, le flash et le filtre',
      'La balance des blancs, le format et la netteté',
      'Le contraste, la saturation et la luminosité',
    ],
  ),
  (
    'photo',
    'Que donne une grande ouverture (par exemple f/1.8) ?',
    'Une faible profondeur de champ (arrière-plan flou)',
    [
      "Une image nette du premier plan à l'infini",
      'Une image plus sombre',
      'Une photo en noir et blanc',
    ],
  ),
  (
    'photo',
    'Augmenter les ISO permet…',
    'De photographier avec moins de lumière, mais avec plus de bruit',
    ['De supprimer le bruit', "D'agrandir l'image", "De changer d'objectif"],
  ),
  (
    'photo',
    'Pour figer un sujet qui bouge vite, on utilise…',
    "Une vitesse d'obturation rapide (1/1000 s)",
    ['Une vitesse lente (1 s)', 'Des ISO très bas', 'Le format JPEG'],
  ),
  (
    'photo',
    'Le format RAW…',
    'Conserve toutes les données du capteur pour la retouche',
    [
      'Est le format le plus léger',
      'Ne peut pas être retouché',
      'Est réservé aux smartphones',
    ],
  ),
  (
    'photo',
    'La « golden hour » est…',
    'Le moment juste après le lever ou avant le coucher du soleil',
    ['Midi en plein soleil', 'La nuit noire', "L'heure de la retouche"],
  ),
  (
    'photo',
    'À quoi sert la balance des blancs ?',
    'À corriger les dominantes de couleur selon la lumière',
    [
      'À régler la mise au point',
      'À augmenter la netteté',
      'À choisir le format',
    ],
  ),
  (
    'photo',
    'Un objectif de 50 mm sur un appareil plein format est considéré comme…',
    'Standard, proche de la vision humaine',
    [
      'Un ultra grand-angle',
      'Un super téléobjectif',
      'Un objectif réservé à la macro',
    ],
  ),
  (
    'photo',
    'Un téléobjectif sert surtout à…',
    'Photographier des sujets éloignés',
    [
      "Photographier sous l'eau",
      'Photographier un intérieur étroit',
      'Retoucher les photos',
    ],
  ),
  (
    'photo',
    'Que montre un histogramme ?',
    "La répartition des tons de l'image, du noir au blanc",
    [
      'Le nombre de photos prises',
      'Le niveau de batterie',
      'La date de prise de vue',
    ],
  ),
  (
    'photo',
    'Quel logiciel est conçu pour trier et développer des photos ?',
    'Adobe Lightroom',
    ['Adobe Premiere Pro', 'Figma', 'VS Code'],
  ),
  (
    'photo',
    'Le « bokeh » désigne…',
    "La qualité du flou d'arrière-plan",
    ['Un type de flash', 'Un format de fichier', 'Un trépied'],
  ),
  (
    'photo',
    'Un « packshot » est…',
    'Une photo de produit sur fond neutre, pour la vente',
    ['Une photo de groupe', 'Un selfie', 'Une photo de nuit'],
  ),
  (
    'photo',
    'Une pose longue (par exemple 10 secondes) nécessite surtout…',
    'Un trépied',
    ['Des ISO très élevés', 'Un flash puissant', 'Un objectif macro'],
  ),
  (
    'photo',
    'Une surexposition rend l’image…',
    'Trop claire, avec des blancs « brûlés »',
    ['Trop sombre', 'Floue', 'En noir et blanc'],
  ),
  (
    'photo',
    "Par défaut, à qui appartiennent les droits d'auteur d'une photo ?",
    'Au photographe',
    ['À la personne photographiée', "À la marque de l'appareil", 'À Internet'],
  ),
  (
    'photo',
    'En portrait, pourquoi utilise-t-on souvent une ouverture f/2.8 ?',
    "Pour détacher le sujet de l'arrière-plan",
    [
      'Pour que tout soit net',
      'Pour photographier les étoiles',
      'Pour économiser la batterie',
    ],
  ),
  (
    'photo',
    'La profondeur de champ augmente quand…',
    'On ferme le diaphragme (par exemple f/11)',
    ['On ouvre au maximum (f/1.4)', 'On monte les ISO', 'On utilise le flash'],
  ),
  (
    'photo',
    'Le mode « priorité ouverture » (A ou Av) permet…',
    "De choisir l'ouverture, l'appareil règle la vitesse",
    [
      'De tout régler automatiquement',
      'De choisir uniquement les ISO',
      'De filmer en 4K',
    ],
  ),
  (
    'photo',
    'Les photos de mariage livrées au client sont généralement…',
    'Sélectionnées et retouchées',
    [
      'Livrées brutes en RAW uniquement',
      'Imprimées sans fichier numérique',
      'Floutées',
    ],
  ),

  // =========================== RÉDACTION ===========================
  (
    'redaction',
    'Que signifie « SEO » ?',
    'Le référencement naturel sur les moteurs de recherche',
    [
      "Un logiciel d'édition en ligne",
      "Un service d'envoi d'e-mails",
      "Des statistiques d'écriture",
    ],
  ),
  (
    'redaction',
    "Qu'est-ce qu'un « call-to-action » ?",
    'Une incitation claire à agir (ex. « Réservez maintenant »)',
    ['Un titre de chapitre', 'Une note de bas de page', 'Une citation'],
  ),
  (
    'redaction',
    'La règle de la « pyramide inversée » consiste à…',
    "Mettre l'information essentielle au début",
    [
      'Garder la conclusion pour la fin',
      'Écrire en vers',
      "N'utiliser que des questions",
    ],
  ),
  (
    'redaction',
    'En rédaction, un « persona » est…',
    'Le portrait du lecteur ou client type',
    ["Un pseudonyme d'auteur", 'Un style de police', 'Un type de contrat'],
  ),
  (
    'redaction',
    'Le plagiat, c’est…',
    "Reprendre le texte d'un autre sans le citer",
    [
      'Résumer un texte en le citant',
      'Traduire son propre texte',
      'Corriger des fautes',
    ],
  ),
  (
    'redaction',
    'À quoi sert une méta-description ?',
    'À résumer la page dans les résultats de recherche',
    ['À décorer la page', 'À ajouter une image', 'À chiffrer le texte'],
  ),
  (
    'redaction',
    'Le « copywriting » est…',
    'La rédaction persuasive destinée à vendre ou convaincre',
    [
      'La copie de textes existants',
      "La protection des droits d'auteur",
      'La mise en page',
    ],
  ),
  (
    'redaction',
    'Quelle phrase est correctement accordée ?',
    '« Les offres qu’elle a envoyées »',
    [
      '« Les offres qu’elle a envoyé »',
      '« Les offres qu’elle a envoyés »',
      '« Les offres qu’elle à envoyées »',
    ],
  ),
  (
    'redaction',
    'Un bon titre pour le web doit être…',
    'Clair, précis et contenir le mot-clé principal',
    ['Le plus long possible', 'Écrit tout en majuscules', 'Sans aucun mot-clé'],
  ),
  (
    'redaction',
    'Le « storytelling » consiste à…',
    "Raconter une histoire pour capter l'attention",
    [
      'Lister des chiffres sans contexte',
      'Écrire uniquement des slogans',
      'Traduire un roman',
    ],
  ),
  (
    'redaction',
    'Pourquoi préfère-t-on souvent la voix active ?',
    'Elle rend la phrase plus directe et dynamique',
    [
      'Elle rallonge les phrases',
      'Elle est plus formelle',
      'Elle évite les verbes',
    ],
  ),
  (
    'redaction',
    'Dans un article, le « chapô » est…',
    "Le court paragraphe d'introduction sous le titre",
    ["La signature de l'auteur", 'La dernière phrase', 'Une illustration'],
  ),
  (
    'redaction',
    'Quelle forme est correcte ?',
    '« Quoi qu’il arrive »',
    ['« Quoiqu’il arrive »', '« Quoi qu’il arrives »', '« Quoiqu’il arrives »'],
  ),
  (
    'redaction',
    'Pour un article de blog facile à lire, il faut…',
    'Des intertitres, des paragraphes courts et des listes',
    [
      'Un seul gros bloc de texte',
      'Aucune ponctuation',
      'Des phrases de 80 mots',
    ],
  ),
  (
    'redaction',
    'Le « ghostwriting » consiste à…',
    "Écrire un texte qui sera signé par quelqu'un d'autre",
    [
      "Écrire des histoires d'horreur",
      'Écrire de façon anonyme sur les réseaux',
      'Corriger des textes',
    ],
  ),
  (
    'redaction',
    'Que contient un « brief » de rédaction ?',
    "L'objectif, la cible, le ton et les mots-clés attendus",
    ['Uniquement le prix', 'Le texte final', 'La facture'],
  ),
  (
    'redaction',
    'Quelle formule convient à un e-mail professionnel ?',
    '« Je vous remercie pour votre retour. »',
    ['« Merci, ciao ! »', '« Réponds vite stp »', '« Slt, ok »'],
  ),
  (
    'redaction',
    'En SEO, le « maillage interne » consiste à…',
    "Créer des liens entre les pages d'un même site",
    ['Acheter des liens', 'Traduire le site', 'Supprimer des pages'],
  ),
  (
    'redaction',
    'Le « ton éditorial » d’une marque, c’est…',
    'Sa façon constante de s’exprimer (formelle, amicale…)',
    [
      'La couleur de son logo',
      "Le nombre d'articles par mois",
      'Le prix de ses textes',
    ],
  ),
  (
    'redaction',
    '« Il faut que vous ___ à l’heure. » Quelle forme est correcte ?',
    'soyez',
    ['êtes', 'serez', 'soyiez'],
  ),

  // =========================== MARKETING ===========================
  (
    'marketing',
    'Que signifie « ROI » ?',
    'Retour sur investissement',
    [
      "Rapport d'orientation interne",
      "Revenu d'origine international",
      "Règle d'optimisation immédiate",
    ],
  ),
  (
    'marketing',
    'Quels sont les « 4P » du marketing mix ?',
    'Produit, Prix, Place (distribution), Promotion',
    [
      'Public, Partenaire, Plan, Profit',
      'Prix, Publicité, Personnel, Projet',
      'Produit, Personne, Page, Post',
    ],
  ),
  (
    'marketing',
    'Que mesure le « taux de conversion » ?',
    "La part des visiteurs qui réalisent l'action voulue",
    [
      'Le nombre total de visiteurs',
      'Le prix moyen',
      "Le nombre d'abonnés perdus",
    ],
  ),
  (
    'marketing',
    'En publicité en ligne, que signifie « CPC » ?',
    'Coût par clic',
    ['Client par campagne', 'Contenu par catégorie', 'Coût par contrat'],
  ),
  (
    'marketing',
    'Que désigne le « SEA » ?',
    'Le référencement payant (annonces sur les moteurs de recherche)',
    [
      'Le référencement naturel',
      "L'envoi de SMS",
      "L'analyse de la concurrence",
    ],
  ),
  (
    'marketing',
    'Que représente un « tunnel de conversion » ?',
    "Les étapes qui mènent un prospect jusqu'à l'achat",
    [
      'Un logiciel de montage',
      'Un type de publicité TV',
      "Le stock d'un magasin",
    ],
  ),
  (
    'marketing',
    "En quoi consiste l'« A/B testing » ?",
    'Comparer deux versions pour voir laquelle fonctionne le mieux',
    [
      'Tester un produit dans deux pays',
      'Publier deux fois le même post',
      'Changer de logo',
    ],
  ),
  (
    'marketing',
    "Qu'est-ce qu'un KPI ?",
    'Un indicateur clé de performance',
    ['Un logiciel de comptabilité', 'Un réseau social', 'Un type de contrat'],
  ),
  (
    'marketing',
    "Sur les réseaux sociaux, que mesure l'« engagement » ?",
    "Les interactions : j'aime, commentaires, partages",
    [
      'Le nombre de publications',
      'Le prix des annonces',
      "Le nombre d'employés",
    ],
  ),
  (
    'marketing',
    "Le marketing d'influence consiste à…",
    'Collaborer avec des créateurs de contenu pour toucher leur audience',
    [
      "Acheter des fichiers d'adresses",
      'Distribuer des flyers',
      'Faire baisser les prix',
    ],
  ),
  (
    'marketing',
    'En marketing, à quoi sert un « persona » ?',
    'À représenter le client idéal pour mieux le cibler',
    ['À fixer le prix', 'À choisir un logo', 'À calculer la TVA'],
  ),
  (
    'marketing',
    "Que regarde une analyse SWOT ?",
    'Les forces, faiblesses, opportunités et menaces',
    [
      'Les ventes, le web, les offres et les tarifs',
      'Les stocks, salaires, objectifs et taxes',
      "Le style, le vocabulaire, l'ordre et le titre",
    ],
  ),
  (
    'marketing',
    "Qu'est-ce que le « taux de rebond » d'un site ?",
    'La part des visiteurs qui partent après une seule page',
    [
      'Le nombre de clics sur une publicité',
      'Le temps de chargement',
      "Le nombre d'achats répétés",
    ],
  ),
  (
    'marketing',
    'Le marketing « inbound » consiste à…',
    'Attirer les clients grâce à du contenu utile',
    [
      'Appeler des prospects au hasard',
      'Envoyer des e-mails non sollicités',
      'Baisser les prix',
    ],
  ),
  (
    'marketing',
    "Quel outil gratuit de Google mesure le trafic d'un site ?",
    'Google Analytics',
    ['Google Docs', 'Google Maps', 'Google Translate'],
  ),
  (
    'marketing',
    'Le « retargeting » consiste à…',
    'Montrer des publicités aux personnes qui ont déjà visité le site',
    [
      'Changer de cible chaque jour',
      'Supprimer des annonces',
      'Cibler uniquement les nouveaux pays',
    ],
  ),
  (
    'marketing',
    'En marketing, un « lead » est…',
    'Un contact intéressé, client potentiel',
    ['Un client perdu', 'Une publicité télévisée', 'Un concurrent'],
  ),
  (
    'marketing',
    'Le « positionnement » d’une marque, c’est…',
    "La place qu'elle veut occuper dans l'esprit des clients",
    [
      'Son emplacement en magasin',
      'Sa position sur Google Maps',
      "L'ordre de ses produits",
    ],
  ),
  (
    'marketing',
    "Qu'est-ce qu'une newsletter ?",
    'Un e-mail envoyé régulièrement à des abonnés',
    [
      'Une publicité télévisée',
      'Un journal papier gratuit',
      'Un message privé sur Instagram',
    ],
  ),
  (
    'marketing',
    'À quoi sert un calendrier éditorial ?',
    'À planifier les contenus à publier',
    ['À calculer les salaires', 'À choisir les couleurs', 'À gérer les stocks'],
  ),

  // =========================== TRADUCTION ===========================
  (
    'traduction',
    "Qu'est-ce qu'un « faux ami » ?",
    "Un mot qui ressemble à un mot d'une autre langue mais n'a pas le même sens",
    ['Un traducteur malhonnête', 'Une faute de frappe', 'Un synonyme exact'],
  ),
  (
    'traduction',
    'Que signifie le mot anglais « actually » ?',
    'En fait, en réalité',
    ['Actuellement', 'Activement', 'Absolument'],
  ),
  (
    'traduction',
    'Comment traduit-on le mot anglais « eventually » ?',
    'Finalement',
    ['Éventuellement', 'Évidemment', 'Également'],
  ),
  (
    'traduction',
    'Qu’est-ce que la « langue cible » ?',
    'La langue vers laquelle on traduit',
    [
      "La langue du texte d'origine",
      'La langue maternelle du client',
      'Une langue morte',
    ],
  ),
  (
    'traduction',
    'En quoi consiste la « localisation » ?',
    "Adapter un contenu à la culture et aux usages d'un pays",
    [
      'Traduire mot à mot',
      "Trouver l'adresse d'un client",
      'Changer la police',
    ],
  ),
  (
    'traduction',
    "Qu'est-ce qu'une « mémoire de traduction » ?",
    'Une base qui réutilise les segments déjà traduits',
    ['Un dictionnaire papier', 'La mémoire du traducteur', 'Un fichier audio'],
  ),
  (
    'traduction',
    'Lequel de ces logiciels est un outil de traduction assistée par ordinateur ?',
    'SDL Trados',
    ['Adobe Premiere', 'Figma', 'Excel'],
  ),
  (
    'traduction',
    "Qu'est-ce qu'une traduction « assermentée » ?",
    'Une traduction certifiée par un traducteur agréé, avec valeur officielle',
    [
      'Une traduction faite par une machine',
      'Une traduction gratuite',
      'Une traduction non signée',
    ],
  ),
  (
    'traduction',
    'Que demande surtout le sous-titrage ?',
    'Condenser le texte pour laisser le temps de le lire',
    [
      'Traduire mot à mot',
      'Écrire en majuscules',
      'Supprimer les noms propres',
    ],
  ),
  (
    'traduction',
    '« Je suis en train de travailler » en anglais :',
    'I am working',
    ['I work since', 'I am work', 'I working'],
  ),
  (
    'traduction',
    'Que signifie le mot anglais « library » ?',
    'Bibliothèque',
    ['Librairie', 'Liberté', 'Livraison'],
  ),
  (
    'traduction',
    'Comment traduire « It’s raining cats and dogs » ?',
    'Il pleut des cordes',
    [
      'Il pleut des chats et des chiens',
      'Il fait beau',
      'Les animaux ont peur',
    ],
  ),
  (
    'traduction',
    'En quoi consiste la « post-édition » ?',
    'Corriger et améliorer une traduction automatique',
    [
      'Éditer un livre après sa vente',
      'Traduire après la date limite',
      'Publier le texte',
    ],
  ),
  (
    'traduction',
    'En traduction, un « glossaire » est…',
    'Une liste de termes validés à utiliser de façon cohérente',
    ['Un résumé du texte', 'La facture', 'La table des matières'],
  ),
  (
    'traduction',
    "Dans quel sens s'écrit l'arabe ?",
    'De droite à gauche',
    ['De gauche à droite', 'De haut en bas uniquement', 'En colonnes'],
  ),
  (
    'traduction',
    'Quel est le bon principe de traduction ?',
    'Transmettre le sens et le ton, pas seulement les mots',
    [
      'Traduire chaque mot dans le même ordre',
      'Ajouter ses opinions',
      'Raccourcir le texte de moitié',
    ],
  ),
  (
    'traduction',
    'Quelle est la différence entre un interprète et un traducteur ?',
    "L'interprète travaille à l'oral, le traducteur à l'écrit",
    [
      "C'est exactement le même métier",
      "L'interprète traduit seulement des livres",
      "Le traducteur travaille seulement à l'oral",
    ],
  ),
  (
    'traduction',
    'Que signifie « to attend a meeting » ?',
    'Assister à une réunion',
    ['Attendre une réunion', 'Annuler une réunion', 'Organiser une réunion'],
  ),
  (
    'traduction',
    "Comment est souvent calculé le tarif d'une traduction écrite ?",
    'Au mot',
    ['Au kilo', 'À la couleur', "Au nombre d'images"],
  ),
  (
    'traduction',
    'Que signifie le mot anglais « sensible » ?',
    'Raisonnable',
    ['Sensible (émotif)', 'Sensationnel', 'Sensuel'],
  ),
];
