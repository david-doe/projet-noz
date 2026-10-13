

-- PROJET NOZ - ETAPE 2 : CONTROLES DE QUALITE DES DONNEES (PostgreSQL)

-- But : PROUVER que les donnees sont fiables AVANT de les analyser.
-- Si les donnees sont fausses, toutes les analyses qui suivent seront
-- fausses aussi .
--
-- Les cles et les CHECK de l'etape 1 bloquent deja les erreurs
-- SIMPLES, sur UNE ligne (une quantite negative, un lot inconnu).
-- Ici on cherche les erreurs que la base ne peut pas voir seule :
-- celles qui concernent PLUSIEURS lignes ou PLUSIEURS tables
-- (ex : "le CA du jour = la somme des CA des lots ce jour-la").
--
-- Methode : chaque controle COMPTE les lignes qui posent probleme.
--   0 probleme  -> statut OK
--   plus de 0   -> statut A VERIFIER (on regarde les lignes en cause)
--
-- VERSION POUR DBEAVER (sans les commandes psql qui commencent par \).




-- PARTIE A : LE RAPPORT DES 22 CONTROLES

-- Une seule grande requete. Chaque bloc "SELECT ..." est un controle,
-- et "UNION ALL" colle les resultats les uns sous les autres pour
-- former un seul tableau.


-- === PARTIE A : rapport des controles (attendu : 22 lignes OK) ===

WITH resultats (famille, num, controle, nb_problemes) AS (

 
    -- FAMILLE 1 : COMPLETUDE = rien ne manque


    -- C01. Le calendrier n'a pas de trou.
    -- generate_series fabrique la liste de TOUS les jours entre le
    -- premier et le dernier. On compte ceux qui n'existent pas dans
    -- magasin_jour.
    SELECT '1. Completude', 'C01', 'Aucun jour manquant dans le calendrier',
           COUNT(*)
    FROM generate_series(DATE '2024-01-01', DATE '2025-08-21', INTERVAL '1 day') AS g(jour)
    WHERE g.jour::date NOT IN (SELECT date_jour FROM magasin_jour)

    -- C02. Chaque lot a sa fiche de sortie (sinon pas de cible a predire).
    -- NOT EXISTS = "il n'existe aucune ligne qui correspond".
    UNION ALL
    SELECT '1. Completude', 'C02', 'Chaque lot a une fiche dans sorties_lots',
           COUNT(*)
    FROM arrivages a
    WHERE NOT EXISTS (SELECT 1 FROM sorties_lots s WHERE s.arrivage_id = a.arrivage_id)

    -- C03. Chaque lot a au moins une ligne de vente.
    UNION ALL
    SELECT '1. Completude', 'C03', 'Chaque lot a au moins une ligne dans ventes_lot_jour',
           COUNT(*)
    FROM arrivages a
    WHERE NOT EXISTS (SELECT 1 FROM ventes_lot_jour v WHERE v.arrivage_id = a.arrivage_id)

    -- C04. A chaque inventaire, les 9 rayons sont comptes.
    -- GROUP BY fait un paquet par date ; HAVING garde les paquets
    -- qui n'ont pas 9 lignes.
    UNION ALL
    SELECT '1. Completude', 'C04', 'Chaque inventaire compte les 9 rayons',
           COUNT(*)
    FROM (SELECT date_inventaire
          FROM inventaires
          GROUP BY date_inventaire
          HAVING COUNT(*) <> 9) AS x

  
    -- FAMILLE 2 : COHERENCE DES CALCULS = les chiffres se recalculent
    

    -- C05. Le nom du jour correspond bien a la date.
    -- ISODOW donne le numero du jour : 1 = lundi ... 7 = dimanche.
    UNION ALL
    SELECT '2. Calculs', 'C05', 'jour_semaine correspond a la date',
           COUNT(*)
    FROM magasin_jour
    WHERE jour_semaine <> (ARRAY['Lundi','Mardi','Mercredi','Jeudi',
                                 'Vendredi','Samedi','Dimanche'])
                          [EXTRACT(ISODOW FROM date_jour)]

    -- C06. Le numero de semaine correspond bien a la date.
    UNION ALL
    SELECT '2. Calculs', 'C06', 'semaine_iso correspond a la date',
           COUNT(*)
    FROM magasin_jour
    WHERE semaine_iso <> EXTRACT(WEEK FROM date_jour)

    -- C07. Le jour de vie = date du jour - date d'arrivee + 1
    -- (le jour d'arrivee est le jour 1).
    UNION ALL
    SELECT '2. Calculs', 'C07', 'jour_de_vie = date - date_arrivee + 1',
           COUNT(*)
    FROM ventes_lot_jour v
    JOIN arrivages a ON a.arrivage_id = v.arrivage_id
    WHERE v.jour_de_vie <> v.date_jour - a.date_arrivee + 1

    -- C08. CA d'une ligne = quantite x prix x (1 - remise).
    -- On tolere 1 centime d'ecart (arrondis).
    UNION ALL
    SELECT '2. Calculs', 'C08', 'CA ligne = quantite x prix x (1 - remise)',
           COUNT(*)
    FROM ventes_lot_jour v
    JOIN arrivages a ON a.arrivage_id = v.arrivage_id
    WHERE ABS(v.chiffre_affaires_eur
              - v.quantite_vendue * a.prix_unitaire_initial
                * (1 - v.taux_demarque_pct / 100.0)) > 0.01

    -- C09. CA du magasin un jour = somme des CA de tous les lots ce jour.
    UNION ALL
    SELECT '2. Calculs', 'C09', 'CA magasin du jour = somme des CA des lots',
           COUNT(*)
    FROM magasin_jour m
    JOIN (SELECT date_jour, SUM(chiffre_affaires_eur) AS ca
          FROM ventes_lot_jour GROUP BY date_jour) v
      ON v.date_jour = m.date_jour
    WHERE ABS(m.ca_total_eur - v.ca) > 0.05

    -- C10. Lots et palettes recus un jour = ce que dit la table arrivages.
    -- LEFT JOIN garde aussi les jours SANS livraison ; COALESCE
    -- remplace alors le "vide" (NULL) par 0.
    UNION ALL
    SELECT '2. Calculs', 'C10', 'Lots et palettes recus = table arrivages',
           COUNT(*)
    FROM magasin_jour m
    LEFT JOIN (SELECT date_arrivee, COUNT(*) AS nb_lots, SUM(nb_palettes) AS nb_pal
               FROM arrivages GROUP BY date_arrivee) a
      ON a.date_arrivee = m.date_jour
    WHERE m.nb_lots_recus      <> COALESCE(a.nb_lots, 0)
       OR m.nb_palettes_recues <> COALESCE(a.nb_pal, 0)

    -- C11. Stock du lendemain = stock du jour - vendu - casse declaree.
    -- LEAD() va chercher la valeur de la ligne SUIVANTE du meme lot
    -- (PARTITION BY = "lot par lot", ORDER BY = "dans l'ordre des dates").
    UNION ALL
    SELECT '2. Calculs', 'C11', 'Stock lendemain = stock - vendu - casse',
           COUNT(*)
    FROM (SELECT stock_theorique_debut_jour - quantite_vendue - casse_declaree AS stock_fin,
                 LEAD(stock_theorique_debut_jour)
                     OVER (PARTITION BY arrivage_id ORDER BY date_jour) AS stock_lendemain
          FROM ventes_lot_jour) x
    WHERE stock_lendemain IS NOT NULL
      AND stock_lendemain <> stock_fin

    -- C12. Au jour 1, le stock = la quantite livree.
    UNION ALL
    SELECT '2. Calculs', 'C12', 'Stock au jour 1 = quantite_initiale',
           COUNT(*)
    FROM ventes_lot_jour v
    JOIN arrivages a ON a.arrivage_id = v.arrivage_id
    WHERE v.jour_de_vie = 1
      AND v.stock_theorique_debut_jour <> a.quantite_initiale

    -- C13. Stock du magasin = somme des stocks des lots EN FIN de journee.
    -- (Attention : c'est le stock du SOIR, pas du matin. Voir partie B.)
    UNION ALL
    SELECT '2. Calculs', 'C13', 'Stock magasin = somme des stocks lots (fin de journee)',
           COUNT(*)
    FROM magasin_jour m
    JOIN (SELECT date_jour,
                 COUNT(*) AS nb_lots,
                 SUM(stock_theorique_debut_jour - quantite_vendue - casse_declaree) AS stock_soir
          FROM ventes_lot_jour GROUP BY date_jour) v
      ON v.date_jour = m.date_jour
    WHERE m.stock_theorique_unites <> v.stock_soir
       OR m.nb_lots_actifs         <> v.nb_lots

    -- C14. Taux de demarque inconnue = - valeur de l'ecart / CA x 100.
    UNION ALL
    SELECT '2. Calculs', 'C14', 'Taux demarque inconnue = -ecart / CA x 100',
           COUNT(*)
    FROM inventaires
    WHERE ABS(taux_demarque_inconnue_pct
              - (-valeur_ecart_eur / ca_periode_eur * 100)) > 0.01


    -- FAMILLE 3 : LOGIQUE METIER = les regles du magasin sont respectees


    -- C15. On ne vend pas (ni ne casse) plus que ce qu'on a.
    UNION ALL
    SELECT '3. Metier', 'C15', 'Vendu + casse <= stock du jour',
           COUNT(*)
    FROM ventes_lot_jour
    WHERE quantite_vendue + casse_declaree > stock_theorique_debut_jour

    -- C16. Une remise ne redescend jamais (0 -> 30 -> 50, jamais l'inverse).
    -- LAG() = la valeur de la ligne PRECEDENTE du meme lot.
    UNION ALL
    SELECT '3. Metier', 'C16', 'La remise ne baisse jamais au cours de la vie',
           COUNT(*)
    FROM (SELECT taux_demarque_pct AS remise,
                 LAG(taux_demarque_pct)
                     OVER (PARTITION BY arrivage_id ORDER BY date_jour) AS remise_veille
          FROM ventes_lot_jour) x
    WHERE remise < remise_veille

    -- C17. Date de sortie = date d'arrivee + jour de vie de sortie - 1.
    UNION ALL
    SELECT '3. Metier', 'C17', 'date_sortie = date_arrivee + jour_de_vie_sortie - 1',
           COUNT(*)
    FROM sorties_lots s
    JOIN arrivages a ON a.arrivage_id = s.arrivage_id
    WHERE s.date_sortie <> a.date_arrivee + s.jour_de_vie_sortie - 1

    -- C18. Le motif colle avec les chiffres :
    --   RVN normal  -> sortie au jour 49 (fin des 7 semaines)
    --   RVN premature -> sortie AVANT le jour 49, avec du stock renvoye
    --   ECOULE ou EN_COURS -> rien de renvoye
    UNION ALL
    SELECT '3. Metier', 'C18', 'Motif de sortie coherent (jour 49, quantite RVN)',
           COUNT(*)
    FROM sorties_lots
    WHERE (motif_sortie = 'RVN_NORMAL_S7' AND jour_de_vie_sortie <> 49)
       OR (motif_sortie = 'RVN_PREMATURE' AND (jour_de_vie_sortie >= 49 OR quantite_rvn = 0))
       OR (motif_sortie IN ('ECOULE', 'EN_COURS') AND quantite_rvn <> 0)

    -- C19. Aucune vente APRES la sortie du lot.
    UNION ALL
    SELECT '3. Metier', 'C19', 'Aucune vente apres la date de sortie',
           COUNT(*)
    FROM ventes_lot_jour v
    JOIN sorties_lots s ON s.arrivage_id = v.arrivage_id
    WHERE v.date_jour > s.date_sortie

    -- C20. La derniere ligne de vente d'un lot sorti = sa date de sortie.
    UNION ALL
    SELECT '3. Metier', 'C20', 'Derniere vente = date de sortie',
           COUNT(*)
    FROM (SELECT arrivage_id, MAX(date_jour) AS derniere_date
          FROM ventes_lot_jour GROUP BY arrivage_id) v
    JOIN sorties_lots s ON s.arrivage_id = v.arrivage_id
    WHERE s.date_sortie IS NOT NULL
      AND v.derniere_date <> s.date_sortie

   
    -- FAMILLE 4 : VERITE TERRAIN = la table cachee colle avec le reste
    -- (sert seulement a verifier le simulateur, jamais dans un modele)
   
    -- C21. Casse declaree = casse reelle - casse non declaree.
    UNION ALL
    SELECT '4. Verite terrain', 'C21', 'Casse declaree = casse reelle - non declaree',
           COUNT(*)
    FROM verite_terrain_lot_jour t
    JOIN ventes_lot_jour v ON v.date_jour = t.date_jour AND v.arrivage_id = t.arrivage_id
    WHERE t.casse_reelle - t.casse_non_declaree <> v.casse_declaree

    -- C22. Le stock reel n'est jamais plus grand que le stock theorique
    -- (les vols et la casse cachee ne font que l'enlever).
    UNION ALL
    SELECT '4. Verite terrain', 'C22', 'Stock physique <= stock theorique',
           COUNT(*)
    FROM verite_terrain_lot_jour t
    JOIN ventes_lot_jour v ON v.date_jour = t.date_jour AND v.arrivage_id = t.arrivage_id
    WHERE t.stock_physique_debut_jour > v.stock_theorique_debut_jour
)
SELECT famille, num, controle, nb_problemes,
       CASE WHEN nb_problemes = 0 THEN 'OK' ELSE 'A VERIFIER' END AS statut
FROM resultats
ORDER BY num;



-- PARTIE B : LE PROFIL DES DONNEES

--  B1. Valeurs mini / maxi des colonnes cles (reperer les valeurs abbérantes)
SELECT 'prix_unitaire_initial (EUR)' AS colonne,
       MIN(prix_unitaire_initial)::text AS mini, ROUND(AVG(prix_unitaire_initial), 2)::text AS moyenne,
       MAX(prix_unitaire_initial)::text AS maxi FROM arrivages
UNION ALL
SELECT 'quantite_initiale (unites)', MIN(quantite_initiale)::text, ROUND(AVG(quantite_initiale))::text,
       MAX(quantite_initiale)::text FROM arrivages
UNION ALL
SELECT 'taux_saturation (1 = plein)', MIN(taux_saturation)::text, ROUND(AVG(taux_saturation), 2)::text,
       MAX(taux_saturation)::text FROM magasin_jour
UNION ALL
SELECT 'effectif (personnes)', MIN(effectif)::text, ROUND(AVG(effectif), 1)::text,
       MAX(effectif)::text FROM magasin_jour
UNION ALL
SELECT 'ca_total_eur (par jour)', MIN(ca_total_eur)::text, ROUND(AVG(ca_total_eur), 2)::text,
       MAX(ca_total_eur)::text FROM magasin_jour;

-- B2. Les zeros 
SELECT COUNT(*)                                   AS nb_lignes,
       COUNT(*) FILTER (WHERE quantite_vendue = 0) AS jours_sans_vente,
       COUNT(*) FILTER (WHERE casse_declaree = 0)  AS jours_sans_casse,
       ROUND(100.0 * COUNT(*) FILTER (WHERE casse_declaree = 0) / COUNT(*), 1) AS pct_sans_casse
FROM ventes_lot_jour;

-- B3. Comment finissent les lots (la cible a predire) 
SELECT motif_sortie,
       COUNT(*)                                        AS nb_lots,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM sorties_lots
GROUP BY motif_sortie
ORDER BY nb_lots DESC;

-- B4. Les lots "au bord" de la periode (a exclure de certaines analyses) 
SELECT 'Lots arrives avant 2024 (herites)' AS cas, COUNT(*) AS nb_lots
FROM arrivages WHERE NOT arrive_dans_fenetre
UNION ALL
SELECT 'Lots encore en rayon au 21/08/2025 (fin inconnue)', COUNT(*)
FROM sorties_lots WHERE motif_sortie = 'EN_COURS';

-- B5. Lots ECOULES alors que le stock THEORIQUE n est pas a zero 
-- Le lot est vide en rayon (stock reel = 0), mais l'ordinateur croit
-- qu'il reste des articles. La difference = ce qui a disparu sans etre
-- enregistre : vols et casse cachee = la DEMARQUE INCONNUE.
-- DISTINCT ON (arrivage_id) ... ORDER BY date_jour DESC = garder
-- seulement la DERNIERE ligne de chaque lot.
SELECT COUNT(*)  AS nb_lots_ecoules_avec_reste,
       SUM(reste_theorique) AS unites_disparues_sans_trace
FROM (SELECT DISTINCT ON (arrivage_id)
             arrivage_id,
             stock_theorique_debut_jour - quantite_vendue - casse_declaree AS reste_theorique
      FROM ventes_lot_jour
      ORDER BY arrivage_id, date_jour DESC) dernier
JOIN sorties_lots s USING (arrivage_id)
WHERE s.motif_sortie = 'ECOULE'
  AND reste_theorique > 0;

