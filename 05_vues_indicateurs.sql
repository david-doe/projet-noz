
-- PROJET NOZ - ETAPE 3 : LES VUES D'INDICATEURS (PostgreSQL)

-- Une VUE = une requete enregistree dans la base, avec un nom.
-- On l'utilise ensuite comme une table : SELECT * FROM v_ca_jour_semaine;
-- Elle ne stocke AUCUNE donnee : a chaque appel, PostgreSQL relance la
-- requete sur les tables. Si les donnees changent, la vue suit toute seule.
--
-- Pourquoi des vues ?
--   1. On ecrit un calcul complique UNE fois, puis on le reutilise
--      partout (Python, Power BI, rapport) avec la MEME definition.
--   2. Power BI et Python liront ces vues : pas besoin de refaire les
--      calculs dans chaque outil.
--   3. Une definition unique = pas de "deux chiffres differents pour
--      le meme indicateur" selon qui a fait le calcul.
--
-- Les 5 vues :
--   V1 v_ca_jour_semaine      -> CA moyen par jour de la semaine   (H1)
--   V2 v_vie_lot              -> le parcours de chaque lot (1 ligne / lot)
--   V3 v_rotation_categorie   -> vitesse de vente par rayon
--   V4 v_demarque_categorie   -> demarque inconnue par rayon       (H2, H3)
--   V5 v_saturation_rvn       -> saturation a l'arrivee et RVN     (H4)
--
-- Ce fichier ne contient PAS de commande psql (\...) : il marche dans
-- le terminal ET dans DBeaver (Alt+X).
--   Terminal : & $psql -U postgres -d noz -f 05_vues_indicateurs.sql


-- On supprime les anciennes versions (pour pouvoir relancer le fichier).
-- Ordre inverse des dependances : V3 et V5 utilisent V2.
DROP VIEW IF EXISTS v_saturation_rvn;
DROP VIEW IF EXISTS v_rotation_categorie;
DROP VIEW IF EXISTS v_demarque_categorie;
DROP VIEW IF EXISTS v_vie_lot;
DROP VIEW IF EXISTS v_ca_jour_semaine;


-- ---------------------------------------------------------------------
-- V1. v_ca_jour_semaine : quel jour de la semaine vend le plus ?
--     1 ligne = 1 jour de la semaine (7 lignes).
--     "indice" = CA du jour / CA moyen de tous les jours.
--     Indice 1,40 = ce jour vend 40 % de plus qu'un jour moyen.
--     Sert a tester H1 (pic le samedi, comme dans l'annexe du memoire).
-- ---------------------------------------------------------------------
CREATE VIEW v_ca_jour_semaine AS
SELECT EXTRACT(ISODOW FROM date_jour)::int AS num_jour,    -- 1 = lundi (pour trier)
       jour_semaine,
       COUNT(*)                            AS nb_jours,
       ROUND(AVG(ca_total_eur), 2)         AS ca_moyen_eur,
       ROUND(AVG(ca_total_eur)
             / (SELECT AVG(ca_total_eur) FROM magasin_jour), 2) AS indice,
       ROUND(AVG(nb_lots_recus), 1)        AS lots_recus_moyen
FROM magasin_jour
GROUP BY num_jour, jour_semaine;


-- ---------------------------------------------------------------------
-- V2. v_vie_lot : la "biographie" de chaque lot
--     1 ligne = 1 lot (3 060 lignes).
--     Rassemble l'arrivee (arrivages), les ventes (ventes_lot_jour) et
--     la fin (sorties_lots).
--     Deux KPI du magasin (memoire de stage) :
--       - taux de vente S1 = part du lot vendue la 1re semaine (jours 1-7)
--       - taux de vente fin de vie = part du lot vendue au total
--     "analysable" = FAUX pour les lots herites (arrives avant 2024) et
--     les lots EN_COURS : leur vie n'est pas complete dans nos donnees.
--
--     c'est une vue de BILAN. Elle melange le debut et la
--     fin de la vie du lot. 
-- ---------------------------------------------------------------------
CREATE VIEW v_vie_lot AS
SELECT a.arrivage_id,
       a.date_arrivee,
       a.categorie,
       a.type_marque,
       a.quantite_initiale,
       a.prix_unitaire_initial,
       a.taux_saturation_arrivee,
       v.unites_vendues,
       v.unites_vendues_s1,
       ROUND(100.0 * v.unites_vendues_s1 / a.quantite_initiale, 1) AS taux_vente_s1_pct,
       ROUND(100.0 * v.unites_vendues    / a.quantite_initiale, 1) AS taux_vente_fin_pct,
       v.casse_declaree,
       v.ca_eur,
       v.jours_en_rayon,
       s.motif_sortie,
       s.quantite_rvn,
       (a.arrive_dans_fenetre AND s.motif_sortie <> 'EN_COURS') AS analysable
FROM arrivages a
JOIN (SELECT arrivage_id,
             SUM(quantite_vendue)                                  AS unites_vendues,
             -- FILTER = "ne compte que les lignes qui respectent la condition"
             SUM(quantite_vendue) FILTER (WHERE jour_de_vie <= 7)  AS unites_vendues_s1,
             SUM(casse_declaree)                                   AS casse_declaree,
             SUM(chiffre_affaires_eur)                             AS ca_eur,
             COUNT(*)                                              AS jours_en_rayon
      FROM ventes_lot_jour
      GROUP BY arrivage_id) v ON v.arrivage_id = a.arrivage_id
JOIN sorties_lots s ON s.arrivage_id = a.arrivage_id;


-- ---------------------------------------------------------------------
-- V3. v_rotation_categorie : quels rayons vendent vite, lesquels coincent ?
--     1 ligne = 1 categorie (9 lignes). Seulement les lots "analysables".
--     Se construit SUR la vue V2 : une vue peut en utiliser une autre.
-- ---------------------------------------------------------------------
CREATE VIEW v_rotation_categorie AS
SELECT categorie,
       COUNT(*)                                     AS nb_lots,
       ROUND(AVG(taux_vente_s1_pct), 1)             AS taux_vente_s1_moyen_pct,
       ROUND(AVG(taux_vente_fin_pct), 1)            AS taux_vente_fin_moyen_pct,
       ROUND(AVG(jours_en_rayon), 1)                AS jours_en_rayon_moyen,
       ROUND(100.0 * AVG((motif_sortie = 'ECOULE')::int), 1)        AS pct_ecoules,
       ROUND(100.0 * AVG((motif_sortie = 'RVN_PREMATURE')::int), 1) AS pct_rvn_premature,
       ROUND(100.0 * SUM(ca_eur) / SUM(SUM(ca_eur)) OVER (), 1)     AS part_ca_pct
FROM v_vie_lot
WHERE analysable
GROUP BY categorie;

-- ---------------------------------------------------------------------
-- V4. v_demarque_categorie : ou disparait la marchandise ?
--     1 ligne = 1 categorie (9 lignes).
--     Source : les inventaires (le SEUL endroit ou on voit les pertes
--     inconnues dans la vraie vie). On n'utilise PAS la verite terrain.
--     taux = valeur perdue / CA de la periode x 100.
--     Sert a tester H2 (D.P.H. plus vole) et H3 (boutique moins volee).
-- ---------------------------------------------------------------------
CREATE VIEW v_demarque_categorie AS
SELECT categorie,
       COUNT(*)                                  AS nb_inventaires,
       -SUM(ecart_unites)                        AS unites_perdues,
       -SUM(valeur_ecart_eur)                    AS valeur_perdue_eur,
       SUM(ca_periode_eur)                       AS ca_eur,
       ROUND(-100.0 * SUM(valeur_ecart_eur) / SUM(ca_periode_eur), 2) AS taux_demarque_pct
FROM inventaires
GROUP BY categorie;


-- ---------------------------------------------------------------------
-- V5. v_saturation_rvn : un magasin plein renvoie-t-il plus de lots ?
--     1 ligne = 1 tranche de saturation a l'arrivee du lot.
--     Sert a tester H4. On range les lots par "tranche" (comme des
--     tiroirs) avec CASE, puis on calcule le % de RVN premature.
-- ---------------------------------------------------------------------
CREATE VIEW v_saturation_rvn AS
SELECT CASE
           WHEN taux_saturation_arrivee <  0.90 THEN '1. moins de 0,90'
           WHEN taux_saturation_arrivee <  1.00 THEN '2. 0,90 a 0,99'
           WHEN taux_saturation_arrivee <  1.10 THEN '3. 1,00 a 1,09'
           ELSE                                      '4. 1,10 et plus'
       END                                                          AS tranche_saturation,
       COUNT(*)                                                     AS nb_lots,
       SUM((motif_sortie = 'RVN_PREMATURE')::int)                   AS nb_rvn_premature,
       ROUND(100.0 * AVG((motif_sortie = 'RVN_PREMATURE')::int), 1) AS pct_rvn_premature,
       ROUND(AVG(taux_vente_fin_pct), 1)                            AS taux_vente_fin_moyen_pct
FROM v_vie_lot
WHERE analysable
GROUP BY tranche_saturation;



SELECT * FROM v_ca_jour_semaine     ORDER BY num_jour;
SELECT * FROM v_rotation_categorie  ORDER BY taux_vente_s1_moyen_pct DESC;
SELECT * FROM v_demarque_categorie  ORDER BY taux_demarque_pct DESC;
SELECT * FROM v_saturation_rvn      ORDER BY tranche_saturation;
SELECT * FROM v_vie_lot             ORDER BY date_arrivee LIMIT 20;
