# Projet NOZ : journal des résultats (pour le rapport)

Données simulées (base `noz_v2`), inspirées du stage. Aucun résultat ne décrit le vrai magasin NOZ : ils valident la méthode.

## Données simulées v2 (calage)
Correspond à la section 3 du rapport (Données) : validation du jeu simulé.

| Indicateur | Valeur v2 | Référence |
|---|---|---|
| CA moyen par semaine | 55 199 € | 55 427 € (annexe, semaine 21 de 2025) |
| Parts de CA par catégorie | à 0,4 point près | annexe |
| Palettes par livraison | 19,8 | environ 20 (mémoire) |
| Jours avec saturation > 1,10 | 6,5 % | |
| RVN prématurés | 10 % (297 lots, soit 9,7 %) | |
| Démarque inconnue | 3,3 % du CA | |
| Random Forest (découpage temporel) | AUC 0,83 | règle de seuil : 0,60 |

Biais de la v1 corrigés : profil hebdomadaire faux (pas de pic le samedi), parts de CA uniformes, cible donnée par une règle de seuil (précision de 99,6 %), fuites de données (cible dans la même table, nombre de lignes par lot, identifiant de lot contenant la catégorie et la date), aucun zéro.

## Étape 1 : base relationnelle PostgreSQL
Correspond à la section 4 du rapport.

- 7 tables. Nombre de lignes : categories 9, magasin_jour 599, arrivages 3 060, ventes_lot_jour 95 332, sorties_lots 3 060, inventaires 189, verite_terrain_lot_jour 95 332.
- La période va du 01/01/2024 au 21/08/2025.
- PostgreSQL a refusé 4 mauvaises données : une catégorie inventée, un lot L99999 qui n'existe pas, une quantité de −5 et le texte « bonjour » dans une colonne date.
- Profil hebdomadaire : le samedi est en tête (10 609 € de CA moyen) et le dimanche en dernier (environ 5,3 k€).
- Incident à raconter : l'encodage de « Bien-être » sous Windows a été lu comme « Bien-Ãªtre ». La clé étrangère a bloqué le chargement, ce qui montre qu'une contrainte protège contre une donnée fausse.
- `arrive_dans_fenetre` : 147 lots sont à FALSE (arrivés entre le 15/11/2023 et le 29/12/2023) et 2 913 à TRUE.

## Étape 2 : contrôles de qualité (`04_controles_qualite.sql`)
Correspond aux sections 3 et 4 du rapport.

- 22 contrôles OK sur 22, répartis en 4 familles :
  - complétude : C01 à C04 ;
  - calculs : C05 à C14 ;
  - règles métier : C15 à C20 ;
  - vérité terrain : C21 et C22.
- Test de sabotage : 5 € ajoutés sur 3 lignes de vente. L'erreur a été détectée par C08 (3 lignes) et par C09 (1 jour).

Profil des données :

| Indicateur | Minimum | Moyenne | Maximum |
|---|---|---|---|
| Prix unitaire | 0,50 € | 5,26 € | 28,67 € |
| Quantité initiale | 91 | 600 | 3 649 |
| Saturation | 0,60 | 0,98 | 1,22 |
| Effectif | 3 | 6,4 | 9 |
| CA par jour | 3 941 € | 7 886 € | 14 548 € |

Lignes lot-jour avec des zéros (95 332 lignes au total) :
- 4 031 sans vente ;
- 88 182 sans casse déclarée, soit 92,5 %.

Dans la v1, il n'y avait aucun zéro.

Comment finissent les lots :

| Motif de sortie | Nombre de lots | Part |
|---|---|---|
| Écoulé | 1 808 | 59,1 % |
| RVN normal à S7 | 858 | 28,0 % |
| RVN prématuré | 297 | 9,7 % |
| En cours | 97 | 3,2 % |

Découvertes :
- `stock_theorique_unites` est le stock du SOIR, pas celui du matin, alors que le nom de la colonne ne le dit pas. À préciser dans le dictionnaire des données.
- 1 290 lots écoulés gardent un stock théorique positif. Au total, 8 877 unités ont disparu sans trace : c'est la démarque inconnue, visible directement dans les données. `quantite_rvn` correspond au stock physique restant, pas au stock théorique.
- Lots au bord de la période : 147 lots hérités (arrivés avant 2024) et 97 lots encore en cours. Ils sont à exclure de certaines analyses.
- Livraisons par jour (nombre moyen de lots) : lundi 9,6, mercredi 11,2, vendredi 11,3, mardi 2,0 et aucune les autres jours.
- La saturation baisse en été 2025 : de 0,81 à 0,64 entre juillet et août.
- Vérité terrain : 18 466 unités volées et 9 157 casses non déclarées. L'écart total des inventaires est de −27 120 unités.

## Pièges méthodologiques à traiter dans le rapport
- Les remises sont décidées sur les lots lents, donc leur effet brut est biaisé.
- `verite_terrain_lot_jour` ne doit jamais servir de variable dans un modèle.
- Il faut un découpage temporel : les mêmes lots ne doivent pas se retrouver à la fois en entraînement et en test.

## Étape 3 : vues d'indicateurs (`05_vues_indicateurs.sql`)
Correspond à la section 4 du rapport (vues SQL) et prépare la section 5.1 (tests des hypothèses).

- 5 vues : `v_ca_jour_semaine`, `v_vie_lot`, `v_rotation_categorie`, `v_demarque_categorie`, `v_saturation_rvn`.
- `v_vie_lot` compte 3 060 lots, dont 2 816 « analysables » (vie complète dans les données).

V1 : CA moyen par jour de la semaine (H1)

| Jour | CA moyen | Indice | Lots reçus en moyenne |
|---|---|---|---|
| Lundi | 7 137 € | 0,91 | 9,6 |
| Mardi | 7 487 € | 0,95 | 2,0 |
| Mercredi | 8 435 € | 1,07 | 11,2 |
| Jeudi | 7 966 € | 1,01 | 0 |
| Vendredi | 8 254 € | 1,05 | 11,3 |
| Samedi | 10 609 € | 1,35 | 0 |
| Dimanche | 5 317 € | 0,67 | 0 |

Le pic du samedi tombe un jour sans livraison : l'ancienne hypothèse « on vend plus les jours de livraison » est contredite.

V3 : rotation par catégorie (lots analysables)

| Catégorie | Taux de vente S1 | Taux de vente fin de vie | RVN prématuré | Part du CA |
|---|---|---|---|---|
| Boissons | 44,8 % | 85,8 % | 11,6 % | 9,7 % |
| Maison | 39,4 % | 85,1 % | 6,8 % | 21,8 % |
| Surgelés | 38,2 % | 84,1 % | 8,2 % | 5,2 % |
| Épicerie | 36,5 % | 79,7 % | 20,1 % | 10,3 % |
| D.P.H. | 35,3 % | 78,2 % | 18,7 % | 6,3 % |
| TDM | 33,6 % | 80,5 % | 9,1 % | 17,8 % |
| Boutique | 33,0 % | 84,3 % | 1,4 % | 3,3 % |
| Textile | 32,6 % | 82,4 % | 9,8 % | 12,6 % |
| Bien-être | 31,7 % | 80,3 % | 10,7 % | 12,9 % |

- Les Boissons sont les plus rapides.
- L'Épicerie et le D.P.H. ont le plus de RVN prématurés.
- La Boutique n'en a presque aucun.

V4 : démarque inconnue par catégorie, mesurée aux inventaires (H2, H3)

| Catégorie | Taux de démarque inconnue |
|---|---|
| Bien-être | 7,22 % |
| D.P.H. | 7,12 % |
| Boissons | 3,38 % |
| Textile | 3,15 % |
| Maison | 2,70 % |
| Surgelés | 2,07 % |
| TDM | 2,03 % |
| Épicerie | 1,06 % |
| Boutique | 0,86 % |

- H2 n'est que partielle : le D.P.H. est en tête, mais à égalité avec le Bien-être.
- H3 va dans le bon sens : la Boutique a la démarque la plus faible.
- Le test statistique se fera à l'étape Python.

V5 : saturation à l'arrivée et RVN prématuré (H4)

| Saturation à l'arrivée | Nombre de lots | RVN prématuré |
|---|---|---|
| Moins de 0,90 | 174 | 8,0 % |
| De 0,90 à 0,99 | 831 | 7,0 % |
| De 1,00 à 1,09 | 1 230 | 11,0 % |
| 1,10 et plus | 581 | 15,0 % |

- Le lien existe, mais il est modéré, loin de la règle quasi parfaite de la v1.
- Le taux de vente en fin de vie baisse quand la saturation monte : de 87,4 % à 78,5 %.

## Étape 4 : tests des hypothèses en Python (`06_tests_hypotheses.ipynb`)
Correspond à la section 5.1 du rapport.

- Python lit directement la base PostgreSQL et les vues de l'étape 3.
- Les tests sont non paramétriques (Kruskal-Wallis, Mann-Whitney, Khi-deux), avec un seuil de 5 %.
- Les 3 graphiques sont enregistrés dans `figures/` : `h1_ca_jour_semaine.png`, `h2_h3_demarque_rayon.png` et `h4_saturation_rvn.png`.

| Hypothèse | Test | p-value | Verdict |
|---|---|---|---|
| H1 : le CA varie selon le jour | Kruskal-Wallis (7 jours) | 1,7e-76 | Confirmée (pic le samedi, creux le dimanche) |
| H1 bis : on vend plus les jours de livraison | Mann-Whitney | 0,86 | Rejetée (7 833 € avec livraison contre 7 954 € sans) |
| Le taux de démarque varie selon le rayon | Kruskal-Wallis (9 rayons) | 2,8e-27 | Oui |
| H2 : D.P.H. plus touché que les autres | Mann-Whitney | 2,9e-10 | Partielle : médiane de 6,65 % contre 2,23 %, mais pas de différence avec le Bien-être (p = 0,97) |
| H3 : Boutique moins touchée | Mann-Whitney | 2,5e-10 | Confirmée : médiane de 0,79 % contre 2,65 % (faible, mais pas nulle) |
| H4 : saturation à l'arrivée → plus de RVN prématurés | Khi-deux = 24,9 | 1,7e-05 | Confirmée, lien modéré : de 7-8 % à 15 % ; au-dessus de 1,10, 85 % des lots ne sont pas renvoyés |

Vérification avec la vérité terrain (vols pour 10 000 unités-jours de stock) :

| Catégorie | Vols pour 10 000 |
|---|---|
| D.P.H. | 14,2 |
| Bien-être | 13,7 |
| Textile | 6,4 |
| Boutique | 0,6 (le plus bas) |

- Les inventaires classent donc les rayons comme les vrais vols, pour H2 comme pour H3.
- Les Boissons ont peu de vols (2,3) mais beaucoup de casse cachée (7,8 pour 10 000) : c'est ce qui explique leur 3e place en démarque inconnue.
- Leçon : la démarque inconnue d'un inventaire mélange vols et casse non déclarée.

## Étape 5 : prédire le RVN prématuré (`07_modele_rvn.ipynb`)
Correspond à la section 5.2 du rapport.

Données utilisées :
- 2 727 lots, dont 294 RVN prématurés (10,8 %).
- On garde les lots arrivés entre le 01/01/2024 et le 04/07/2025 : c'est la règle anti-censure, qui laisse à chaque lot 49 jours pour finir.
- Sans cette règle, les lots arrivés au 3e trimestre 2025 affichaient 0 % de RVN : un biais, puisque seuls les lots écoulés vite étaient déjà sortis.

Découpage temporel :

| Période | Lots | Taux de RVN prématurés |
|---|---|---|
| Entraînement (avant le 01/02/2025) | 1 934 | 7,4 % |
| Test (à partir du 01/02/2025) | 793 | 18,9 % |

Le taux de RVN prématurés change avec le temps (dérive) : de 3,6 % au 1er trimestre 2024 à 19,6 % au 1er trimestre 2025.

Modèle A : prédiction le jour de l'arrivée (AUC)

| Modèle | Test | Entraînement |
|---|---|---|
| Règle simple (saturation seule) | 0,510 | 0,553 |
| Régression logistique | 0,836 | 0,911 |
| Random Forest | 0,822 | 0,969 (sur-apprentissage) |

Modèle B : prédiction après 7 jours de vente (AUC)
2 528 lots étaient encore en rayon au jour 7 ; les 199 autres étaient déjà écoulés.

| Modèle | Test | Entraînement |
|---|---|---|
| Règle simple | 0,502 | 0,547 |
| Régression logistique | 0,922 | 0,957 |
| Random Forest | 0,876 | 0,986 |

- L'objectif du cahier des charges (AUC ≥ 0,75) est atteint.
- Le modèle simple fait mieux que la Random Forest.

Traduction pour le manager : l'équipe surveille les 20 % de lots au score de risque le plus élevé.

| | Modèle A (arrivée) | Modèle B (jour 7) |
|---|---|---|
| Part des RVN détectés (rappel) | 58 % (87 sur 150) | 65 % (98 sur 150) |
| Part des lots signalés qui sont des RVN (précision) | 55 % | 65 % |

Au hasard, on ne détecterait que 20 % des RVN.

Variables les plus utiles (modèle B, baisse de l'AUC quand on mélange la variable) :

| Variable | Baisse de l'AUC |
|---|---|
| Taux de vente de la semaine 1 | 0,316 (de loin la plus utile) |
| Saturation à l'arrivée | 0,030 |
| Quantité initiale | 0,022 |
| Catégorie | 0,017 |

Une variable utile pour prédire n'est pas forcément une cause : un faible taux de vente en semaine 1 est un symptôme.

Graphiques : `figures/m5_courbes_roc.png` et `figures/m5_importance_variables.png`.

## Étape 6 : prévision du CA à 7 jours (`08_prevision_ca.ipynb`)
Correspond à la section 5.3 du rapport.

- Cible : le CA total du magasin par jour. On a choisi le CA plutôt que le stock, parce que le stock dépend des livraisons imposées par le siège (modèle *push*), que le magasin ne connaît pas à l'avance.
- Validation glissante : chaque lundi de 2025, on prévoit les 7 jours suivants avec seulement le passé. Au total, 32 semaines testées, soit 224 jours prévus.

| Méthode | Erreur moyenne (MAE) | Erreur en % (MAPE) | Gain par rapport à la méthode naïve |
|---|---|---|---|
| Naïve saisonnière (même jour la semaine dernière) | 1 078 € | 14,0 % | référence |
| Moyenne des 4 dernières semaines | 985 € | 12,7 % | −8,7 % |
| Holt-Winters (saisonnalité multiplicative de 7 jours) | 847 € | 11,0 % | −21,5 % |

- L'objectif du cahier des charges (−15 %) est atteint par Holt-Winters.

Erreur de Holt-Winters par jour de la semaine :

| Jour | Erreur moyenne |
|---|---|
| Lundi | 8,9 % |
| Mardi | 10,7 % |
| Mercredi | 12,3 % |
| Jeudi | 8,1 % |
| Vendredi | 11,2 % |
| Samedi | 13,7 % (le plus difficile) |
| Dimanche | 12,1 % |

Erreur de Holt-Winters selon l'événement :

| Événement | Erreur moyenne |
|---|---|
| Aucun | 10,9 % |
| Pâques | 12,1 % |
| Soldes | 10,9 % |

- Piste d'amélioration : donner le calendrier des événements au modèle (SARIMAX ou régression).
- Export pour Power BI : `previsions_7j.csv` (224 lignes, séparateur `;`, décimales avec une virgule).
- Graphiques : `figures/m6_serie_ca.png` et `figures/m6_prevision_vs_reel.png`.

## Étape 7 : tableau de bord Power BI (`dashboard_noz.pbix`)

- Connexion : PostgreSQL `localhost` / `noz`, mode Importer. 7 tables ou vues chargées (`magasin_jour`, `categories`, `inventaires`, `v_vie_lot`, `v_ca_jour_semaine`, `v_rotation_categorie`, `v_demarque_categorie`), plus `previsions_7j.csv`. Exclues exprès : `verite_terrain_lot_jour` (pas une donnée métier) et `ventes_lot_jour` (déjà résumée par les vues).
- Modèle en étoile : `categories[categorie]` → `v_vie_lot`, `inventaires` (1 à *), `v_rotation_categorie`, `v_demarque_categorie` (1 à 1). `magasin_jour[date_jour]` → `v_vie_lot[date_arrivee]`, `inventaires[date_inventaire]`. Filtre croisé « Unique » sur les 1 à *.
- Mesures DAX (table `_Mesures`), vérifiées contre PostgreSQL :

| Mesure | Power BI | PostgreSQL |
|---|---|---|
| CA total | 4 723 465 € | 4 723 465,16 € |
| Démarque inconnue € | 154 277 € | 154 277,37 € |
| Taux démarque | 3,32 % | 3,32 % |
| Lots analysables | 2 816 | 2 816 |
| % RVN prématuré | 10,4 % | 10,4 % |
| Taux vente S1 | 36,3 % | 36,3 % |

- Page 1 « Radar des anomalies » : 4 cartes, taux de démarque par rayon, % RVN prématuré par rayon, segment par rayon. Test : filtre D.P.H. → taux de démarque 7,12 % (identique à la vue SQL), % RVN prématuré 18,7 %.
- Page 2 « Capacity planning » : CA moyen par jour de la semaine (samedi en tête), courbe CA réel vs prévision Holt-Winters sur 224 jours, segment pour choisir une semaine de prévision (32 lundis).
- Page 3 « Saturation et démarque » (objectif O5 complété) :
  - Paramètre what-if `Seuil saturation` : `GENERATESERIES(0.8, 1.2, 0.05)`, défaut 1,00, mesure `[Valeur Seuil saturation]`. Curseur en haut à gauche (valeur laissée sur 1,10, le seuil d'alerte de l'étape 3).
  - 3 nouvelles mesures (total 9 mesures, objectif ≥ 8 atteint) :
    - `Jours au-dessus du seuil = COUNTROWS(FILTER(magasin_jour, taux_saturation > [Valeur Seuil saturation])) + 0`
    - `% RVN au-dessus du seuil` et `% RVN sous le seuil` : part de RVN prématurés parmi les lots analysables arrivés au-dessus (ou au plus) du seuil de saturation.
  - Courbe de la saturation par jour avec la ligne du seuil qui bouge avec le curseur ; courbe du taux de démarque inconnue par inventaire (21 inventaires).
  - Vérification contre PostgreSQL (base simulée) :

| Seuil | Jours au-dessus | % RVN au-dessus | % RVN sous | Power BI = SQL ? |
|---|---|---|---|---|
| 1,00 | 229 | 12,53 % | 7,14 % | oui |
| 1,05 | 101 | 14,50 % | 7,91 % | oui |
| 1,10 | 39 | 15,74 % | 9,38 % | oui |

  - Lecture : plus le seuil monte, plus l'écart de RVN prématuré entre lots « saturés » et « non saturés » reste net (environ 5 à 6 points). Cohérent avec H4 (étape 4). Capture : `etape7/page3_saturation_demarque.jpg`.
  - Piège : dans la zone de saisie du curseur, Power BI attend un point (`1.1`), pas une virgule ; `1,1` est lu comme 1.



Chiffres nouveaux calculés pour la section 8 (base simulée) :
- Lots analysables RVN prématurés : 294 lots, 255 254 unités renvoyées, 1 220 665 € au prix initial. Période test (arrivés dès le 01/02/2025) : 150 lots, 604 129 € au prix initial.
- Démarque inconnue € par rayon : Bien-être 44 316 € (28,7 %), Maison 27 021 € (17,5 %), D.P.H. 21 216 € (13,8 %), Textile 18 284 € (11,9 %), TDM 16 767 € (10,9 %), Boissons 15 325 € (9,9 %), Surgelés 5 091 € (3,3 %), Épicerie 4 930 € (3,2 %), Boutique 1 328 € (0,9 %).
- Bien-être + D.P.H. = 65 531 € = 42,5 % de la démarque inconnue, pour 19,2 % du CA.
- Écarts au cahier des charges assumés dans le rapport : hypothèses renumérotées (H2 à H4), QR2 / H5 (remises) non traitées, O4 fait sur le CA au lieu de la saturation, O2 partiel (4 hypothèses au lieu de 6), O6 en cours.
- Formats des cartes corrigés (04:47) : Démarque inconnue € en Devise 0 décimale (« 154K € »), CA total en Devise 2 décimales (« 4,72M€ »), Lots analysables 1 décimale (« 2,8K »). Le nouveau visuel Carte n'a pas d'option « Unités d'affichage » pour la valeur : le format se règle dans Outils de mesure. Captures refaites dans `captures/`.

### Relecture complète du rapport (2026)

Chiffres ajoutés au rapport (vérifiés par requête SQL sur la base simulée) :
- Zéros : 4 031 lignes lot-jour sur 95 332 (4,2 %) sans aucune vente ; 92,5 % des lignes sans casse déclarée.
- Min / moyenne / max : prix unitaire 0,50 / 5,26 / 28,67 € ; quantité reçue 91 / 600 / 3 649 ; saturation du jour 0,60 / 0,98 / 1,22 ; effectif 3 / 6,4 / 9 ; CA par jour 3 941 / 7 886 / 14 548 €.
- Indice du jour = CA du jour / CA moyen journalier (7 886 €) : samedi 1,35, dimanche 0,67.
- 15,0 % (lots ≥ 1,10 : 581) contre 15,7 % (lots > 1,10 : 470) : ce ne sont pas les mêmes lots.
- Valeur des RVN prématurés de la période test : 150 lots, 604 129 € (quantite_rvn × prix initial). Illustration section 8 : 98/150 × 604 k€ ≈ 395 k€ ; si 20 % vendus avec 30 % de remise ≈ 55 k€ de CA (hypothèses non vérifiées).
Corrections de fond : conclusion = 4 objectifs sur 6 (O2 partiel, O6 en cours) ; QR4 traitée en partie ; aucune prévision de la saturation (alerte réactive) ; H1 = contrôle de calage ; hypothèses du cahier des charges notées CdC-H1 à CdC-H6.
