#!/usr/bin/env ruby

#
# sudo update-java-alternatives -s java-1.11.0-openjdk-amd64
#

require 'optparse'

class Klass
  OUTD = "./" # <<<<<<<<<<<<<<<<
  OMIM_VERSION = "20240414"
  OMIM = "/peta/fserv/share/NGS/PublicDatasets/OMIM#{OMIM_VERSION}/genemap2.txt"

  BCFTOOLS = GCconfig::BCFTOOLS
  HEADERS =
    [%!##INFO=<ID=OMIM_MIM,Number=1,Type=Integer,Description="OMIM MIM ID",Version="#{OMIM_VERSION}">!,
     %!##INFO=<ID=OMIM_GeneSym,Number=1,Type=String,Description="OMIM gene symbol",Version="#{OMIM_VERSION}">!,
     %!##INFO=<ID=OMIM_GeneName,Number=1,Type=String,Description="OMIM gene name",Version="#{OMIM_VERSION}">!,
     %!##INFO=<ID=OMIM_comment,Number=1,Type=String,Description="OMIM comment",Version="#{OMIM_VERSION}">!,
     %!##INFO=<ID=OMIM_phenotype,Number=1,Type=String,Description="OMIM phenotype",Version="#{OMIM_VERSION}">!,
    ]

  TEMPSUFF = "__TEMP__"
  Genemap2 = Struct.new(:chr, :st, :ed, :cyto, :cyto2, :mim,
                       :genesyms, :genename, :hgnc, :entrez, :ensembl, :comment,
                       :pheno, :mouse) # using heading 14 colmns only
  INFO_IDX = 7
  ANN = "ANN="
  ANNGENE_IDX = 3
  attr_reader :opts, :omimgene

  def initialize(opts)
    @opts = opts
  end

  def load_omim
    @omimgene = Hash.new
    open(OMIM, "r") do |fin|
      fin.each_line do |row|
        row.chomp!
        next if row.start_with?("#")
        cols = row.split("\t", 14).map{|x| x.empty? ? "." : x}
        gmap = Genemap2.new(*cols)
        next if gmap.pheno == ""
        if gmap.hgnc == ""
          # gmap.genesyms.split(", ").each do |gsym|
          #   @omimgene[gsym] ||= Array.new
          #   @omimgene[gsym] << gmap
          # end
          next
        else
          @omimgene[gmap.hgnc] = gmap unless @omimgene.key?(gmap.hgnc)
        end
        # "SHOX"
        # [#<struct Klass::Genemap2 chr="chrX", st="624343", ed="659410", cyto="Xpter-p22.32", cyto2="Xp22.33",
        # mim="312865", genesyms="SHOX, GCFX, SS, PHOG", genename="Short stature homeobox", hgnc="SHOX", entrez="6473",
        # ensembl="ENSG00000185960", 
        # comment="pseudoautosomal; ?gene causing short stature in Turner syndrome",
        # pheno="Short stature, idiopathic familial, 300582 (3); Leri-Weill dyschondrosteosis,#
        # 127300 (3), Pseudoautosomal dominant; Langer mesomelic dysplasia, 249700 (3),
        # Pseudoautosomal recessive", mouse="">,
      end
    end
  end

  def valid_value(str)
    str.gsub(/, /, "|").gsub(/; /, "|")
  end

  def valid_sentence(str)
    str.gsub(/; /, "|").gsub(/, /,"__").gsub(/ /, "_").gsub(/;/, "::")
  end

  def run
    load_omim

    Dir["#{OUTD}/**/*.annot2.vcf.gz"].sort.each do |vcf|
      out  = vcf.sub(/\.annot2\.vcf\.gz$/, ".annot3#{TEMPSUFF}.vcf.gz")
      out2 = vcf.sub(/\.annot2\.vcf\.gz$/, ".annot3.vcf.gz")

      if File.exist?(out) && !opts[:f]
        warn "SKIP processing #{File.basename(vcf)} and skip generating #{File.basename(out2)}"
        next
      else
        warn "Processing #{File.basename(vcf)} to generate #{File.basename(out2)}"
      end

      IO.popen("#{BCFTOOLS} view #{vcf}", "r") do |fin|
        IO.popen("#{BCFTOOLS} view -Oz -o #{out} -", "w") do |fout|
          fin.each_line do |row|
            if row.start_with? "##"
              fout.puts row
              next
            end
            if row.start_with? "#CHROM"
              fout.puts HEADERS.join("\n")
              fout.puts row
              next
            end
            cols = row.chomp.split("\t")
            info = cols[INFO_IDX].split(";")
            ann  = info.find{|x|x.start_with?(ANN)}
            unless ann
              fout.puts row
              next
            end
            genesym = ann.sub(/#{ANN}/,'').split("|")[ANNGENE_IDX]
            if omimgene.key?(genesym)
              info << "OMIM_MIM=#{valid_value(omimgene[genesym].mim)}"
              info << "OMIM_GeneSym=#{valid_value(omimgene[genesym].genesyms)}"
              info << "OMIM_GeneName=#{valid_sentence(omimgene[genesym].genename)}"
              info << "OMIM_comment=#{valid_sentence(omimgene[genesym].comment)}"
              info << "OMIM_phenotype=#{valid_sentence(omimgene[genesym].pheno)}"
            end
            cols[INFO_IDX] = info.join(";")
            fout.puts cols.join("\t")
          end
        end # IO.popen:fout
      end # IO.popen:fin
      system("mv #{out} #{out2}")
    end
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hnf")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
