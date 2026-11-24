package fr.master2.bigdata;

import java.io.IOException;
import java.math.BigDecimal;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.Path;
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
 * Job 1 : chiffre d'affaires par catégorie.
 * Entrée : lignes.csv (id_commande, categorie, quantite, prix_unitaire)
 * Sortie : categorie \t CA en CENTIMES (entier exact)
 */
public class CaParCategorie extends Configured implements Tool {

    public static final String COUNTER_GROUP = "CaParCategorie";

    public static class LineMapper extends Mapper<LongWritable, Text, Text, LongWritable> {

        private final Text categorie = new Text();
        private final LongWritable montantCentimes = new LongWritable();

        @Override
        protected void map(LongWritable offset, Text line, Context context)
                throws IOException, InterruptedException {

            String s = line.toString().trim();

            // TODO 1 : ignorer la ligne d'en-tête
            if (s.startsWith("id_commande")) {
                return;
            }

            // TODO 2 : découper la ligne et vérifier le nombre de champs
            String[] f = s.split(",");
            if (f.length != 4) {
                // TODO 5 : compter les lignes invalides
                context.getCounter(COUNTER_GROUP, "LIGNES_INVALIDES").increment(1);
                return;
            }

            try {
                // TODO 3 : montant exact = quantite x prix, en centimes (long)
                int quantite = Integer.parseInt(f[2].trim());
                BigDecimal prix = new BigDecimal(f[3].trim());
                long centimes = prix.multiply(BigDecimal.valueOf(quantite))
                                    .movePointRight(2)
                                    .longValueExact();

                // TODO 4 : émettre (categorie, montant)
                categorie.set(f[1].trim());
                montantCentimes.set(centimes);
                context.write(categorie, montantCentimes);
                context.getCounter(COUNTER_GROUP, "LIGNES_VALIDES").increment(1);

            } catch (NumberFormatException | ArithmeticException e) {
                // TODO 5 : nombre illisible -> ligne invalide
                context.getCounter(COUNTER_GROUP, "LIGNES_INVALIDES").increment(1);
            }
        }
    }

    public static class SumReducer extends Reducer<Text, LongWritable, Text, LongWritable> {

        private final LongWritable total = new LongWritable();

        @Override
        protected void reduce(Text cle, Iterable<LongWritable> values, Context context)
                throws IOException, InterruptedException {
            // TODO 6 : additionner les valeurs et émettre (cle, total)
            long somme = 0;
            for (LongWritable v : values) {
                somme += v.get();
            }
            total.set(somme);
            context.write(cle, total);
        }
    }

    @Override
    public int run(String[] args) throws Exception {
        if (args.length != 2) {
            System.err.println("Usage: CaParCategorie <input> <output>");
            return 2;
        }
        Job job = Job.getInstance(getConf(), "CA par categorie");
        job.setJarByClass(CaParCategorie.class);

        // TODO 7 : mapper, combiner, reducer et types de sortie
        job.setMapperClass(LineMapper.class);
        job.setCombinerClass(SumReducer.class);
        job.setReducerClass(SumReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(LongWritable.class);

        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        return job.waitForCompletion(true) ? 0 : 1;
    }

    public static void main(String[] args) throws Exception {
        System.exit(ToolRunner.run(new Configuration(), new CaParCategorie(), args));
    }
}