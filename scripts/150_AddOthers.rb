#!/usr/bin/env ruby
require 'optparse'

class Klass
  OUTD = "./"
  BCFTOOLS = GCconfig::BCFTOOLS
  TEMPSUFF = "__TEMP__"

  BED_CYTOBAND = "/peta/fserv/share/PublicDatasets/UCSC_hg38/cytoBand-canonical.bed.gz"
  HEADER_CYTOBAND = "/peta/fserv/share/PublicDatasets/UCSC_hg38/cytoBand-canonical.header.txt"
  # ##INFO=<ID=Cytoband,Number=1,Type=String,Description="Cytoband">

  attr_reader :opts

  def initialize(opts)
    @opts = opts
  end

  def cytoband(vcfin: nil, vcfout: nil)
    tempout  = vcfout.sub(/.vcf\.gz$/, "#{TEMPSUFF}.vcf.gz")
    cmd = Array.new
    cmd << BCFTOOLS
    cmd << "annotate"
    cmd << "--annotations #{BED_CYTOBAND}"
    cmd << "--header-lines #{HEADER_CYTOBAND}"
    cmd << "--columns CHROM,BEG,END,cytoband"
    cmd << "-Oz -o #{tempout}"
    cmd << vcfin
    cmd << "&&"
    cmd << "mv #{tempout} #{vcfout}"
    warn   cmd.join(" ")
    system cmd.join(" ")
  end

  def run
    Dir["#{OUTD}/**/*.annot3.vcf.gz"].sort.each do |vcf|
      out = vcf.sub(/\.annot3\.vcf\.gz$/, ".annot4.vcf.gz")
      if File.exist?(out) && !opts[:f]
        warn "SKIP processing #{File.basename(vcf)} to generate #{File.basename(out)}"
        next
      else
        warn "Processing #{File.basename(vcf)} to generate #{File.basename(out)}"
      end
      cytoband(vcfin:vcf, vcfout:out)
    end
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hf")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
