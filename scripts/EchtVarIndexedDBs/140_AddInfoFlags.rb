#!/usr/bin/env ruby
require 'optparse'

class Klass
  OUTD = "./"
  BCFTOOLS = GCconfig::BCFTOOLS
  TEMPSUFF = "__TEMP__"

  SAI  = "SpliceAI"
  SAIF = "SpliceAIflag"
  HEADER_INFO = '##INFO=<ID=SpliceAIflag,Number=1,Type=String,Description="SpliceAI flag. If any of DS is => 0.2, => 0.5 or >= 0.8, then the value will be set green, yellow, or red, respectively">'
  VCF_INFO_IDX = 7

  SAIELE = Struct.new(:allele, :symbol, :ds_ag, :ds_al, :ds_dg, :ds_dl, :dp_ag, :dp_al, :dp_dg, :dp_dl)
  attr_reader :opts

  def initialize(opts)
    @opts = opts
  end

  def infoval(cols, infoid)
    cols[VCF_INFO_IDX].split(";").find{|x|x.start_with?("#{infoid}=")}.split("=")[1]
  end

  def run
    Dir["#{OUTD}/**/*.annot1.bcf"].sort.each do |vcf|
      out  = vcf.sub(/\.annot1\.bcf$/, ".annot2#{TEMPSUFF}.vcf.gz")
      out2 = vcf.sub(/\.annot1\.bcf$/, ".annot2.vcf.gz")

      if File.exist?(out) && !opts[:f]
        warn "SKIP processing #{File.basename(vcf)} to generate #{File.basename(out)}"
        next
      else
        warn "Processing #{File.basename(vcf)} to generate #{File.basename(out)}"
      end
      IO.popen("#{BCFTOOLS} view #{vcf}", "r") do |fin|
        IO.popen("#{BCFTOOLS} view -Oz -o #{out} -", "w") do |fout|
          fin.each_line do |row|
            if row.start_with? "#CHROM"
              fout.puts HEADER_INFO
              fout.puts row
              next
            end
            if row.start_with? "##"
              fout.puts row
              next
            end
            cols = row.chomp.split("\t")

            sai = cols[VCF_INFO_IDX].split(";").find{|x|x.start_with?("SpAI")}
            if sai.nil?
              fout.puts row
              next
            end

            ##INFO=<ID=SpAI_ALLELE,Number=1,Type=String
            ##INFO=<ID=SpAI_SYMBOL,Number=1,Type=String
            ##INFO=<ID=SpAI_DS_AG,Number=1,Type=Float
            ##INFO=<ID=SpAI_DS_AL,Number=1,Type=Float
            ##INFO=<ID=SpAI_DS_DG,Number=1,Type=Float
            ##INFO=<ID=SpAI_DS_DL,Number=1,Type=Float
            ##INFO=<ID=SpAI_DP_AG,Number=1,Type=Integer
            ##INFO=<ID=SpAI_DP_AL,Number=1,Type=Integer
            ##INFO=<ID=SpAI_DP_DG,Number=1,Type=Integer
            ##INFO=<ID=SpAI_DP_DL,Number=1,Type=Integer
            dss = Array.new
            dss << Float(infoval(cols, "SpAI_DS_AG"))
            dss << Float(infoval(cols, "SpAI_DS_AL"))
            dss << Float(infoval(cols, "SpAI_DS_DG"))
            dss << Float(infoval(cols, "SpAI_DS_DL"))
            saimax = dss.max
            case
            when saimax >= 0.8
              saiflag = "red"
            when saimax >= 0.5
              saiflag = "yellow"
            when saimax >= 0.2
              saiflag = "green"
            else
              fout.puts row
              next
            end
            cols[VCF_INFO_IDX] += ";#{SAIF}=#{saiflag}"
            fout.puts cols.join("\t")
          end
        end
      end
      system("mv #{out} #{out2}")
    end
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hf")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
