-- Partie 7 : mesure du calcul des paires en SQL (comparaison avec MapReduce)
SET search_path TO shopdata;
\timing on

SELECT COUNT(*) AS nb_paires_frequentes FROM (
    SELECT l1.id_produit, l2.id_produit
    FROM lignes_commande l1
    JOIN lignes_commande l2
      ON l2.id_commande = l1.id_commande AND l1.id_produit < l2.id_produit
    GROUP BY l1.id_produit, l2.id_produit
    HAVING COUNT(*) >= 100
) t;

-- Nombre de paires selon le seuil
SELECT seuil, COUNT(*) FILTER (WHERE nb >= seuil) AS nb_paires
FROM (
    SELECT COUNT(*) AS nb
    FROM lignes_commande l1
    JOIN lignes_commande l2
      ON l2.id_commande = l1.id_commande AND l1.id_produit < l2.id_produit
    GROUP BY l1.id_produit, l2.id_produit
) p
CROSS JOIN (VALUES (100), (250), (500), (1000)) s(seuil)
GROUP BY seuil
ORDER BY seuil;

-- Valeur théorique de « Map output records » du job 2 : somme de k + k(k-1)/2
SELECT SUM(k + k * (k - 1) / 2) AS map_output_records_attendu,
       SUM(k)                   AS items_emis,
       SUM(k * (k - 1) / 2)     AS paires_emises
FROM (SELECT COUNT(*) AS k FROM lignes_commande GROUP BY id_commande) t;

\timing off
