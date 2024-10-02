#!/usr/bin/env ruby
require 'optparse'

class Klass
  #ECHTVAR = "/xcatopt/Echtvar-v0.2.0/echtvar"
  ECHTVAR = "/xcatopt/Echtvar-v0.1.9/echtvar"
  #EVDIR = "/peta/hotel/share/PublicDatasets/Echtvar-202405-hg38"
  EVDIR = "/peta/hotel/share/PublicDatasets/Echtvar-202312-hg38"
  EV_Tommo54kjpn    = "tommo54kjpn.echtvar.zip"
  EV_ClinVar        = "clinvar.echtvar.zip"
  EV_dbSNP          = "dbsnp.echtvar.zip"
  EV_SpliceAI_SNV   = "spliceai_snv.echtvar.zip"
  # EV_SpliceAI_INDEL = "spliceai_indel.echtvar.zip"
  EV_AlphaMissense  = "alphamissense.echtvar.zip"
  EV_GNOMAD         = "gnomad4.echtvar.zip"
  TEMP = "__TEMP__"
  OUTD = "."

  attr_reader :opts

  def initialize(opts)
    @opts = opts
  end

  def run
    Dir["#{OUTD}/*.snpeff.vcf.gz"].sort.each do |vcf|
      bcfout = vcf.sub(/\.vcf\.gz$/, ".annot1.bcf")
      next if (File.exist?(bcfout) && !opts[:f])
      cmd = Array.new
      cmd << ECHTVAR
      cmd << "anno"
      cmd << "-e #{EVDIR}/#{EV_Tommo54kjpn}"
      cmd << "-e #{EVDIR}/#{EV_GNOMAD}"
      cmd << "-e #{EVDIR}/#{EV_dbSNP}"
      cmd << "-e #{EVDIR}/#{EV_ClinVar}"
      cmd << "-e #{EVDIR}/#{EV_SpliceAI_SNV}"
      #cmd << "-e #{EVDIR}/#{EV_SpliceAI_INDEL}"
      #cmd << "-e #{EVDIR}/#{EV_AlphaMissense}"
      cmd << vcf
      cmd << "#{bcfout}#{TEMP}"
      cmd << "2>&1 | tee #{bcfout}.log"
      cmd << "&&"
      cmd << "mv #{bcfout}#{TEMP} #{bcfout}"
      warn   cmd.join(" ")
      system cmd.join(" ") unless opts[:n]
    end
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hnf")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
