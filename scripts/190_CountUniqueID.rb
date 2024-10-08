#!/usr/bin/env ruby

require 'optparse'
require "./00config.rb"

class Klass
  OUTD = "./" # <<<<<<<
  TARGET_SUFFIX = GConfig::SSFilter_OutSuffix  # rare / loose

  INSERT_BEFORE_INDEX = 2 # gene - unuque - ID
  TEMP_SUFFIX = "__TEMP__"

  attr_reader :opts, :tabheader, :tab

  def initialize(opts)
    @opts = opts
  end

  def load_table(fin)
    @tabheader = nil
    @tab = Hash.new
    fin.each_line.with_index do |row, nrow|
      cols = row.chomp.split("\t")
      if nrow.zero?
        @tabheader = row.chomp.split("\t").insert(INSERT_BEFORE_INDEX, "unique").join("\t")
        next
      end
      gene = cols[0]
      id   = cols[1]
      @tab[gene] ||= Hash.new
      @tab[gene][id] ||= Array.new
      @tab[gene][id] << cols
    end
  end

  def output(fout)
    fout.puts tabheader
    tab.each do |gene, ids|
      unique = ids.size
      ids.each do |id, rows|
        rows.each do |cols|
          fout.puts cols.dup.insert(INSERT_BEFORE_INDEX, unique).join("\t")
        end
      end
    end
  end

  def run
    annot_max =
      Dir["#{OUTD}/**/*.annot?.vcf.gz"].map{|x|File.basename(x).split(".")[-3].sub(/^annot/,"").to_i}.max

    Dir[
      "#{OUTD}/*.snpeff.annot#{annot_max}.#{TARGET_SUFFIX}.txt",
    ].sort.each do |inp|
      next if inp.include?(".raw.")
      next if inp.include?(".uniq.")
      out  = inp.sub(/\.txt$/, ".uniq.txt#{TEMP_SUFFIX}")
      out2 = inp.sub(/\.txt$/, ".uniq.txt")
      if File.exist?(out) && !opts[:f]
        warn "skip #{File.basename(out)}...."
        next
      end
      warn "processing #{File.basename(out2)}...."
      next if opts[:n]
      next if (File.exist?(out2) && !(opts[:f]))
      open(inp, "r") do |fin|
        open(out, "w") do |fout|
          load_table(fin)
          output(fout)
        end
      end
      system("mv #{out} #{out2}")
    end
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hnf")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
