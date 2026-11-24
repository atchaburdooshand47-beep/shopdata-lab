DROP SCHEMA IF EXISTS shopdata CASCADE;
CREATE SCHEMA shopdata;
SET search_path TO shopdata;
 
CREATE TABLE categories (
    id_categorie  SMALLINT     PRIMARY KEY,
    libelle       VARCHAR(50)  NOT NULL UNIQUE
);
 
CREATE TABLE produits (
    id_produit     INTEGER        PRIMARY KEY,
    libelle        VARCHAR(100)   NOT NULL,
    id_categorie   SMALLINT       NOT NULL REFERENCES categories(id_categorie),
    prix_unitaire  NUMERIC(10,2)  NOT NULL CHECK (prix_unitaire > 0)
);
 
CREATE TABLE clients (
    id_client         INTEGER      PRIMARY KEY,
    ville             VARCHAR(50)  NOT NULL,
    date_inscription  DATE         NOT NULL,
    tranche_age       VARCHAR(10)  NOT NULL
                      CHECK (tranche_age IN ('18-25','26-35','36-50','51+'))
);
 
CREATE TABLE commandes (
    id_commande    INTEGER      PRIMARY KEY,
    id_client      INTEGER      NOT NULL REFERENCES clients(id_client),
    date_commande  TIMESTAMP    NOT NULL,
    canal          VARCHAR(10)  NOT NULL CHECK (canal IN ('web','mobile','magasin'))
);
 
CREATE TABLE lignes_commande (
    id_commande  INTEGER   NOT NULL REFERENCES commandes(id_commande) ON DELETE CASCADE,
    id_produit   INTEGER   NOT NULL REFERENCES produits(id_produit),
    quantite     SMALLINT  NOT NULL CHECK (quantite > 0),
    PRIMARY KEY (id_commande, id_produit)
);
 
CREATE INDEX idx_commandes_client ON commandes(id_client);
CREATE INDEX idx_commandes_date   ON commandes(date_commande);
CREATE INDEX idx_lignes_produit   ON lignes_commande(id_produit);
