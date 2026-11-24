-- Partie 2 : exploration des données en SQL
SET search_path TO shopdata;

-- Q1 : volumétrie de chaque table
SELECT 'categories' AS table_name, COUNT(*) AS nb_lignes FROM categories
UNION ALL SELECT 'produits',        COUNT(*) FROM produits
UNION ALL SELECT 'clients',         COUNT(*) FROM clients
UNION ALL SELECT 'commandes',       COUNT(*) FROM commandes
UNION ALL SELECT 'lignes_commande', COUNT(*) FROM lignes_commande;

-- Q2 : chiffre d'affaires et nombre de commandes par catégorie
SELECT c.libelle                              AS categorie,
       SUM(l.quantite * p.prix_unitaire)      AS ca,
       COUNT(DISTINCT l.id_commande)          AS nb_commandes
FROM lignes_commande l
JOIN produits   p ON p.id_produit   = l.id_produit
JOIN categories c ON c.id_categorie = p.id_categorie
GROUP BY c.libelle
ORDER BY ca DESC;

-- Q3 : CA mensuel par canal (une colonne par canal)
SELECT date_trunc('month', co.date_commande)::date                               AS mois,
       SUM(l.quantite * p.prix_unitaire) FILTER (WHERE co.canal = 'web')     AS ca_web,
       SUM(l.quantite * p.prix_unitaire) FILTER (WHERE co.canal = 'mobile')  AS ca_mobile,
       SUM(l.quantite * p.prix_unitaire) FILTER (WHERE co.canal = 'magasin') AS ca_magasin,
       SUM(l.quantite * p.prix_unitaire)                                     AS ca_total
FROM commandes co
JOIN lignes_commande l ON l.id_commande = co.id_commande
JOIN produits        p ON p.id_produit  = l.id_produit
GROUP BY 1
ORDER BY 1;

-- Q4 : panier moyen, panier médian, nombre moyen d'articles distincts
WITH paniers AS (
    SELECT l.id_commande,
           SUM(l.quantite * p.prix_unitaire) AS montant,
           COUNT(*)                          AS nb_articles_distincts
    FROM lignes_commande l
    JOIN produits p ON p.id_produit = l.id_produit
    GROUP BY l.id_commande
)
SELECT ROUND(AVG(montant), 2)                                            AS panier_moyen,
       ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY montant)::numeric, 2) AS panier_median,
       ROUND(AVG(nb_articles_distincts), 2)                              AS nb_moyen_articles_distincts
FROM paniers;

-- Q5 : top 3 des produits les plus vendus (en quantité) par catégorie
WITH ventes AS (
    SELECT c.libelle AS categorie, p.libelle AS produit, SUM(l.quantite) AS qte,
           RANK() OVER (PARTITION BY c.libelle ORDER BY SUM(l.quantite) DESC) AS rang
    FROM lignes_commande l
    JOIN produits   p ON p.id_produit   = l.id_produit
    JOIN categories c ON c.id_categorie = p.id_categorie
    GROUP BY c.libelle, p.libelle
)
SELECT categorie, rang, produit, qte
FROM ventes
WHERE rang <= 3
ORDER BY categorie, rang, produit;

-- Q6 : contrôle qualité
SELECT
  (SELECT COUNT(*) FROM commandes co
    WHERE NOT EXISTS (SELECT 1 FROM lignes_commande l WHERE l.id_commande = co.id_commande))
      AS commandes_sans_ligne,
  (SELECT COUNT(*) FROM clients cl
    WHERE NOT EXISTS (SELECT 1 FROM commandes co WHERE co.id_client = cl.id_client))
      AS clients_sans_commande;
