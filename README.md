# ShopData – Data Mining and Big Data Lab (M2 S3)

Pipeline PostgreSQL → HDFS → MapReduce (Java) → PostgreSQL to discover
association rules between products and segment customers with RFM.

## Environment

| Tool | Version |
| --- | --- |
| OS | Ubuntu 24.04 (native, dual boot) |
| Java | OpenJDK 17.0.20 |
| Hadoop | 3.5.0, pseudo-distributed (single node) |
| Maven | 3.8.7 |
| PostgreSQL | 16.15 (database `shopdata_db`, schema `shopdata`) |

**Deviations from the lab handout**

- Java 17 instead of 8/11: Hadoop 3.5.0 is compiled for Java 17
  (`UnsupportedClassVersionError: class file version 61.0` on Java 11).
- `pom.xml`: `hadoop.version` set to `3.5.0`, compiler source/target set to `17`.
- `PairesProduits` accepts an extra option `-D use.combiner=false` to rerun
  the job without the combiner (Job 2, task 4).

## Repository layout

```
.
├── README.md
├── sql/
│   ├── 01_schema.sql        schema + 5 tables (provided)
│   ├── 02_load.sql          data loading (provided)
│   ├── 03_exploration.sql   Part 2: Q1–Q6
│   ├── 04_export.sql        Part 3: export lignes.csv and paniers.tsv
│   ├── 05_regles.sql        Part 5: import, cross-check, association rules
│   └── 06_rfm.sql           Part 6: RFM segmentation
├── shopdata-mr/
│   ├── pom.xml
│   └── src/main/java/fr/master2/bigdata/
│       ├── CaParCategorie.java   Job 1: revenue by category
│       └── PairesProduits.java   Job 2: products and product pairs
└── screenshots/             outputs (hdfs dfs -ls, counters, queries)
```

Data files (`clients.csv`, `commandes.csv`, `lignes_commande.csv`) are provided
by the instructor and are not versioned.

## How to run

### 1. PostgreSQL: schema, load, exploration

```bash
createdb shopdata_db
cd <folder containing the CSV files>
psql -d shopdata_db -v ON_ERROR_STOP=1 -f sql/01_schema.sql
psql -d shopdata_db -v ON_ERROR_STOP=1 -f sql/02_load.sql
psql -d shopdata_db -f sql/03_exploration.sql
```

### 2. Export and ingestion into HDFS

```bash
cd ~/shopdata
psql -d shopdata_db -f sql/04_export.sql          # writes lignes.csv and paniers.tsv

start-dfs.sh && start-yarn.sh && jps
hdfs dfs -mkdir -p /user/$USER/shopdata/input/lignes /user/$USER/shopdata/input/paniers
hdfs dfs -put lignes.csv  /user/$USER/shopdata/input/lignes/
hdfs dfs -put paniers.tsv /user/$USER/shopdata/input/paniers/
hdfs dfs -ls -R /user/$USER/shopdata
hdfs fsck /user/$USER/shopdata/input -files -blocks
```

### 3. MapReduce jobs

```bash
cd shopdata-mr
mvn clean package

# Job 1: revenue by category (output in cents)
hadoop jar target/shopdata-mr-1.0.jar fr.master2.bigdata.CaParCategorie \
  /user/$USER/shopdata/input/lignes /user/$USER/shopdata/output/ca_categorie
hdfs dfs -cat /user/$USER/shopdata/output/ca_categorie/part-r-*

# Job 2: products and pairs, threshold 100 baskets
hadoop jar target/shopdata-mr-1.0.jar fr.master2.bigdata.PairesProduits \
  -D minsup.count=100 \
  /user/$USER/shopdata/input/paniers /user/$USER/shopdata/output/paires

# Job 2 without combiner (comparison)
hadoop jar target/shopdata-mr-1.0.jar fr.master2.bigdata.PairesProduits \
  -D minsup.count=100 -D use.combiner=false \
  /user/$USER/shopdata/input/paniers /user/$USER/shopdata/output/paires_sans_combiner

# Download Job 2 results
cd ~/shopdata
hdfs dfs -getmerge /user/$USER/shopdata/output/paires paires_resultats.tsv
```

`-D` options must come before the input/output paths (read by ToolRunner).
An output directory must not exist: remove it with `hdfs dfs -rm -r <dir>` to rerun.

### 4. Association rules and RFM

```bash
cd ~/shopdata
psql -d shopdata_db -f sql/05_regles.sql
psql -d shopdata_db -f sql/06_rfm.sql
```

## Key results

| Check | Result |
| --- | --- |
| Volumes | 6 categories, 20 products, 2,000 customers, 20,000 orders, 54,883 lines |
| HDFS | `lignes.csv` 1,280,976 B, `paniers.tsv` 247,035 B, 1 block each (128 MB) → 1 mapper |
| Job 1 vs SQL Q2 | 6 categories identical to the cent (total €9,218,529.10) |
| Job 2 output | 210 keys = 20 products + 190 pairs (threshold 100 filters nothing) |
| Job 2 map output | 120,717 records = Σ n + n(n−1)/2 (verified in SQL) |
| Combiner effect | shuffle 2,706 B vs 1,430,923 B without combiner; outputs identical (`diff`) |
| Pairs cross-check | 0 differences between MapReduce and SQL self-join |
| Rules | 380 rules; 14 with confidence ≥ 0.30 and lift > 1.5 (top: Smartphone X1 → Coque, lift 3.53) |
| RFM | Champions 13% of customers / 21% of revenue; À risque 23% of revenue |
| Timing (pairs) | SQL self-join 0.195 s vs MapReduce ≈ 26 s |
