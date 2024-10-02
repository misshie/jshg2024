#!/usr/bin/env ruby
require 'optparse'
require "./00config.rb"
require "./lib/read-pedigree-file.rb"
class Klass
  OUTD = "./"
  MAX_MAF = GConfig::SSFilter_MaxMAF
  OUTSUFFIX  = GConfig::SSFilter_OutSuffix  # rare / loose
  OUTSUFFIX2 = GConfig::SSFilter_OutSuffix2 # condC
  BCFTOOLS = "/xcatopt/bcftools-1.19/bcftools"
  OPLINE ="/xcatopt/snpEff-5.1/scripts/vcfEffOnePerLine.pl"
  TEMPSUFF = "__TEMP__"
  HEAD_PARENTAL_DESC = "parental transmission of child's alleles (PAT/MAT, hom/het, question)"
  HEAD_PARENTAL = %!##INFO=<ID=PARENTAL,Number=1,Type=String,Description="#{HEAD_PARENTAL_DESC}">!
  INFOIX = 7
  SMPIX  = 9

  attr_reader :opts, :annot_max, :cfm

  def initialize(opts)
    @opts = opts
    @annot_max =
      Dir["#{OUTD}/**/*.annot?.vcf.gz"].map{|x|File.basename(x).split(".")[-3].sub(/^annot/,"").to_i}.max
    @cfm = ReadPedigreeFile.cfm_indices
  end

  def transmission_type(rowcols)
    cfmgt = rowcols.values_at(SMPIX+cfm[0], SMPIX+cfm[1], SMPIX+cfm[2]).map{|x|x.split(":")[0]}
    case cfmgt
    when ["0/1", "0/1", "0/0"] then "PAThet"
    when ["0/1", "1/1", "0/0"] then "PAThom"
    when ["0/1", "0/0", "0/1"] then "MAThet"
    when ["0/1", "0/0", "1/1"] then "MAThom"
      #
    when ["0/1", "./.", "0/0"] then "PAT?"
    when ["0/1", "./.", "0/1"] then "MAThet?"
    when ["0/1", "./.", "1/1"] then "MAThom?"
      #
    when ["0/1", "0/1", "./."] then "PAThet?"
    when ["0/1", "1/1", "./."] then "PAThom?"
    when ["0/1", "0/0", "./."] then "MAT?"
      #
    else
      "."
    end
  end

  def invoke_bcftools(vcf, out, expr)
    cmd = Array.new
    cmd << BCFTOOLS
    cmd << "view"
    cmd << "-Ov"
    cmd << "--include"
    cmd << "'"
    cmd << expr.join(" ")
    cmd << "'"
    cmd << vcf
    return if (File.exist?(out) && !(opts[:f]))
    IO.popen(cmd.join(" "), "r") do |fin|
      IO.popen("#{BCFTOOLS} view -Oz -o #{out}#{TEMPSUFF} -", "w") do |fout|
        fin.each_line do |row|
          if row.start_with?("##")
            fout.puts row
            next
          end
          if row.start_with?("#")
            fout.puts HEAD_PARENTAL
            fout.puts row
            next
          end
          cols = row.chomp.split("\t")
          trans = transmission_type(cols)
          cols[INFOIX] = "PARENTAL=#{trans};" + cols[INFOIX]
          fout.puts cols.join("\t")
        end
      end
    end
    system("mv #{out}#{TEMPSUFF} #{out}")
  end

  def model_a01_simple_denovo(vcf)
    warn "model_a01_simple_denovo (#{File.basename(vcf)})"
    if cfm.any?{|x|x.nil?}
      warn "Not a trio family."
      return false
    end
    out = vcf.sub(/\.vcf\.gz$/, ".A01_DeNovo.vcf.gz")
    expr = Array.new
    expr << "("
    expr << "((GT[#{cfm[0]}]!=\"mis\") && (GT[#{cfm[0]}]!=\"0/0\"))"
    expr << "&&"
    expr << "((GT[#{cfm[1]}]==\"mis\") || (GT[#{cfm[1]}]==\"0/0\"))"
    expr << "&&"
    expr << "((GT[#{cfm[2]}]==\"mis\") || (GT[#{cfm[2]}]==\"0/0\"))"
    expr << ")"
    invoke_bcftools(vcf, out, expr)
  end

  def model_a02_hom_tight(vcf)
    warn "model_a02_hom_tight (#{File.basename(vcf)})"
    if cfm.any?{|x|x.nil?}
      warn "Not a trio family."
      return false
    end
    out = vcf.sub(/\.vcf\.gz$/, ".A02_Homozygous.vcf.gz")
    expr = Array.new
    expr << "(GT[#{cfm[0]}]==\"AA\")"
    invoke_bcftools(vcf, out, expr)
  end

  def model_a03_comp_het_loose(vcf)
    warn "model_a03_comp_het_loose (#{File.basename(vcf)})"
    if cfm.any?{|x|x.nil?}
      warn "Not a trio family."
      return false
    end
    out = vcf.sub(/\.vcf\.gz$/, ".A03_CompoundHeterozygous.vcf.gz")
    expr = Array.new
    expr << "("
    expr << "(GT[#{cfm[0]}]==\"RA\")"
    expr << "||"
    expr << " ("
    expr << "  (GT[#{cfm[0]}]==\"AA\")"
    expr << "  &&"
    expr << "  ((GT[#{cfm[1]}]==\"RR\") || (GT[#{cfm[1]}]!=\"RA\"))"
    expr << "  &&"
    expr << "  ((GT[#{cfm[2]}]==\"RR\") || (GT[#{cfm[2]}]!=\"RA\"))"
    expr << " )"
    expr << ")"
    invoke_bcftools(vcf, out, expr)
  end

  def model_a04_parental_transmitted(vcf)
    warn "model_a04_parental_transmitted (#{File.basename(vcf)})"
    if cfm.any?{|x|x.nil?}
      warn "Not a trio family."
      return false
    end
    out = vcf.sub(/\.vcf\.gz$/, ".A04_ParentalTransmitted.vcf.gz")
    header = `#{BCFTOOLS} head #{vcf}`.split("\n").map{|x|x.chomp}
    header.insert(-2, HEAD_PARENTAL)
    IO.popen(%!#{BCFTOOLS} view -Oz -o#{out} -!, "w") do |fout|
      header.each{|s|fout.puts s}
      `#{BCFTOOLS} view -H #{vcf}`.split("\n").each do |row|
        cols = row.chomp.split("\t")
        trans = transmission_type(cols)
        cols[INFOIX] = "PARENTAL=#{trans};" + cols[INFOIX]
        fout.puts cols.join("\t")
      end
    end
  end

  def run
    Dir[
      "#{OUTD}/**/*.annot#{annot_max}.#{OUTSUFFIX}.vcf.gz",
      "#{OUTD}/**/*.annot#{annot_max}.#{OUTSUFFIX}-#{OUTSUFFIX2}.vcf.gz",
    ].sort.each do |vcf|
      model_a01_simple_denovo(vcf)
      model_a02_hom_tight(vcf)
      model_a03_comp_het_loose(vcf)
      model_a04_parental_transmitted(vcf)
    end
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hnf")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
