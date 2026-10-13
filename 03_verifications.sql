
-- PROJET NOZ - ETAPE 1 : PREMIERES REQUETES POUR "VOIR" LA BASE


-- Structure de base :
--     SELECT   <quelles colonnes je veux voir>
--     FROM     <dans quelle table>
--     WHERE    <quelles lignes je garde>
--     GROUP BY <regrouper par ...>
--     ORDER BY <trier par ...>
--     LIMIT    <combien de lignes au maximum>
--


-- Q1. Combien de lignes dans chaque table ?

SELECT 'categories' AS table_nom, COUNT(*) AS nb_lignes FROM categories
UNION ALL SELECT 'magasin_jour',            COUNT(*) FROM magasin_jour
UNION ALL SELECT 'arrivages',               COUNT(*) FROM arrivages
UNION ALL SELECT 'ventes_lot_jour',         COUNT(*) FROM ventes_lot_jour
UNION ALL SELECT 'sorties_lots',            COUNT(*) FROM sorties_lots
UNION ALL SELECT 'inventaires',             COUNT(*) FROM inventaires
UNION ALL SELECT 'verite_terrain_lot_jour', COUNT(*) FROM verite_terrain_lot_jour;

-- Q2. A quoi ressemble un lot ? (5 premieres lignes de "arrivages")
SELECT * FROM arrivages ORDER BY date_arrivee, arrivage_id LIMIT 5;

-- Q3. Combien de lots par categorie ?
--     GROUP BY = "fais un paquet par categorie, puis compte chaque paquet".
SELECT categorie, COUNT(*) AS nb_lots
FROM arrivages
GROUP BY categorie
ORDER BY nb_lots DESC;

-- Q4. Comment les lots ont-ils fini ?
--     (EN_COURS = pas encore termines a la fin de la periode.)
SELECT motif_sortie, COUNT(*) AS nb_lots
FROM sorties_lots
GROUP BY motif_sortie
ORDER BY nb_lots DESC;

-- Q5. La vie d'un lot : ses 7 premiers jours.
--     JOIN = "colle les lignes de deux tables qui parlent du meme lot".
SELECT a.arrivage_id, a.categorie, v.date_jour, v.jour_de_vie,
       v.stock_theorique_debut_jour AS stock, v.quantite_vendue AS vendu
FROM arrivages AS a
JOIN ventes_lot_jour AS v ON v.arrivage_id = a.arrivage_id
WHERE a.arrivage_id = (SELECT arrivage_id FROM arrivages
                       WHERE arrive_dans_fenetre        -- = TRUE
                       ORDER BY date_arrivee, arrivage_id LIMIT 1)
ORDER BY v.jour_de_vie
LIMIT 7;

-- Q6. Chiffre d'affaires moyen par jour de la semaine.
SELECT jour_semaine, ROUND(AVG(ca_total_eur)) AS ca_moyen_eur
FROM magasin_jour
GROUP BY jour_semaine
ORDER BY ca_moyen_eur DESC;

-- Q7. Les 5 jours ou le magasin etait le plus plein.
SELECT date_jour, jour_semaine, taux_saturation, evenement
FROM magasin_jour
ORDER BY taux_saturation DESC, date_jour
LIMIT 5;

-- Q8. Combien de lots etaient deja en rayon avant 2024 ?
--     (false = arrive avant la periode, true = arrive pendant la periode)
SELECT arrive_dans_fenetre, COUNT(*) AS nb_lots
FROM arrivages
GROUP BY arrive_dans_fenetre;

-- Q9. calculer avec les dates.
--     Combien de jours entre l'arrivee et la sortie, en moyenne, par motif ?
--     (date_sortie - date_arrivee donne directement un nombre de jours,
--      c'est l'interet du vrai type DATE.)
SELECT s.motif_sortie,
       ROUND(AVG(s.date_sortie - a.date_arrivee), 1) AS jours_en_rayon_moyen
FROM sorties_lots AS s
JOIN arrivages    AS a ON a.arrivage_id = s.arrivage_id
WHERE s.date_sortie IS NOT NULL
GROUP BY s.motif_sortie
ORDER BY jours_en_rayon_moyen;
