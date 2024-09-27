#!/usr/bin/env ruby
require 'optparse'
require 'fileutils'

class Klass
  FASTQD = "Fastqd"
  RESULTS = "Parabricks"
  REF    = "/staging/share/Genomes/human_hg38_GRCh38/hg38.canonical-EBV-JRGv2.fasta"
  KNOWN_INDELS =
    "GATKbundle/v2.8/hg38/resources_broad_hg38_v0_Mills_and_1000G_gold_standard.indels.hg38.vcf"
  TEMPDIR  = "/staging/tmp"
  PLATFORM = "ILLUMINA"
  NUM_GPUS = 4
  PARABRICKS = "nvcr.io/nvidia/clara/clara-parabricks:4.3.0-1"

  attr_reader :opts

  def initialize(opts)
    @opts = opts
  end

  def run
    FileUtils.mkdir_p RESULTS

    Dir.chdir(RESULTS) do
      samplehash = Hash.new
      Dir["#{FASTQD}/*.fastq.gz"].each do |fqgz|
        ## file naming scheme: aaaa_bbbb_24_0001_L001_R1.fastq.gz (multiple lane may used!)
        sname = File.basename(fqgz).split("_")[0..-3].join("_")
        samplehash[sname] ||= Array.new
        samplehash[sname] << fqgz
      end

      samplehash.each do |sname, paths|
        FileUtils.mkdir_p(sname)
        Dir.chdir(sname) do
          cmd = Array.new
          cmd << "/usr/bin/time --verbose --append -o #{RESULTS}/#{sname}/#{sname}.time.log"
          cmd << "/usr/bin/bash -c"
          cmd << "'"
          cmd << "sudo docker run --rm --gpus all"
          cmd << "--volume #{File.dirname(paths[0])}:/inputdir"
          cmd << "--volume #{Dir.pwd}:/outputdir"
          cmd << "--volume #{File.dirname(REF)}:/refdir"
          cmd << "--volume #{File.dirname(KNOWN_INDELS)}:/knowndir"
          cmd << "--volume #{TEMPDIR}:/tempdir"
          cmd << "-w /outdir"
          cmd << PARABRICKS
          cmd << "pbrun germline"
          cmd << "--ref           /refdir/#{File.basename(REF)}"
          cmd << "--knownSites    /knowndir/#{File.basename(KNOWN_INDELS)}"
          cmd << "--gvcf"
          cmd << "--out-variants          /outputdir/#{sname}.hg38.g.vcf.gz"
          cmd << "--out-bam               /outputdir/#{sname}.hg38.sort.dedup.bam"
          cmd << "--out-recal-file        /outputdir/#{sname}.hg38.recal.txt"
          cmd << "--out-duplicate-metrics /outputdir/#{sname}.hg38.duplicate-metrics.txt"
          cmd << "--logfile               /outputdir/#{sname}.hg38.germline.log"
          cmd << "--tmp-dir /tempdir"
          cmd << "--num-gpus #{NUM_GPUS}"
          cmd << "--gpuwrite"
          cmd << "--gpusort"
          cmd << "--num-cpu-threads-per-stage 16"
          cmd << "--read-group-sm #{sname}"
          cmd << "--read-group-lb #{sname}"
          cmd << "--read-group-pl #{PLATFORM}"
          cmd << "--read-group-id-prefix #{sname}"
          paths.each_slice(2) do |pairs|
            cmd << "--in-fq /inputdir/#{File.basename(pairs[0])} /inputdir/#{File.basename(pairs[1])}"
          end
          cmd << "'"
          warn "--------------"
          if File.exist?("#{sname}.hg38.g.vcf.gz")
            warn("#{sname}.g.vcf.gz already exits to be skipped...")
            next
          end
          warn   cmd.join("\n")
          system cmd.join(" ") unless opts[:n]
          sleep 1 if opts[:n]
        end
      end
    end
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hn")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
