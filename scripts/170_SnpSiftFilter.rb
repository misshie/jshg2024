#!/usr/bin/env ruby
require 'optparse'
require "./00config.rb"

class Klass
  OUTD = "./"
  MAX_MAF = GConfig::SSFilter_MaxMAF
  OUTSUFFIX  = GConfig::SSFilter_OutSuffix  # rare / loose
  OUTSUFFIX2 = GConfig::SSFilter_OutSuffix2 # "condB"
  JAR = "/xcatopt/snpEff-5.1/SnpSift.jar"
  # prepare: sudo update-java-alternatives -s java-1.11.0-openjdk-amd64
  BCFTOOLS = "/xcatopt/bcftools-1.19/bcftools"
  OPLINE ="/xcatopt/snpEff-5.1/scripts/vcfEffOnePerLine.pl"
  TEMPSUFF = "__TEMP__"

  attr_reader :opts

  def initialize(opts)
    @opts = opts
  end

  def run
    annot_max =
      Dir["#{OUTD}/**/*.annot?.vcf.gz"].map{|x|File.basename(x).split(".")[-3].sub(/^annot/,"").to_i}.max

    Dir["#{OUTD}/**/*.annot#{annot_max}.vcf.gz"].sort.each do |vcf|
      out = vcf.sub(/\.vcf\.gz$/, ".#{OUTSUFFIX}-#{OUTSUFFIX2}.vcf.gz")
      next if (File.exist?(out) && !(opts[:f]))
      cmd = Array.new
      cmd << "#{BCFTOOLS} view #{vcf}"
      cmd << "|"
      cmd << "#{OPLINE}"
      cmd << "|"
      cmd << "java -Xmx256g -jar #{JAR}"
      cmd << "filter"
      cmd << '"'
      cmd << "("
      cmd << "  ((tommo54kjpn_af < #{MAX_MAF}) | !(exists tommo54kjpn_af)) &"
      cmd << "  ((gnomad4_af     < #{MAX_MAF}) | !(exists gnomad4_af))"
      cmd << ")"
      cmd << "&"
      cmd << "("
      cmd << "  ((ANN[*].IMPACT = 'HIGH') | (ANN[*].IMPACT = 'MODERATE'))"
      cmd << "  |"
      cmd << "  ((SpliceAIflag = 'red') | (SpliceAIflag = 'yellow'))"
      cmd << ")"
      cmd << '"'
      cmd << "|"
      cmd << BCFTOOLS
      cmd << "view"
      cmd << "-Oz -o #{out}#{TEMPSUFF}"
      cmd << "&&"
      cmd << "mv #{out}#{TEMPSUFF} #{out}"
      warn    cmd.join(" ")
      system  cmd.join(" ") unless opts[:n]
    end
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hnf")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
