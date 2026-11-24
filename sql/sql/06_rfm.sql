-- Partie 6 : segmentation RFM
SET search_path TO shopdata;

DROP TABLE IF EXISTS segments_rfm;
CREATE TABLE segments_rfm AS
WITH ref AS (
    -- date de référence : lendemain de la dernière commande de la base
    SELECT (MAX(date_commande)::date + 1) AS date_ref FROM commandes
),
montants AS (
    SELECT l.id_commande, SUM(l.quantite * p.prix_unitaire) AS montant
    FROM lignes_commande l JOIN produits p ON p.id_produit = l.id_produit
    GROUP BY l.id_commande
),
rfm AS (
    SELECT co.id_client,
           (SELECT date_ref FROM ref) - MAX(co.date_commande)::date AS recence,
           COUNT(DISTINCT co.id_commande)                           AS frequence,
           COALESCE(SUM(m.montant), 0)                              AS montant
    FROM commandes co
    LEFT JOIN montants m ON m.id_commande = co.id_commande
    GROUP BY co.id_client
),
scores AS (
    SELECT rfm.*,
           NTILE(5) OVER (ORDER BY recence DESC)  AS r_score,  -- plus récent => 5
           NTILE(5) OVER (ORDER BY frequence ASC) AS f_score,  -- plus fréquent => 5
           NTILE(5) OVER (ORDER BY montant ASC)   AS m_score   -- plus dépensier => 5
    FROM rfm
)
SELECT s.*,
       CASE
         WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
         WHEN r_score >= 3 AND f_score >= 3                  THEN 'Fidèles'
         WHEN r_score <= 2 AND f_score >= 3                  THEN 'À risque'
         WHEN r_score <= 2 AND f_score <= 2                  THEN 'Perdus'
         ELSE 'À développer'
       END AS segment
FROM scores s;

ALTER TABLE segments_rfm ADD PRIMARY KEY (id_client);

-- Indicateurs par segment
SELECT segment,
       COUNT(*)                                             AS nb_clients,
       ROUND(AVG(recence), 1)                               AS recence_moy_jours,
       ROUND(AVG(frequence), 2)                             AS frequence_moy,
       ROUND(AVG(montant), 2)                               AS montant_moy,
       ROUND(100 * SUM(montant) / SUM(SUM(montant)) OVER (), 1) AS part_ca_pct
FROM segments_rfm
GROUP BY segment
ORDER BY part_ca_pct DESC;

-- Limite de NTILE : des clients ex æquo reçoivent des scores différents
SELECT frequence, COUNT(*) AS nb_clients,
       MIN(f_score) AS f_score_min, MAX(f_score) AS f_score_max
FROM segments_rfm
GROUP BY frequence
HAVING MIN(f_score) <> MAX(f_score)
ORDER BY frequence;
