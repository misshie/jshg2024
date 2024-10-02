#!/usr/bin/env ruby
require 'optparse'
require "./00config.rb"

class Klass
  PROJ   = GConfig::FamName
  BCFIN  = "#{PROJ}.norm.bcf"
  VCFOUT = "#{PROJ}.norm.snpeff.vcf.gz"
  LOG    = "#{PROJ}.norm.snpeff.vcf.log"
  SNPEFF_SUMMARY = "#{PROJ}.norm.snpeff.vcf.snpEff_summary.html"

  SNPEFF   = "/xcatopt/snpEff-5.1/snpEff.jar"
  DATABASE = "hg38decoy.gencode39"
  JAVAOPT  = "-Xmx32g"
  BCFTOOLS = "/xcatopt/bcftools-1.19/bcftools"
  THREADS  = 32

  attr_reader :opts

  def initialize(opts)
    @opts = opts
  end

  def run
    cmd = Array.new
    cmd << BCFTOOLS
    cmd << "view"
    cmd << "--threads #{THREADS}"
    cmd << "-Ov"
    cmd << BCFIN
    cmd << "|"
    cmd << "java"
    cmd << JAVAOPT
    cmd << "-jar #{SNPEFF}"
    cmd << "ann"
    cmd << "-stats #{SNPEFF_SUMMARY}"
    cmd << "-v #{DATABASE}"
    cmd << "2> #{LOG}"
    cmd << "|"
    cmd << BCFTOOLS
    cmd << "view"
    cmd << "--threads #{THREADS}"
    cmd << "-Oz -o #{VCFOUT}"
    cmd << "&&"
    cmd << BCFTOOLS
    cmd << "index"
    cmd << VCFOUT
    warn   cmd.join(" ")
    system cmd.join(" ") unless opts[:n]
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hn")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end


