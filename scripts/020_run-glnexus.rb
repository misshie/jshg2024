#!/usr/bin/env ruby
require 'fileutils'
require 'optparse'

class Klass
  SAMPLE_SUFFIX = ""
  FAMILIES = {
    "NGSK_IRUD_24_9999" =>
      %w(
        NGSK_IRUD_24_9999
        NGSK_IRUD_24_9999Father
        NGSK_IRUD_24_9999Mother
      ),
  }

  GERMLINE    = "Parabricks"
  RESULTS     = "GLnexus"
  TMPDIR      = "/staging/tmp"
  TEMP_SUFFIX = "__TEMP__"
  GLNEXUS     = "/xcatopt/GLnexus-v1.4.1/glnexus_cli"
  GLNEXUSDB   = "#{TMPDIR}/GLnexus.DB"
  GLNEXUSCONFIG = "gatk"

  MEM_G = 96
  MEM   = "96G"
  CORES = 32
  ULIMIT = "ulimit -n 65536"

  attr_reader :opts

  def initialize(opts)
    @opts = opts
  end

  def remove_glnexusdb(glnexusdb)
    if File.exist?(glnexusdb)
      FileUtils.remove_entry(glnexusdb)
    end
  end

  def run
    FAMILIES.each do |family, indivs|
      FileUtils.mkdir_p "#{RESULTS}/#{family}_pbFam1"
      pp "#{RESULTS}/#{family}_pbFam1"
      Dir.chdir("#{RESULTS}/#{family}_pbFam1") do
        if File.exist?("comb.both.bcf") && !opts[:f]
          warn "comb.both.bcf is found in #{RESULTS}/#{family}_pbFam1Fam1"
          next
        end
        cmd = Array.new
        cmd << "/usr/bin/time --verbose --append -o #{family}.glnexus.time.log"
        cmd << "/usr/bin/bash -c"
        cmd << "'"
         cmd << ULIMIT
         cmd << ";"
         cmd << "LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so"
         cmd << "numactl --interleave=all"
         cmd << GLNEXUS
         cmd << "--config #{GLNEXUSCONFIG}"
         cmd << "--squeeze"
         cmd << "--dir #{GLNEXUSDB}"
         cmd << "--trim-uncalled-alleles"
         cmd << "--mem-gbytes #{MEM_G}"
         cmd << "--threads #{CORES}"
         indivs.each do |indiv|
           cmd << "#{GERMLINE}/#{indiv}/#{indiv}#{SAMPLE_SUFFIX}.hg38.g.vcf.gz"
         end
         cmd << "> comb.both.bcf#{TEMP_SUFFIX}"
        cmd << "'"

        warn   cmd.join(" ")
        sleep 3 if opts[:n]
        unless opts[:n]
          system cmd.join(" ")
          FileUtils.mv("comb.both.bcf#{TEMP_SUFFIX}", "comb.both.bcf")
          remove_glnexusdb(GLNEXUSDB) unless opts[:n]
        end
      end
    end
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hnf")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
