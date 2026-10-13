
-- PROJET NOZ - ETAPE 1 : CHARGER LES CSV DANS POSTGRESQL

-- A lancer avec psql, DEPUIS LE DOSSIER DU PROJET (celui qui contient
-- le dossier noz_v2), par exemple :
--     psql -U postgres -d noz -f 02_charger_donnees.sql
--
-- \copy = "copie ce fichier CSV dans cette table".
--   - FORMAT csv : le fichier est un CSV (virgules)
--   - HEADER     : la 1re ligne contient les noms des colonnes, on la saute
--   - Une case vide devient NULL ("pas de valeur").
-- \copy (avec la barre \) lit le fichier sur ordinateur. C'est la
-- version "client" de la commande COPY de PostgreSQL.
--
-- L'ORDRE COMPTE : on charge d'abord les tables dont les autres dependent.
-- (On ne peut pas ranger une vente pour un lot qui n'existe pas encore :
-- PostgreSQL refuserait, grace aux cles etrangeres.)

-- Les fichiers sont en UTF-8 . On le dit a psql,
-- sinon Windows peut mal lire les accents.
\encoding UTF8

-- Arreter tout a la premiere erreur (plutot que continuer a moitie).
\set ON_ERROR_STOP on

-- On vide les tables avant de charger (pour pouvoir relancer le script).
-- La table categories est remplie par 01_schema.sql.
TRUNCATE verite_terrain_lot_jour, ventes_lot_jour, sorties_lots,
         inventaires, arrivages, magasin_jour;

\echo 'Chargement de magasin_jour...'
\copy magasin_jour FROM 'noz_v2/magasin_jour.csv' WITH (FORMAT csv, HEADER true)

\echo 'Chargement de arrivages...'
\copy arrivages FROM 'noz_v2/arrivages.csv' WITH (FORMAT csv, HEADER true)

\echo 'Chargement de ventes_lot_jour (95 332 lignes)...'
\copy ventes_lot_jour FROM 'noz_v2/ventes_lot_jour.csv' WITH (FORMAT csv, HEADER true)

\echo 'Chargement de sorties_lots...'
\copy sorties_lots FROM 'noz_v2/sorties_lots.csv' WITH (FORMAT csv, HEADER true)

\echo 'Chargement de inventaires...'
\copy inventaires FROM 'noz_v2/inventaires.csv' WITH (FORMAT csv, HEADER true)

\echo 'Chargement de verite_terrain_lot_jour (95 332 lignes)...'
\copy verite_terrain_lot_jour FROM 'noz_v2/verite_terrain_lot_jour.csv' WITH (FORMAT csv, HEADER true)

-- ANALYZE : PostgreSQL "etudie" les tables pour choisir ensuite la facon
-- la plus rapide de repondre aux requetes.
ANALYZE;

-- Controle final : nombre de lignes par table.

\echo 'Controle du nombre de lignes :'
SELECT 'categories' AS table_nom, COUNT(*) AS nb_lignes FROM categories
UNION ALL SELECT 'magasin_jour',            COUNT(*) FROM magasin_jour
UNION ALL SELECT 'arrivages',               COUNT(*) FROM arrivages
UNION ALL SELECT 'ventes_lot_jour',         COUNT(*) FROM ventes_lot_jour
UNION ALL SELECT 'sorties_lots',            COUNT(*) FROM sorties_lots
UNION ALL SELECT 'inventaires',             COUNT(*) FROM inventaires
UNION ALL SELECT 'verite_terrain_lot_jour', COUNT(*) FROM verite_terrain_lot_jour;

\echo 'Termine. Si aucune erreur ne s''est affichee, tous les liens entre tables sont valides.'
