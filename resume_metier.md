# Résumé métier : piloter un magasin discount avec ses propres données

David DOE · 2026

*Une page pour un responsable de magasin ou de réseau, sans jargon technique.*

> Toutes les données sont simulées à partir de mes observations de stage chez NOZ (Saint-Pol-sur-Mer, 2025). Aucune donnée interne de l'enseigne n'a été utilisée. Les chiffres montrent ce qu'un outil peut apporter ; ils ne décrivent pas un vrai magasin.

## Le problème

Un magasin de déstockage ne choisit pas ce qu'il reçoit : la centrale envoie les lots. Trois coûts en découlent :

1. Les retours trop tôt. Quand le magasin est plein, des lots repartent à l'entrepôt avant la fin de leurs 7 semaines en rayon, sans avoir eu le temps de se vendre.
2. La marchandise qui disparaît. Vols et casse non déclarée ne se voient qu'à l'inventaire, une fois par mois environ. Entre deux inventaires, personne ne sait quel rayon perd de l'argent.
3. Le personnel au mauvais moment. On renforce souvent l'équipe les jours de livraison, alors que ce ne sont pas forcément les jours où l'on vend le plus.

## Ce que l'outil montre (magasin simulé, 20 mois)

| Constat | Ce que cela veut dire pour le magasin |
|---|---|
| Après une semaine en rayon, l'outil repère 2 lots sur 3 qui seront renvoyés trop tôt, en ne surveillant que 1 lot sur 5. | On peut agir sur une petite liste de lots chaque lundi (remise, meilleur emplacement), au lieu de tout surveiller. |
| Quand le magasin est plein à plus de 110 %, les lots qui arrivent repartent trop tôt 1,7 fois plus souvent (15,7 % contre 9,4 %). | La place est un vrai coût : sortir les lots qui ne se vendent plus avant une grosse livraison protège les nouveaux. |
| Deux rayons (Bien-être et Droguerie-Parfumerie-Hygiène) concentrent 42 % de la marchandise disparue pour seulement 19 % des ventes. | Les comptages et la surveillance doivent viser ces deux rayons en priorité. |
| Les Boissons perdent de la marchandise surtout par casse non déclarée, pas par vol. | La bonne réponse est de faciliter la déclaration de casse, pas d'ajouter un antivol. |
| Le samedi fait 35 % de ventes en plus que la moyenne, sans livraison ce jour-là. Les jours de livraison ne vendent pas plus. | Il faut deux plannings : la mise en rayon suit les livraisons, la caisse suit les ventes. |
| Les ventes des 7 prochains jours se prévoient avec environ 11 % d'erreur. | Le planning de la semaine peut s'appuyer sur un chiffre prévu, pas seulement sur l'habitude. |

## Quatre décisions simples

1. Chaque lundi, revoir la courte liste des lots les plus à risque et choisir pour chacun : remise, déplacement ou retour anticipé.
2. Quand le magasin dépasse 110 % de remplissage, le signaler à la centrale et sortir d'abord les lots qui ne se vendent plus.
3. Compter plus souvent le Bien-être et la Droguerie-Parfumerie-Hygiène (par exemple chaque semaine, sur une partie du rayon).
4. Construire le planning du personnel à partir des ventes prévues, et pas des jours de livraison.

## Ce que l'outil ne fait pas encore

- Il ne prévoit pas quand le magasin va être plein : l'alerte se déclenche quand le seuil est dépassé.
- Il ne mesure pas si une remise fait vraiment vendre plus. C'est la prochaine étape.
- Il a été testé sur un magasin simulé. Avant toute décision, il faudrait le relancer sur les données d'un vrai magasin.

## Comment c'est construit

Une base de données qui vérifie elle-même la qualité des chiffres (22 contrôles), des analyses statistiques, deux modèles de prévision, et un tableau de bord Power BI de 3 pages qu'un responsable peut utiliser sans connaître les outils. Le détail est dans le [rapport complet](rapport_noz.pdf).
