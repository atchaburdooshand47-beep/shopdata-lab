SET search_path TO shopdata;
 
INSERT INTO categories (id_categorie, libelle) VALUES
    (1, 'Électronique'),
    (2, 'Accessoires'),
    (3, 'Maison'),
    (4, 'Alimentation'),
    (5, 'Livres'),
    (6, 'Sport');
 
INSERT INTO produits (id_produit, libelle, id_categorie, prix_unitaire) VALUES
    ( 1, 'Smartphone X1',        1, 499.00),
    ( 2, 'Coque smartphone',     2,  19.90),
    ( 3, 'Chargeur rapide',      2,  29.90),
    ( 4, 'Écouteurs sans fil',   1,  89.00),
    ( 5, 'Ordinateur portable',  1, 899.00),
    ( 6, 'Souris sans fil',      2,  24.90),
    ( 7, 'Sacoche ordinateur',   2,  39.90),
    ( 8, 'Cafetière',            3,  59.00),
    ( 9, 'Café en grains 1 kg',  4,  14.50),
    (10, 'Filtres à café',       4,   3.20),
    (11, 'Bouilloire',           3,  34.90),
    (12, 'Thé vert',             4,   6.80),
    (13, 'Roman policier',       5,   8.90),
    (14, 'Guide de voyage',      5,  22.00),
    (15, 'Livre de cuisine',     5,  25.00),
    (16, 'Tapis de yoga',        6,  29.00),
    (17, 'Gourde inox',          6,  18.00),
    (18, 'Haltères 2 x 5 kg',    6,  45.00),
    (19, 'Lampe de bureau',      3,  32.00),
    (20, 'Carnet de notes',      5,   4.50);
 
-- Chargement des données fournies par l'enseignant
-- (lancer psql depuis le dossier qui contient les fichiers CSV)
\copy shopdata.clients         FROM 'clients.csv'         WITH (FORMAT csv, HEADER true)
\copy shopdata.commandes       FROM 'commandes.csv'       WITH (FORMAT csv, HEADER true)
\copy shopdata.lignes_commande FROM 'lignes_commande.csv' WITH (FORMAT csv, HEADER true)
 
ANALYZE;
