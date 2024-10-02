#!/usr/bin/env ruby
require 'optparse'
require "./00config.rb"

class Klass
  OUTD = "./"
  OUTSUFFIX  = GConfig::SSFilter_OutSuffix  # rare / loose
  JAR = "/xcatopt/snpEff-5.1/SnpSift.jar"
  BCFTOOLS = "/xcatopt/bcftools-1.18/bcftools"
  TEMPSUFF = "__TEMP__"
  attr_reader :opts

  def initialize(opts)
    @opts = opts
  end

  def run
    annot_max =
      Dir["#{OUTD}/**/*.annot?.vcf.gz"].map{|x|File.basename(x).split(".")[-3].sub(/^annot/,"").to_i}.max

    Dir[
      "#{OUTD}/**/*.annot#{annot_max}.#{OUTSUFFIX}.*.vcf.gz",
    ].sort.each do |vcf|
      out = vcf.sub(/\.vcf\.gz$/, ".txt")
      next if File.exist?(out) && !opts[:f]
      samples = `#{BCFTOOLS} query --list-samples #{vcf}`.chomp.split("\n")
      header_rows = `#{BCFTOOLS} view -h #{vcf}`.split("\n").map{|x|x.chomp}
      open("#{out}#{TEMPSUFF}", "w"){|fout|fout.puts("#" + samples.join("\t"))} unless opts[:n]
      cmd = Array.new
      cmd << "java -Xmx128g -jar #{JAR}"
      cmd << "extractFields"
      cmd << '-e "."'
      cmd << vcf
      cmd << '"ANN[0].GENE"'
      cmd << '"ID"'
      cmd << '"PARENTAL"' if header_rows.any?{|x|x.start_with?("##INFO=<ID=PARENTAL")}
      cmd << '"CHROM"'
      cmd << '"POS"'
      cmd << '"QUAL"'
      cmd << '"dbsnp_id"'
      cmd << '"cytoband"'
      cmd << '"REF"'
      cmd << '"ALT"'
      cmd << '"tommo54kjpn_af"'
      cmd << '"tommo54kjpn_filter"'
      cmd << '"gnomad4_af"'
      cmd << '"gnomad4_filter"'
      cmd << '"clinvar_disease_name"'
      cmd << '"clinvar_significance"'
      cmd << '"SpliceAIflag"'
      #cmd << '"SpliceAI"'
      #cmd << '"AlphaMissense"'
      #cmd << '"AlphaMissenseScore"'

      cmd << '"OMIM_MIM"'
      cmd << '"OMIM_GeneSym"'
      cmd << '"OMIM_GeneName"'
      cmd << '"OMIM_comment"'
      cmd << '"OMIM_phenotype"'

      cmd << '"ANN[0].ALLELE"'
      cmd << '"ANN[0].EFFECT"'
      cmd << '"ANN[0].IMPACT"'
      cmd << '"ANN[0].GENE"'
      cmd << '"ANN[0].FEATURE"'
      cmd << '"ANN[0].FEATUREID"'
      cmd << '"ANN[0].BIOTYPE"'
      cmd << '"ANN[0].RANK"'
      cmd << '"ANN[0].HGVS_C"'
      cmd << '"ANN[0].HGVS_P"'
      cmd << '"ANN[0].DISTANCE"'
      cmd << '"ANN[0].ERRORS"'
      samples.each do |sname|
        cmd << "\"GEN['#{sname}'].GT\""
        cmd << "\"GEN['#{sname}'].DP\""
        cmd << "\"GEN['#{sname}'].AD\""
        cmd << "\"GEN['#{sname}'].GQ\""
        cmd << "\"GEN['#{sname}'].SB\""
        cmd << "\"GEN['#{sname}'].RNC\""
        cmd << "\"GEN['#{sname}'].DENOVO\"" if vcf.include?("denovo")
        cmd << "\"GEN['#{sname}'].VA\""     if vcf.include?("denovo")
      end
      cmd << ">> #{out}#{TEMPSUFF}"
      #cmd << "2> #{out}.log"
      cmd << "&&"
      cmd << "mv #{out}#{TEMPSUFF} #{out}"
      warn   cmd.join(" ")
      system cmd.join(" ") unless opts[:n]
    end
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hnf")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
