# Projet NOZ : cahier des charges et plan du rapport

David DOE · 2026

Document de départ du projet, écrit avant les analyses. Ce qui a été fait autrement (hypothèses renumérotées, prévision du CA au lieu de la saturation, effet des remises non traité) est expliqué dans le rapport (`rapport_noz.pdf`).

## Partie A. Fiche de projet (cahier des charges)

### 1. Identité du projet

| Rubrique | Contenu |
| --- | --- |
| Titre | Piloter la saturation d'un magasin de déstockage : base SQL, modèles prédictifs et tableau de bord. Projet data inspiré de NOZ Saint-Pol-sur-Mer |
| Auteur | David DOE |
| Cadre | Projet personnel et académique, Master SIAD |
| Nature | Projet de data science : SQL, Python, Power BI |
| Données | Base simulée v2 : 6 tables, 3 060 lots, 95 332 lignes lot-jour, du 01/01/2024 au 21/08/2025, calibrée sur les relevés réels de la semaine 21 de 2025 |
| Durée indicative | 6 semaines |

### 2. Contexte et origine

Mon stage de L3 au NOZ de Saint-Pol-sur-Mer (29 avril au 20 juin 2025) était opérationnel : mise en rayon, étiquetage, retours de non-vendus. Mon mémoire en a tiré un constat : la gestion repose sur des inventaires papier, sans outil de pilotage de la saturation, des remises ni de la démarque inconnue. Il proposait des pistes : seuil d'alerte dès la semaine 4, remise avant la semaine 8, suivi numérique des indicateurs.

Ce projet transforme ces pistes en preuve de concept chiffrée. Aucune donnée interne n'étant disponible, il s'appuie sur un simulateur de magasin calibré sur les relevés de mon mémoire : CA hebdomadaire de 55,4 k€, profil par jour de la semaine, parts de CA par catégorie, environ 20 palettes par livraison, cycle de 49 jours. Les résultats valident une méthode. Ils ne décrivent pas NOZ.

### 3. Problématique, questions et hypothèses

Problématique. Dans un magasin à approvisionnement subi, comment anticiper la saturation et en limiter les coûts (retours anticipés, remises tardives, démarque inconnue) à partir des données d'exploitation ?

Questions de recherche

- QR1. Quels lots risquent d'être renvoyés avant 49 jours, et peut-on le savoir dès leur arrivée ?
- QR2. Quand et à quel niveau démarquer ? Quel est l'effet réel d'une remise sur l'écoulement ?
- QR3. Où et quand se concentre la démarque inconnue ?
- QR4. Peut-on prévoir la saturation à 7 jours pour planifier retours et livraisons ?

Hypothèses. Chaque test est d'abord réalisé sur les tables observées, puis comparé à la table de vérité terrain.

| N° | Hypothèse | Test prévu |
| --- | --- | --- |
| H1 | Les ventes suivent le profil hebdomadaire de l'annexe (pic le samedi, creux le dimanche), sans effet « jour de livraison » | Comparaison par jour de semaine (Kruskal-Wallis), taille d'effet |
| H2 | Au-delà d'une saturation d'environ 1,0, la casse augmente de façon non linéaire | Régression de comptage (binomiale négative) avec terme de saturation |
| H3 | Un effectif plus faible augmente le vol | Régression de comptage sur l'effectif, avec catégorie et week-end en contrôle |
| H4 | La boutique à vitrine a un taux de vol nettement plus faible que D.P.H. et Bien-être, sans être nul | Écart d'inventaire par catégorie, intervalles de confiance |
| H5 | Une remise accélère l'écoulement à reste à vendre égal ; l'effet brut est biaisé | Comparaison brute, puis pondération par score de propension |
| H6 | Le risque de RVN prématuré croît avec la taille du lot et la saturation à l'arrivée | Classification, importance par permutation |

### 4. Objectifs et critères de réussite

| Objectif | Critère mesurable |
| --- | --- |
| O1. Base relationnelle | 6 tables chargées, clés vérifiées, 5 vues d'indicateurs, 10 contrôles de qualité automatisés qui passent |
| O2. Analyse | 6 hypothèses testées avec taille d'effet et intervalle de confiance, comparées à la vérité terrain |
| O3. Classification du RVN prématuré | AUC d'au moins 0,75 en découpage temporel, supérieure à la règle de seuil (0,60), calibration vérifiée |
| O4. Prévision de la saturation à 7 jours | Erreur absolue moyenne inférieure d'au moins 15 % à la référence « même jour la semaine précédente » (cible à ajuster une fois la référence mesurée) |
| O5. Tableau de bord Power BI | 3 pages, au moins 8 mesures DAX, un paramètre what-if sur le seuil de saturation |
| O6. Reproductibilité | Dépôt avec README, requirements, graine fixe, exécution de bout en bout en une commande |

### 5. Périmètre

Inclus : base SQL, analyse exploratoire, tests d'hypothèses, modèles de classification et de prévision, tableau de bord, recommandations illustrées par simulation, rapport et dépôt.

Exclus : données réelles de NOZ, mise en production, conclusions chiffrées sur l'entreprise, deep learning.

### 6. Données et règles de bon usage

Tables : `magasin_jour` (contexte quotidien), `arrivages` (variables connues à l'arrivée du lot), `ventes_lot_jour`, `sorties_lots` (la cible), `inventaires` (démarque inconnue toutes les 4 semaines), `verite_terrain_lot_jour` (validation uniquement).

Règles

- La cible reste dans sa table : les variables viennent de `arrivages` et `magasin_jour` à la date d'arrivée.
- Découpage temporel, jamais aléatoire sur les lignes lot-jour.
- Les lots « en cours » (non terminés) et « hérités » (arrivés avant 2024) sont traités explicitement.
- La vérité terrain ne sert jamais de variable, seulement de référence pour juger les méthodes.

Limites connues : calage sur une seule semaine réelle ; prix, casse et vol sont des hypothèses ; 62 % de lots entièrement écoulés, à confronter aux vrais indicateurs ; remises décidées sur les lots lents (biais de sélection voulu).

### 7. Méthodologie et outils

- SQL (SQLite ou PostgreSQL) : schéma, vues, requêtes à fenêtres.
- Python : pandas, scikit-learn, statsmodels, matplotlib ; notebooks et modules.
- Validation : découpage temporel, validation glissante, baselines systématiques, métriques adaptées au déséquilibre (PR-AUC, rappel à précision fixée).
- Power BI : modèle en étoile, mesures DAX, paramètre what-if.
- Qualité : tests automatisés sur les règles de la base, graine fixe, versionnement Git.

### 8. Livrables

| Livrable | Format |
| --- | --- |
| Base SQL (schéma, chargement, vues, tests) | Fichiers .sql et base PostgreSQL |
| Analyses et modèles | Notebooks .ipynb et modules .py |
| Tableau de bord | Fichier .pbix et captures PDF |
| Rapport | PDF d'environ 30 pages |
| Dépôt public | GitHub : README, requirements, simulateur, données |
| Synthèse d'une page |

### 9. Planning (6 semaines, à adapter)

| Semaine | Contenu | Jalon |
| --- | --- | --- |
| S1 | Cadrage, schéma SQL, chargement, contrôles de qualité | Base opérationnelle |
| S2 | Analyse exploratoire, tests H1 à H4 | Notebook d'exploration |
| S3 | Classification du RVN prématuré, baselines, interprétation | Modèle et seuil d'alerte |
| S4 | Effet des remises (H5), prévision de la saturation | Résultats de modélisation |
| S5 | Power BI, recommandations, test de politiques (option) | Tableau de bord |
| S6 | Rédaction, relecture, dépôt GitHub| Rapport final |

### 10. Risques et parades

| Risque | Parade |
| --- | --- |
| Fuite de données | Cible séparée, découpage temporel, revue des variables avant chaque modèle |
| Résultats trop beaux à cause du simulateur | Comparaison à la vérité terrain, baselines simples, formulation « validation de méthode » |
| Sur-interprétation causale des remises | Pondération par propension, lecture prudente |
| Dérive du périmètre | Les idées de la partie C sont optionnelles ; priorité aux objectifs O1 à O6 |


## Partie B. Structure du rapport (environ 30 pages hors annexes)

| N° | Section | Contenu | Preuve attendue | Pages |
| --- | --- | --- | --- | --- |
| 0 | Résumé exécutif | Problème, méthode, 3 résultats chiffrés, limite principale | Tableau de synthèse | 1 |
| 1 | Introduction | Contexte NOZ, lien avec le stage et le mémoire, problématique, QR1 à QR4, plan. Encadré « Transparence sur les données » | Schéma question, méthode, décision | 2 |
| 2 | Cadrage métier | Modèle push, cycle de 49 jours, flux, rôle du manager. Définitions et formules : saturation, taux de vente en semaine 1, écoulement en fin de vie, taux de RVN, démarque inconnue en % du CA | Schéma du parcours d'un lot, tableau des indicateurs | 3 |
| 3 | Données et validation du jeu simulé | Principe du simulateur (offre, demande, manager, pertes), calibrage sur l'annexe, schéma relationnel, dictionnaire, contrôles, règles anti-fuite, limites | Tableau de calibrage v2 contre annexe, schéma entité-relation | 4 |
| 4 | Phase 1 : ingénierie SQL | Modèle relationnel, chargement, 5 vues d'indicateurs, requêtes à fenêtres (écoulement par semaine de vie), tests de cohérence | Schéma, 2 requêtes commentées, tableau des tests | 3 |
| 5 | Phase 2 : analyse exploratoire et tests | Profil hebdomadaire, saisonnalité, saturation, casse, vol, inventaires. Tests H1 à H4 avec taille d'effet et intervalle, comparés à la vérité terrain | 6 graphiques, tableau hypothèse / verdict / vérité | 4 |
| 6 | Phase 3 : modélisation | 6.1 RVN prématuré : cadrage, variables connues à l'arrivée, découpage temporel, baselines (règle de seuil, régression logistique), modèle d'arbres, PR-AUC, calibration, importance par permutation. 6.2 Effet des remises (H5) : effet brut puis corrigé. 6.3 Prévision de la saturation à 7 jours : référence naïve, modèle saisonnier, modèle d'arbres avec calendrier, validation glissante. 6.4 Démarque inconnue : modèle sur inventaires et détection d'anomalies | Courbes ROC et PR, calibration, importances, erreurs par horizon | 7 |
| 7 | Phase 4 : Power BI | Modèle en étoile, mesures DAX, 3 pages (radar de saturation et alertes ; cycle de vie et remises ; démarque inconnue), paramètre what-if | Captures commentées, une décision par page | 3 |
| 8 | Recommandations | Règle d'alerte de saturation, calendrier de remises selon le reste à vendre, ciblage des inventaires. Gains estimés en simulation, présentés comme illustration | Tableau décision / indicateur / seuil / gain simulé | 2 |
| 9 | Limites et perspectives | Validité externe, calage sur une semaine, hypothèses de simulation, passage à des données réelles, industrialisation | Tableau limite / impact / parade | 1 |
| 10 | Conclusion | Réponses à QR1 à QR4, compétences mobilisées, suite | n/a | 1 |
| A | Annexes | Dictionnaire, schéma entité-relation, requêtes, code, captures, README du simulateur | n/a | n/a |

Règles de rédaction

- Chaque section suit le même fil : question, méthode, résultat, décision.
- «base simulée », jamais « chez NOZ », pour un résultat.
- Comparer chaque résultat à la vérité terrain : « le pipeline retrouve l'effet injecté ».
- Légender chaque figure : « Source : base simulée v2 ».

## Partie C. Idées pour enrichir le projet (optionnelles)

1. Tester des politiques dans le simulateur. Faire varier la tolérance de saturation et le calendrier de remises, puis comparer CA, RVN et démarque inconnue. Le rapport devient une étude d'aide à la décision.
2. Robustesse par répétition. Régénérer la base avec 20 graines et rapporter la distribution des AUC et des erreurs de prévision : les résultats ne dépendent plus d'un seul tirage.
3. Effet causal des remises. Pondération par score de propension, comparée à l'effet réel du simulateur (poids de demande ×1,7 et ×2,6).
4. Seuil de décision économique. Chiffrer le coût d'un retour inutile et d'un retour manqué, puis choisir le seuil d'alerte qui minimise le coût plutôt qu'un seuil de 0,5.
5. Détection d'anomalies sur les inventaires. Comparer l'écart de chaque catégorie à son historique et déclencher des alertes, validées par la vérité terrain.
6. Prévision avec intervalles. Quantiles à 7 jours pour estimer la probabilité de dépasser 1,10 de saturation.
7. Ingénierie visible. Tests automatisés sur la base, commande unique de reproduction, README 

