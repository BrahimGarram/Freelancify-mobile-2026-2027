import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

import 'questions_test.dart';

import '../services/password_hasher.dart';

class DatabaseHelper {
  // Singleton
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  /// Chemin de la base. Modifiable uniquement pour les tests
  /// (ex. `inMemoryDatabasePath`) ; null = app.db dans le dossier par défaut.
  static String? overridePath;

  /// Ferme la base (utilisé par les tests pour repartir de zéro).
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path =
        overridePath ??
        (kIsWeb ? 'freelancify.db' : join(await getDatabasesPath(), 'app.db'));

    return await openDatabase(
      path,
      // Version 2 : ajout des tables posts et candidatures.
      // Version 3 : les mots de passe sont hachés (plus jamais en clair).
      // Version 4 : nouveaux champs des posts (catégorie, délai, mode…).
      // Version 5 : table messages (discussion client ↔ freelancer).
      // Version 6 : profil freelancer (métier, bio) + table realisations.
      // Version 7 : file d'attente des emails (notifications).
      // Version 8 : codes de réinitialisation (mot de passe oublié).
      // Version 9 : abonnements (freelancer suit un client) + notifications.
      // Version 10 : tests de compétences (table test, tentatives,
      //              réponses) et certifications.
      // Version 11 : durée de chaque question, domaines fixés sur le profil
      //              du freelancer, réponse vide si le temps est écoulé.
      // Version 12 : 3 tentatives max (une tentative compte dès le début du
      //              test) et rapports de l'IA après chaque test.
      // Versions 13 à 18 : deux séries développées en parallèle, avec les
      // mêmes numéros pour des changements différents :
      //  - tests : vérification de l'email, demandes de tentative et statut ;
      //  - projets : projets, tâches, soumission du travail, CofeeCoins.
      // Version 19 : réunit les deux séries (voir _reunirSeries13a18).
      // Si l'app était déjà installée, onUpgrade met la base à jour
      // sans effacer tes utilisateurs.
      version: 19,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Active les clés étrangères (désactivées par défaut dans SQLite)
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Première installation : on crée toutes les tables
  Future<void> _onCreate(Database db, int version) async {
    await _createUsers(db);
    await _createPosts(db);
    await _createCandidatures(db);
    await _createMessages(db);
    await _createRealisations(db);
    await _createEmailsSortants(db);
    await _createCodesReinitialisation(db);
    await _createAbonnementsEtNotifications(db);
    await _createTestsEtCertifications(db);
    await _createVerificationsEmail(db);
    await _createDemandesTentative(db);
    await _createProjetsEtTaches(db);
  }

  // App déjà installée avec une ancienne version
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPosts(db); // IF NOT EXISTS : sans risque si elle existe
      await _createCandidatures(db);
    }
    if (oldVersion < 3) {
      await _hasherMotsDePasseExistants(db);
    }
    if (oldVersion < 4) {
      await _ajouterColonnesPostsV4(db);
    }
    if (oldVersion < 5) {
      await _createCandidatures(db); // IF NOT EXISTS : sans risque
      await _createMessages(db);
      // Les candidatures déjà envoyées deviennent le 1er message de leur
      // discussion (pour que le client puisse les lire et répondre).
      await db.execute('''
        INSERT INTO messages (candidature_id, expediteur_id, contenu,
                              date_envoi, lu)
        SELECT c.id, c.freelancer_id, substr(c.message, 1, 1000),
               c.date_candidature, 0
        FROM candidatures c
        WHERE length(trim(c.message)) > 0
          AND NOT EXISTS (SELECT 1 FROM messages m
                          WHERE m.candidature_id = c.id)
      ''');
    }
    if (oldVersion < 6) {
      for (final col in ['metier', 'bio']) {
        if (!await _colonneExiste(db, 'users', col)) {
          await db.execute('ALTER TABLE users ADD COLUMN $col TEXT');
        }
      }
      await _createRealisations(db);
    }
    if (oldVersion < 7) {
      await _createEmailsSortants(db);
    }
    if (oldVersion < 8) {
      await _createCodesReinitialisation(db);
    }
    if (oldVersion < 9) {
      await _createAbonnementsEtNotifications(db);
    }
    if (oldVersion < 10) {
      await _createTestsEtCertifications(db);
    }
    if (oldVersion < 11) {
      await _migrerV11(db);
    }
    if (oldVersion < 12) {
      if (!await _colonneExiste(db, 'tentatives_test', 'statut')) {
        await db.execute(
          "ALTER TABLE tentatives_test ADD COLUMN statut TEXT NOT NULL "
          "DEFAULT 'terminee'",
        );
      }
      await _createRapportsTest(db);
    }
    if (oldVersion < 19) {
      await _reunirSeries13a18(db);
    }
  }

  /// Une base « v13 à v18 » peut venir de l'une ou l'autre série : son numéro
  /// ne dit donc pas ce qu'elle contient. Chaque étape vérifie ce qui existe
  /// et n'ajoute que ce qui manque, sans perdre de données.
  Future<void> _reunirSeries13a18(Database db) async {
    // série « tests »
    await _createVerificationsEmail(db);
    await _createDemandesTentative(db);
    if (!await _colonneExiste(db, 'demandes_tentative', 'statut')) {
      await db.execute(
        "ALTER TABLE demandes_tentative ADD COLUMN statut TEXT NOT NULL "
        "DEFAULT 'en_cours'",
      );
    }

    // série « projets »
    final projetsDejaLa = await _tableExiste(db, 'projects');
    await _createProjetsEtTaches(db);
    if (!projetsDejaLa &&
        await _tableExiste(db, 'candidatures') &&
        await _colonneExiste(db, 'posts', 'date_limite')) {
      // 1re fois seulement : un projet supprimé ensuite ne revient pas
      await db.execute('''
        INSERT INTO projects (
          candidature_id, post_id, client_id, freelancer_id, title,
          description, deadline, status, created_at, updated_at
        )
        SELECT c.id, p.id, p.client_id, c.freelancer_id, p.titre,
               p.description, p.date_limite, 'en_cours',
               c.date_candidature, c.date_candidature
        FROM candidatures c
        JOIN posts p ON p.id = c.post_id
        WHERE c.statut = 'acceptee'
      ''');
    }
    for (final column in {
      'drive_url': 'TEXT',
      'github_url': 'TEXT',
      'attachment_name': 'TEXT',
      'attachment_mime': 'TEXT',
      'attachment_bytes': 'BLOB',
    }.entries) {
      if (!await _colonneExiste(db, 'project_tasks', column.key)) {
        await db.execute(
          'ALTER TABLE project_tasks ADD COLUMN ${column.key} ${column.value}',
        );
      }
    }
    await _ajouterColonnesSoumission(db);
    await _ajouterCofeeCoins(db);
    await _ajouterCofeeCoinsDonnes(db);
  }

  Future<bool> _tableExiste(Database db, String table) async {
    final l = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table' AND name = ?",
      whereArgs: [table],
    );
    return l.isNotEmpty;
  }

  Future<void> _ajouterColonnesSoumission(Database db) async {
    for (final column in {
      'work_description': 'TEXT',
      'work_link': 'TEXT',
      'work_attachment_name': 'TEXT',
      'work_attachment_mime': 'TEXT',
      'work_attachment_bytes': 'BLOB',
      'review_note': 'TEXT',
      'reviewed_at': 'TEXT',
    }.entries) {
      if (!await _colonneExiste(db, 'project_tasks', column.key)) {
        await db.execute(
          'ALTER TABLE project_tasks ADD COLUMN ${column.key} ${column.value}',
        );
      }
    }
  }

  Future<void> _ajouterCofeeCoins(Database db) async {
    if (!await _colonneExiste(db, 'users', 'cofeecoins')) {
      await db.execute(
        "ALTER TABLE users ADD COLUMN cofeecoins INTEGER NOT NULL DEFAULT 0",
      );
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_rewards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL UNIQUE,
        client_id INTEGER NOT NULL,
        freelancer_id INTEGER NOT NULL,
        coins INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (client_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (freelancer_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _ajouterCofeeCoinsDonnes(Database db) async {
    if (!await _colonneExiste(db, 'users', 'cofeecoins_donnes')) {
      await db.execute(
        "ALTER TABLE users ADD COLUMN cofeecoins_donnes INTEGER NOT NULL DEFAULT 0",
      );
    }
  }

  /// Colonnes ajoutées aux posts en v4 (avec la valeur donnée aux anciens posts)
  static const _colonnesPostsV4 = {
    'categorie': "TEXT NOT NULL DEFAULT 'autre'",
    'type_budget': "TEXT NOT NULL DEFAULT 'fixe' CHECK (type_budget IN ('fixe', 'horaire'))",
    'date_limite': 'TEXT',
    'mode_travail':
        "TEXT NOT NULL DEFAULT 'distance' "
        "CHECK (mode_travail IN ('distance', 'sur_place', 'hybride'))",
    'ville': 'TEXT',
    'competences': "TEXT NOT NULL DEFAULT '[]'",
    'urgent': 'INTEGER NOT NULL DEFAULT 0 CHECK (urgent IN (0, 1))',
  };

  /// Migration v4 : ajoute seulement les colonnes qui manquent
  /// (les anciens posts gardent leurs données + valeurs par défaut).
  Future<void> _ajouterColonnesPostsV4(Database db) async {
    final infos = await db.rawQuery('PRAGMA table_info(posts)');
    if (infos.isEmpty) return _createPosts(db); // table absente : on la crée
    final existantes = infos.map((c) => c['name'] as String).toSet();
    for (final MapEntry(key: nom, value: definition)
        in _colonnesPostsV4.entries) {
      if (!existantes.contains(nom)) {
        await db.execute('ALTER TABLE posts ADD COLUMN $nom $definition');
      }
    }
  }

  /// Migration v3 : remplace chaque mot de passe encore en clair par son hash.
  /// Les utilisateurs gardent le même mot de passe pour se connecter.
  Future<void> _hasherMotsDePasseExistants(Database db) async {
    final users = await db.query('users', columns: ['id', 'password']);
    final batch = db.batch();
    for (final u in users) {
      final password = u['password'] as String;
      if (PasswordHasher.isHashed(password)) continue;
      batch.update(
        'users',
        {'password': PasswordHasher.hash(password)},
        where: 'id = ?',
        whereArgs: [u['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _createUsers(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('freelancer', 'client')),
        metier TEXT,
        bio TEXT,
        domaines TEXT,
        cofeecoins INTEGER NOT NULL DEFAULT 0,
        cofeecoins_donnes INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createPosts(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        titre TEXT NOT NULL,
        description TEXT NOT NULL,
        budget REAL NOT NULL,
        ${_colonnesPostsV4.entries.map((c) => '${c.key} ${c.value},').join(' ')}
        statut TEXT NOT NULL DEFAULT 'ouvert'
          CHECK (statut IN ('ouvert', 'en_cours', 'termine')),
        date_creation TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createCandidatures(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS candidatures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id INTEGER NOT NULL,
        freelancer_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        statut TEXT NOT NULL DEFAULT 'en_attente'
          CHECK (statut IN ('en_attente', 'acceptee', 'refusee')),
        date_candidature TEXT NOT NULL,
        UNIQUE (post_id, freelancer_id),
        FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        FOREIGN KEY (freelancer_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  /// Une conversation = une candidature (le freelancer ↔ le client du post).
  /// Le message de la candidature est le premier message de la discussion.
  Future<void> _createMessages(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        candidature_id INTEGER NOT NULL,
        expediteur_id INTEGER NOT NULL,
        contenu TEXT NOT NULL CHECK (length(trim(contenu)) BETWEEN 1 AND 1000),
        date_envoi TEXT NOT NULL,
        lu INTEGER NOT NULL DEFAULT 0 CHECK (lu IN (0, 1)),
        FOREIGN KEY (candidature_id) REFERENCES candidatures(id) ON DELETE CASCADE,
        FOREIGN KEY (expediteur_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_candidature '
      'ON messages (candidature_id, id)',
    );
  }

  Future<bool> _colonneExiste(Database db, String table, String col) async {
    final infos = await db.rawQuery('PRAGMA table_info($table)');
    return infos.any((c) => c['name'] == col);
  }

  /// Portfolio des freelancers (projets, expériences, sites réalisés…)
  Future<void> _createRealisations(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS realisations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        freelancer_id INTEGER NOT NULL,
        titre TEXT NOT NULL,
        description TEXT NOT NULL,
        categorie TEXT NOT NULL DEFAULT 'autre',
        client TEXT,
        lien TEXT,
        image_path TEXT,
        date_creation TEXT NOT NULL,
        FOREIGN KEY (freelancer_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_realisations_freelancer '
      'ON realisations (freelancer_id, id)',
    );
  }

  /// Emails à envoyer (« boîte d'envoi ») : un email reste ici tant qu'il
  /// n'est pas parti (pas de réseau…) et il est renvoyé plus tard.
  Future<void> _createEmailsSortants(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS emails_sortants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destinataire TEXT NOT NULL,
        sujet TEXT NOT NULL,
        texte TEXT NOT NULL,
        html TEXT NOT NULL,
        tentatives INTEGER NOT NULL DEFAULT 0,
        derniere_erreur TEXT,
        date_creation TEXT NOT NULL
      )
    ''');
  }

  /// Codes à 6 chiffres envoyés par email pour réinitialiser un mot de
  /// passe. Le code n'est jamais stocké en clair (seulement son hash).
  /// Formulaire rempli après 3 échecs. UNIQUE : une seule demande par
  /// freelancer ; chaque ligne donne droit à une tentative de plus.
  Future<void> _createDemandesTentative(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS demandes_tentative (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        freelancer_id INTEGER NOT NULL UNIQUE,
        motif TEXT NOT NULL,
        precision_motif TEXT,
        explication TEXT NOT NULL,
        revisions TEXT NOT NULL,
        heures INTEGER NOT NULL CHECK (heures BETWEEN 1 AND 200),
        date_demande TEXT NOT NULL,
        statut TEXT NOT NULL DEFAULT 'en_cours',
        FOREIGN KEY (freelancer_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  /// Inscription en attente : le code envoyé à une adresse (une ligne par
  /// adresse). Le compte n'est créé dans `users` qu'une fois le code validé.
  Future<void> _createVerificationsEmail(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS verifications_email (
        email TEXT PRIMARY KEY,
        code_hash TEXT NOT NULL,
        expire_le TEXT NOT NULL,
        tentatives INTEGER NOT NULL DEFAULT 0,
        date_creation TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createCodesReinitialisation(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS codes_reinitialisation (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        code_hash TEXT NOT NULL,
        expire_le TEXT NOT NULL,
        tentatives INTEGER NOT NULL DEFAULT 0,
        utilise INTEGER NOT NULL DEFAULT 0 CHECK (utilise IN (0, 1)),
        date_creation TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  /// Un freelancer suit un client ; il reçoit une notification dans l'app
  /// à chaque nouveau post de ce client.
  Future<void> _createAbonnementsEtNotifications(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS abonnements (
        freelancer_id INTEGER NOT NULL,
        client_id INTEGER NOT NULL,
        date_abonnement TEXT NOT NULL,
        PRIMARY KEY (freelancer_id, client_id),
        CHECK (freelancer_id <> client_id),
        FOREIGN KEY (freelancer_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (client_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_abonnements_client '
      'ON abonnements (client_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        titre TEXT NOT NULL,
        contenu TEXT NOT NULL,
        post_id INTEGER,
        acteur_id INTEGER,
        lu INTEGER NOT NULL DEFAULT 0 CHECK (lu IN (0, 1)),
        date_creation TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        FOREIGN KEY (acteur_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_user '
      'ON notifications (user_id, lu, id)',
    );
  }

  /// Tests de compétences des freelancers :
  /// - `test` : la banque de questions (QCM à 4 choix) par domaine ;
  /// - `tentatives_test` : chaque test passé, avec son score ;
  /// - `reponses_test` : les réponses données (correction, et pour ne pas
  ///   reposer les mêmes questions au test suivant) ;
  /// - `certifications` : délivrées quand le score est d'au moins 50 %.
  Future<void> _createTestsEtCertifications(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS test (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domaine TEXT NOT NULL,
        question TEXT NOT NULL UNIQUE,
        choix_a TEXT NOT NULL,
        choix_b TEXT NOT NULL,
        choix_c TEXT NOT NULL,
        choix_d TEXT NOT NULL,
        bonne_reponse INTEGER NOT NULL CHECK (bonne_reponse BETWEEN 0 AND 3),
        duree INTEGER NOT NULL DEFAULT 30 CHECK (duree BETWEEN 10 AND 120)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_test_domaine ON test (domaine)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tentatives_test (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        freelancer_id INTEGER NOT NULL,
        domaines TEXT NOT NULL,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        pourcentage INTEGER NOT NULL CHECK (pourcentage BETWEEN 0 AND 100),
        reussi INTEGER NOT NULL CHECK (reussi IN (0, 1)),
        date_tentative TEXT NOT NULL,
        statut TEXT NOT NULL DEFAULT 'terminee'
          CHECK (statut IN ('en_cours', 'terminee')),
        FOREIGN KEY (freelancer_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reponses_test (
        tentative_id INTEGER NOT NULL,
        question_id INTEGER NOT NULL,
        choix INTEGER CHECK (choix IS NULL OR choix BETWEEN 0 AND 3),
        correcte INTEGER NOT NULL CHECK (correcte IN (0, 1)),
        PRIMARY KEY (tentative_id, question_id),
        FOREIGN KEY (tentative_id) REFERENCES tentatives_test(id)
          ON DELETE CASCADE,
        FOREIGN KEY (question_id) REFERENCES test(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS certifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        freelancer_id INTEGER NOT NULL,
        tentative_id INTEGER NOT NULL UNIQUE,
        numero TEXT NOT NULL UNIQUE,
        nom_freelancer TEXT NOT NULL,
        metier TEXT,
        domaines TEXT NOT NULL,
        competences TEXT NOT NULL,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        pourcentage INTEGER NOT NULL,
        mention TEXT NOT NULL,
        date_obtention TEXT NOT NULL,
        FOREIGN KEY (freelancer_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (tentative_id) REFERENCES tentatives_test(id)
          ON DELETE CASCADE
      )
    ''');
    await _createRapportsTest(db);
    await semerQuestions(db);
  }

  /// Rapport de l'IA sur un test (points forts, points faibles, conseils).
  /// Les listes sont stockées en JSON.
  Future<void> _createRapportsTest(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rapports_test (
        tentative_id INTEGER PRIMARY KEY,
        synthese TEXT NOT NULL,
        points_forts TEXT NOT NULL,
        points_faibles TEXT NOT NULL,
        conseils TEXT NOT NULL,
        modele TEXT,
        date_creation TEXT NOT NULL,
        FOREIGN KEY (tentative_id) REFERENCES tentatives_test(id)
          ON DELETE CASCADE
      )
    ''');
  }

  /// Projets de suivi créés lorsqu'une candidature est acceptée.
  Future<void> _createProjetsEtTaches(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        candidature_id INTEGER NOT NULL UNIQUE,
        post_id INTEGER NOT NULL,
        client_id INTEGER NOT NULL,
        freelancer_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        deadline TEXT,
        status TEXT NOT NULL DEFAULT 'en_cours'
          CHECK (status IN ('en_cours', 'en_pause', 'termine', 'annule')),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (candidature_id) REFERENCES candidatures(id)
          ON DELETE CASCADE,
        FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        FOREIGN KEY (client_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (freelancer_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_projects_client '
      'ON projects (client_id, status, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_projects_freelancer '
      'ON projects (freelancer_id, status, id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_rewards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL UNIQUE,
        client_id INTEGER NOT NULL,
        freelancer_id INTEGER NOT NULL,
        coins INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (client_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (freelancer_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        priority TEXT NOT NULL DEFAULT 'normale'
          CHECK (priority IN ('basse', 'normale', 'haute', 'urgente')),
        status TEXT NOT NULL DEFAULT 'a_faire'
          CHECK (status IN ('a_faire', 'en_cours', 'a_valider', 'validee', 'refusee')),
        due_date TEXT,
        drive_url TEXT,
        github_url TEXT,
        attachment_name TEXT,
        attachment_mime TEXT,
        attachment_bytes BLOB,
        work_description TEXT,
        work_link TEXT,
        work_attachment_name TEXT,
        work_attachment_mime TEXT,
        work_attachment_bytes BLOB,
        rejection_reason TEXT,
        review_note TEXT,
        reviewed_at TEXT,
        created_by INTEGER NOT NULL,
        assigned_to INTEGER NOT NULL,
        validated_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_project_tasks_project '
      'ON project_tasks (project_id, status, priority, id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        task_id INTEGER,
        author_id INTEGER NOT NULL,
        content TEXT NOT NULL CHECK (length(trim(content)) BETWEEN 1 AND 2000),
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (task_id) REFERENCES project_tasks(id) ON DELETE CASCADE,
        FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_project_comments_project '
      'ON project_comments (project_id, id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_activity (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        task_id INTEGER,
        actor_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        details TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (task_id) REFERENCES project_tasks(id) ON DELETE CASCADE,
        FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_project_activity_project '
      'ON project_activity (project_id, id)',
    );
  }

  /// Migration v11 (sans perdre les tests déjà passés)
  Future<void> _migrerV11(Database db) async {
    if (!await _colonneExiste(db, 'users', 'domaines')) {
      await db.execute('ALTER TABLE users ADD COLUMN domaines TEXT');
    }
    if (!await _colonneExiste(db, 'test', 'duree')) {
      await db.execute(
        'ALTER TABLE test ADD COLUMN duree INTEGER NOT NULL DEFAULT 30',
      );
    }
    // reponses_test : « choix » peut être vide (temps écoulé). SQLite ne
    // modifie pas une contrainte : on recrée la table et on recopie.
    await db.execute('''
      CREATE TABLE reponses_test_v11 (
        tentative_id INTEGER NOT NULL,
        question_id INTEGER NOT NULL,
        choix INTEGER CHECK (choix IS NULL OR choix BETWEEN 0 AND 3),
        correcte INTEGER NOT NULL CHECK (correcte IN (0, 1)),
        PRIMARY KEY (tentative_id, question_id),
        FOREIGN KEY (tentative_id) REFERENCES tentatives_test(id)
          ON DELETE CASCADE,
        FOREIGN KEY (question_id) REFERENCES test(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'INSERT INTO reponses_test_v11 SELECT * FROM reponses_test',
    );
    await db.execute('DROP TABLE reponses_test');
    await db.execute('ALTER TABLE reponses_test_v11 RENAME TO reponses_test');
    // les domaines déjà testés deviennent les domaines du profil
    await db.execute('''
      UPDATE users SET domaines = (
        SELECT t.domaines FROM tentatives_test t
        WHERE t.freelancer_id = users.id ORDER BY t.id LIMIT 1)
      WHERE domaines IS NULL AND role = 'freelancer'
    ''');
    await semerQuestions(db); // calcule la durée de chaque question
  }

  /// Durée d'une question en secondes : plus le texte est long, plus on a
  /// de temps pour le lire (entre 20 et 60 s, par pas de 5 s).
  static int dureeQuestion(String question, List<String> choix) {
    final caracteres = question.length + choix.fold(0, (n, c) => n + c.length);
    final brut = 15 + caracteres ~/ 8;
    return ((brut + 4) ~/ 5 * 5).clamp(20, 60);
  }

  /// Remplit la table `test` avec la banque de questions.
  /// Les questions déjà présentes sont ignorées (on peut en ajouter plus
  /// tard sans doublon). La bonne réponse change de position (A, B, C, D).
  static Future<void> semerQuestions(Database db) async {
    final batch = db.batch();
    for (var i = 0; i < questionsTest.length; i++) {
      final (domaine, question, bonne, fausses) = questionsTest[i];
      final position = i % 4;
      final choix = [...fausses]..insert(position, bonne);
      final duree = dureeQuestion(question, choix);
      batch.rawInsert(
        'INSERT OR IGNORE INTO test (domaine, question, choix_a, choix_b, '
        'choix_c, choix_d, bonne_reponse, duree) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [domaine, question, ...choix, position, duree],
      );
      // question déjà en base : on met sa durée à jour
      batch.rawUpdate('UPDATE test SET duree = ? WHERE question = ?', [
        duree,
        question,
      ]);
    }
    await batch.commit(noResult: true);
  }
}
