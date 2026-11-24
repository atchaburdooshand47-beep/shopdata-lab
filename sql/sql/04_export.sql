-- Partie 3 : export des fichiers pour HDFS
-- (chaque \copy doit tenir sur une seule ligne)

-- lignes.csv : id_commande, catégorie, quantité, prix unitaire (CSV avec en-tête)
\copy (SELECT l.id_commande, c.libelle AS categorie, l.quantite, p.prix_unitaire FROM shopdata.lignes_commande l JOIN shopdata.produits p ON p.id_produit = l.id_produit JOIN shopdata.categories c ON c.id_categorie = p.id_categorie ORDER BY l.id_commande, l.id_produit) TO 'lignes.csv' WITH (FORMAT csv, HEADER true)

-- paniers.tsv : id_commande <TAB> produits triés séparés par des virgules
\copy (SELECT id_commande, string_agg(id_produit::text, ',' ORDER BY id_produit) FROM shopdata.lignes_commande GROUP BY id_commande ORDER BY id_commande) TO 'paniers.tsv' WITH (FORMAT text)
