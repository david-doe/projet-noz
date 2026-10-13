
-- PROJET NOZ - ETAPE 1 : CREATION DES TABLES (PostgreSQL)
-- 
-- Ce fichier ne contient AUCUNE donnee. Il decrit la forme de la base :
-- quelles tables, quelles colonnes, quelles regles.
--
-- Vocabulaire :
--   TABLE         = un tableau (comme une feuille Excel)
--   COLONNE       = une information (ex : prix_unitaire_initial)
--   LIGNE         = un enregistrement (ex : un lot de marchandises)
--   PRIMARY KEY   = la "carte d'identite" d'une ligne : unique, jamais vide
--   FOREIGN KEY   = un lien vers une autre table (on ne peut pas citer
--                   un lot qui n'existe pas)
--   CHECK         = une regle de bon sens (ex : une quantite >= 0)
--   INDEX         = un "sommaire" qui rend les recherches plus rapides
--
-- Les TYPES utilises (le "format" de chaque colonne) :
--   DATE           = une vraie date (PostgreSQL sait calculer avec :
--                    "date + 7", "date_a - date_b" = nombre de jours)
--   INTEGER        = un nombre entier (3, 120, -5)
--   NUMERIC(10,2)  = un nombre EXACT avec 2 chiffres apres la virgule.
--                    On l'utilise pour l'argent : pas d'erreur d'arrondi.
--   NUMERIC(4,2)   = petit nombre exact a 2 decimales (ex : 1.05)
--   TEXT           = du texte
--   BOOLEAN        = vrai / faux
--
-- =====================================================================

-- Ce fichier est ecrit en UTF-8 (l'accent de "Bien-être").
-- Sous Windows, psql lit par defaut les fichiers en WIN1252 : il
-- enregistrerait alors "Bien-Ãªtre" au lieu de "Bien-être".
-- Cette ligne dit a psql : "lis ce fichier en UTF-8".
\encoding UTF8

-- On repart de zero : si les tables existent deja, on les supprime.

DROP TABLE IF EXISTS verite_terrain_lot_jour CASCADE;
DROP TABLE IF EXISTS ventes_lot_jour         CASCADE;
DROP TABLE IF EXISTS sorties_lots            CASCADE;
DROP TABLE IF EXISTS inventaires             CASCADE;
DROP TABLE IF EXISTS arrivages               CASCADE;
DROP TABLE IF EXISTS magasin_jour            CASCADE;
DROP TABLE IF EXISTS categories              CASCADE;


-- ---------------------------------------------------------------------
-- 0. categories : la liste des 9 rayons (table de reference)
--    1 ligne = 1 categorie.
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    categorie TEXT PRIMARY KEY
);

INSERT INTO categories (categorie) VALUES
    ('1. Epicerie'), ('2. Boissons'), ('4. D.P.H.'), ('5. Maison'),
    ('6. Bien-être'), ('7. Textile'), ('SURGELES'), ('TDM'),
    ('BOUTIQUE MANON MERCIER');


-- ---------------------------------------------------------------------
-- 1. magasin_jour : la "meteo" du magasin, un jour par ligne (599 lignes)

CREATE TABLE magasin_jour (
    date_jour              DATE          PRIMARY KEY,
    jour_semaine           TEXT          NOT NULL
        CHECK (jour_semaine IN ('Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche')),
    semaine_iso            INTEGER       NOT NULL CHECK (semaine_iso BETWEEN 1 AND 53),
    evenement              TEXT          NOT NULL,     -- Aucun, Noel, Soldes, Paques, Rentree
    effectif               INTEGER       NOT NULL CHECK (effectif BETWEEN 0 AND 20),
    nb_lots_recus          INTEGER       NOT NULL CHECK (nb_lots_recus >= 0),
    nb_palettes_recues     INTEGER       NOT NULL CHECK (nb_palettes_recues >= 0),
    nb_lots_actifs         INTEGER       NOT NULL CHECK (nb_lots_actifs >= 0),
    stock_theorique_unites INTEGER       NOT NULL CHECK (stock_theorique_unites >= 0),
    taux_saturation        NUMERIC(4,2)  NOT NULL CHECK (taux_saturation > 0),  -- 1.00 = magasin plein
    ca_total_eur           NUMERIC(10,2) NOT NULL CHECK (ca_total_eur >= 0)
);


-- ---------------------------------------------------------------------
-- 2. arrivages : la fiche d'identite de chaque lot, CONNUE A L'ARRIVEE
--    1 ligne = 1 lot livre (3 060 lignes).
--    Aucune information sur le futur du lot ici : c'est voulu, pour
--    eviter la "fuite de donnees".
--    Pas de lien vers magasin_jour : 147 lots sont arrives AVANT le
--    1er janvier 2024 (deja en rayon), or magasin_jour commence a cette date.
-- ---------------------------------------------------------------------
CREATE TABLE arrivages (
    arrivage_id              TEXT          PRIMARY KEY,   -- ex : L00001
    date_arrivee             DATE          NOT NULL,
    categorie                TEXT          NOT NULL REFERENCES categories(categorie),
    type_marque              TEXT          NOT NULL
        CHECK (type_marque IN ('Grande Marque','Marque Distributeur','Sans Marque')),
    indice_fragilite         TEXT          NOT NULL
        CHECK (indice_fragilite IN ('Basse','Moyenne','Haute')),
    nb_palettes              INTEGER       NOT NULL CHECK (nb_palettes BETWEEN 1 AND 5),
    quantite_initiale        INTEGER       NOT NULL CHECK (quantite_initiale > 0),
    prix_unitaire_initial    NUMERIC(10,2) NOT NULL CHECK (prix_unitaire_initial > 0),
    taux_saturation_arrivee  NUMERIC(4,2)  NOT NULL CHECK (taux_saturation_arrivee > 0),
    arrive_dans_fenetre      BOOLEAN       NOT NULL   -- FALSE = deja la avant 2024
);


-- ---------------------------------------------------------------------
-- 3. ventes_lot_jour : ce qui se passe chaque jour pour chaque lot
--    1 ligne = 1 lot un jour donne (95 332 lignes).
--    Carte d'identite a DEUX colonnes (date + lot) : un lot ne peut
--    avoir qu'une seule ligne par jour.
-- ---------------------------------------------------------------------
CREATE TABLE ventes_lot_jour (
    date_jour                   DATE          NOT NULL REFERENCES magasin_jour(date_jour),
    arrivage_id                 TEXT          NOT NULL REFERENCES arrivages(arrivage_id),
    jour_de_vie                 INTEGER       NOT NULL CHECK (jour_de_vie BETWEEN 1 AND 49),
    stock_theorique_debut_jour  INTEGER       NOT NULL CHECK (stock_theorique_debut_jour >= 0),
    quantite_vendue             INTEGER       NOT NULL CHECK (quantite_vendue >= 0),
    casse_declaree              INTEGER       NOT NULL CHECK (casse_declaree >= 0),
    taux_demarque_pct           INTEGER       NOT NULL CHECK (taux_demarque_pct IN (0, 30, 50)),
    chiffre_affaires_eur        NUMERIC(10,2) NOT NULL CHECK (chiffre_affaires_eur >= 0),
    PRIMARY KEY (date_jour, arrivage_id)
);


-- ---------------------------------------------------------------------
-- 4. sorties_lots : comment chaque lot a fini sa vie (la CIBLE a predire)
--    1 ligne = 1 lot (3 060 lignes).
--    Regle : un lot EN_COURS n'a pas de date de sortie (et inversement).
-- ---------------------------------------------------------------------
CREATE TABLE sorties_lots (
    arrivage_id         TEXT    PRIMARY KEY REFERENCES arrivages(arrivage_id),
    date_sortie         DATE,                       -- vide (NULL) si encore en rayon
    jour_de_vie_sortie  INTEGER CHECK (jour_de_vie_sortie BETWEEN 1 AND 49),
    motif_sortie        TEXT    NOT NULL
        CHECK (motif_sortie IN ('ECOULE','RVN_NORMAL_S7','RVN_PREMATURE','EN_COURS')),
    quantite_rvn        INTEGER NOT NULL CHECK (quantite_rvn >= 0),
    CHECK ((motif_sortie = 'EN_COURS') = (date_sortie IS NULL))
);


-- ---------------------------------------------------------------------
-- 5. inventaires : les comptages physiques, toutes les 4 semaines
--    1 ligne = 1 categorie a une date d'inventaire (189 lignes).
--    SEUL moment ou le magasin decouvre ce qui a disparu (vols, casse
--    non declaree, erreurs) : la "demarque inconnue".
-- ---------------------------------------------------------------------
CREATE TABLE inventaires (
    date_inventaire             DATE          NOT NULL,
    categorie                   TEXT          NOT NULL REFERENCES categories(categorie),
    ecart_unites                INTEGER       NOT NULL,   -- negatif = il manque des articles
    valeur_ecart_eur            NUMERIC(10,2) NOT NULL,
    ca_periode_eur              NUMERIC(10,2) NOT NULL CHECK (ca_periode_eur >= 0),
    taux_demarque_inconnue_pct  NUMERIC(6,2)  NOT NULL,
    PRIMARY KEY (date_inventaire, categorie)
);


-- ---------------------------------------------------------------------
-- 6. verite_terrain_lot_jour : la "verite cachee" du simulateur
--    1 ligne = 1 lot un jour donne (95 332 lignes).
--    SERT UNIQUEMENT A VERIFIER nos methodes. JAMAIS une variable de modele.
-- ---------------------------------------------------------------------
CREATE TABLE verite_terrain_lot_jour (
    date_jour                  DATE    NOT NULL,
    arrivage_id                TEXT    NOT NULL,
    stock_physique_debut_jour  INTEGER NOT NULL CHECK (stock_physique_debut_jour >= 0),
    casse_reelle               INTEGER NOT NULL CHECK (casse_reelle >= 0),
    casse_non_declaree         INTEGER NOT NULL CHECK (casse_non_declaree >= 0),
    vol_reel                   INTEGER NOT NULL CHECK (vol_reel >= 0),
    PRIMARY KEY (date_jour, arrivage_id),
    FOREIGN KEY (date_jour, arrivage_id) REFERENCES ventes_lot_jour(date_jour, arrivage_id),
    CHECK (casse_non_declaree <= casse_reelle)
);


-- ---------------------------------------------------------------------
-- INDEX : des "sommaires" pour retrouver vite les lignes d'un lot,
-- d'une categorie ou d'une date. (Les cles primaires en ont deja un.)
-- ---------------------------------------------------------------------
CREATE INDEX idx_ventes_lot            ON ventes_lot_jour (arrivage_id);
CREATE INDEX idx_arrivages_date        ON arrivages (date_arrivee);
CREATE INDEX idx_arrivages_categorie   ON arrivages (categorie);
CREATE INDEX idx_inventaires_categorie ON inventaires (categorie);
CREATE INDEX idx_verite_lot            ON verite_terrain_lot_jour (arrivage_id);
