-- Partie 5 : retour dans PostgreSQL et règles d'association
-- Lancer psql depuis le dossier qui contient paires_resultats.tsv
SET search_path TO shopdata;

-- 1. Table de réception (fournie) et chargement
DROP TABLE IF EXISTS mr_resultats_brut;
CREATE TABLE mr_resultats_brut (
    cle  TEXT     NOT NULL,
    nb   INTEGER  NOT NULL
);
\copy shopdata.mr_resultats_brut FROM 'paires_resultats.tsv' WITH (FORMAT text)

-- 2. Supports des produits et des paires
DROP TABLE IF EXISTS support_items;
CREATE TABLE support_items AS
SELECT split_part(cle, ':', 2)::int AS id_produit, nb
FROM mr_resultats_brut
WHERE cle LIKE 'I:%';
ALTER TABLE support_items ADD PRIMARY KEY (id_produit);

DROP TABLE IF EXISTS support_paires;
CREATE TABLE support_paires AS
SELECT split_part(split_part(cle, ':', 2), ',', 1)::int AS produit_a,
       split_part(split_part(cle, ':', 2), ',', 2)::int AS produit_b,
       nb
FROM mr_resultats_brut
WHERE cle LIKE 'P:%';
ALTER TABLE support_paires ADD PRIMARY KEY (produit_a, produit_b);

-- 3. Contrôle croisé MapReduce / SQL (résultat attendu : 0)
--    Le même seuil (100) est appliqué au calcul SQL.
WITH paires_sql AS (
    SELECT l1.id_produit AS produit_a, l2.id_produit AS produit_b, COUNT(*) AS nb
    FROM lignes_commande l1
    JOIN lignes_commande l2
      ON l2.id_commande = l1.id_commande AND l1.id_produit < l2.id_produit
    GROUP BY l1.id_produit, l2.id_produit
    HAVING COUNT(*) >= 100
)
SELECT COUNT(*) AS nb_ecarts
FROM paires_sql s
FULL JOIN support_paires m
  ON m.produit_a = s.produit_a AND m.produit_b = s.produit_b
WHERE s.nb IS DISTINCT FROM m.nb;

-- Même contrôle pour les produits seuls (résultat attendu : 0)
WITH items_sql AS (
    SELECT id_produit, COUNT(*) AS nb
    FROM lignes_commande GROUP BY id_produit HAVING COUNT(*) >= 100
)
SELECT COUNT(*) AS nb_ecarts_items
FROM items_sql s
FULL JOIN support_items m ON m.id_produit = s.id_produit
WHERE s.nb IS DISTINCT FROM m.nb;

-- 4. Support, confiance et lift dans les deux sens
DROP TABLE IF EXISTS regles_association;
CREATE TABLE regles_association AS
WITH n AS (
    SELECT COUNT(DISTINCT id_commande)::numeric AS nb_paniers FROM lignes_commande
),
sens AS (
    SELECT produit_a AS antecedent, produit_b AS consequent, nb FROM support_paires
    UNION ALL
    SELECT produit_b, produit_a, nb FROM support_paires
)
SELECT s.antecedent,
       s.consequent,
       s.nb                                                   AS nb_paniers_xy,
       -- valeurs exactes (l'arrondi n'est fait qu'à l'affichage, pour ne pas
       -- fausser les filtres : 0,29996 arrondi à 0,3000 passerait le seuil)
       s.nb / n.nb_paniers                                    AS support,
       s.nb::numeric / ix.nb                                  AS confiance,
       (s.nb::numeric / ix.nb) / (iy.nb / n.nb_paniers)       AS lift
FROM sens s
CROSS JOIN n
JOIN support_items ix ON ix.id_produit = s.antecedent
JOIN support_items iy ON iy.id_produit = s.consequent;

-- 5. Règles intéressantes : confiance >= 0,30 et lift > 1,5
SELECT pa.libelle AS si_achat_de, pc.libelle AS alors_achat_de,
       r.nb_paniers_xy, ROUND(r.support, 4) AS support,
       ROUND(r.confiance, 4) AS confiance, ROUND(r.lift, 4) AS lift
FROM regles_association r
JOIN produits pa ON pa.id_produit = r.antecedent
JOIN produits pc ON pc.id_produit = r.consequent
WHERE r.confiance >= 0.30 AND r.lift > 1.5
ORDER BY r.lift DESC, r.confiance DESC;

-- Pour l'analyse critique : paires fréquentes dont le lift reste proche de 1
SELECT pa.libelle AS a, pc.libelle AS b, r.nb_paniers_xy,
       ROUND(r.support, 4) AS support, ROUND(r.lift, 4) AS lift
FROM regles_association r
JOIN produits pa ON pa.id_produit = r.antecedent
JOIN produits pc ON pc.id_produit = r.consequent
WHERE r.antecedent < r.consequent AND r.lift < 1.2
ORDER BY r.nb_paniers_xy DESC
LIMIT 10;
