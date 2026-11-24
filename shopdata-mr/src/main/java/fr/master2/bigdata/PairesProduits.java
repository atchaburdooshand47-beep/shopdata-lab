package fr.master2.bigdata;

import java.io.IOException;
import java.util.Arrays;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;

/**
 * Job 2 : comptage des produits et des paires de produits (approche "pairs").
 * Entrée : paniers.tsv (id_commande \t id1,id2,id3)
 * Sortie : I:p \t nb   (nombre de paniers contenant le produit p)
 *          P:a,b \t nb (nombre de paniers contenant la paire, avec a < b)
 * Paramètres : -D minsup.count=N   (seuil de support absolu, 1 par défaut)
 *              -D use.combiner=false (pour relancer sans combiner)
 */
public class PairesProduits extends Configured implements Tool {

    public static final String MINSUP = "minsup.count";
    public static final String USE_COMBINER = "use.combiner";
    public static final String COUNTER_GROUP = "PairesProduits";

    public static class BasketMapper extends Mapper<LongWritable, Text, Text, IntWritable> {

        private static final IntWritable ONE = new IntWritable(1);
        private final Text cle = new Text();

        @Override
        protected void map(LongWritable offset, Text line, Context context)
                throws IOException, InterruptedException {

            // TODO 1 : récupérer la liste des articles du panier
            String[] parts = line.toString().trim().split("\t");

            // TODO 2 : gérer les lignes invalides (compteur)
            if (parts.length != 2 || parts[1].isEmpty()) {
                context.getCounter(COUNTER_GROUP, "LIGNES_INVALIDES").increment(1);
                return;
            }

            int[] produits;
            try {
                produits = Arrays.stream(parts[1].split(","))
                                 .mapToInt(s -> Integer.parseInt(s.trim()))
                                 .sorted()
                                 .distinct()
                                 .toArray();
            } catch (NumberFormatException e) {
                context.getCounter(COUNTER_GROUP, "LIGNES_INVALIDES").increment(1);
                return;
            }
            context.getCounter(COUNTER_GROUP, "PANIERS_VALIDES").increment(1);

            // TODO 3 : émettre ("I:" + produit, 1) pour chaque produit
            for (int p : produits) {
                cle.set("I:" + p);
                context.write(cle, ONE);
            }

            // TODO 4 : émettre ("P:" + a + "," + b, 1) pour chaque paire, avec a < b
            for (int i = 0; i < produits.length; i++) {
                for (int j = i + 1; j < produits.length; j++) {
                    cle.set("P:" + produits[i] + "," + produits[j]);
                    context.write(cle, ONE);
                }
            }
        }
    }

    public static class SumCombiner extends Reducer<Text, IntWritable, Text, IntWritable> {

        private final IntWritable somme = new IntWritable();

        @Override
        protected void reduce(Text cle, Iterable<IntWritable> values, Context context)
                throws IOException, InterruptedException {
            // TODO 5 : somme partielle, SANS appliquer le seuil (voir explication)
            int s = 0;
            for (IntWritable v : values) {
                s += v.get();
            }
            somme.set(s);
            context.write(cle, somme);
        }
    }

    public static class SupportReducer extends Reducer<Text, IntWritable, Text, IntWritable> {

        private int minSup;
        private final IntWritable total = new IntWritable();

        @Override
        protected void setup(Context context) {
            // TODO 6 : lire le seuil MINSUP depuis la configuration
            minSup = context.getConfiguration().getInt(MINSUP, 1);
        }

        @Override
        protected void reduce(Text cle, Iterable<IntWritable> values, Context context)
                throws IOException, InterruptedException {
            // TODO 7 : somme finale, puis émettre seulement si le seuil est atteint
            int s = 0;
            for (IntWritable v : values) {
                s += v.get();
            }
            if (s >= minSup) {
                total.set(s);
                context.write(cle, total);
            } else {
                context.getCounter(COUNTER_GROUP, "SOUS_LE_SEUIL").increment(1);
            }
        }
    }

    @Override
    public int run(String[] args) throws Exception {
        if (args.length != 2) {
            System.err.println("Usage: PairesProduits [-D minsup.count=N] <input> <output>");
            return 2;
        }
        Job job = Job.getInstance(getConf(), "Paires de produits");
        job.setJarByClass(PairesProduits.class);

        // TODO 8 : mapper, combiner, reducer et types de sortie
        job.setMapperClass(BasketMapper.class);
        if (getConf().getBoolean(USE_COMBINER, true)) {
            job.setCombinerClass(SumCombiner.class);
        }
        job.setReducerClass(SupportReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);

        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        return job.waitForCompletion(true) ? 0 : 1;
    }

    public static void main(String[] args) throws Exception {
        System.exit(ToolRunner.run(new Configuration(), new PairesProduits(), args));
    }
}
