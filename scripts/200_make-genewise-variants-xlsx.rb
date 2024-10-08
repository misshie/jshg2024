#!/usr/bin/env ruby

require 'optparse'
require 'caxlsx'
require 'fileutils'
require "./00config.rb"
require "./lib/read-pedigree-file.rb"

class Klass
  OUTD = "."
  EXCELD = "./Excel"
  REFNAME = "hg38"
  TARGET_SUFFIX = GConfig::SSFilter_OutSuffix  # rare/loose

  FLORAL_WHITE = "FFFAF0"
  WHITE        = "FFFFFF"
  IMPACTS       = %w(MODIFIER LOW MODERATE HIGH)

  SHEET_VARIANTS = "Variants"
  SHEET_GENEWISE = "Genewise"

  COL_QUAL      = "QUAL"

  COL_Symbol    = "ANN.GENE"
  COL_Unique    = "unique"
  COL_Chrom     = "CHROM"
  COL_Impact    = "ANN.IMPACT"
  COL_ClinVar   = "clinvar_significance"
  COL_SplicaAI  = "SpliceAIflag"
  #COL_AlphaMiss = "AlphaMissense"
  COL_GeneName  = "OMIM_GeneName"
  COL_Alias     = "OMIM_GeneSym"
  COL_MIM       = "OMIM_MIM"
  COL_Comment   = "OMIM_comment"
  COL_Phenotype = "OMIM_phenotype"
  COL_SUFFIX_GT     = ".GT"
  COL_SUFFIX_DENOVO = ".DENOVO"
  attr_reader :opts

  def initialize(opts)
    @opts = opts
  end

  def gene_recessive(loci)
    count = 0
    loci.each do |locus, rows|
      (0 .. ($num_samples - 1)).each do |sidx|
        col_gt = $col_1st_gt + sidx * $sample_cols
        count +=1 if rows[0][col_gt].start_with?("1/1")
      end
    end
    count
  end

  def gene_dominant(loci)
    count = 0
    loci.each do |locus, rows|
      (0 .. ($num_samples - 1)).each do |sidx|
        col_gt = $col_1st_gt + sidx * $sample_cols
        count +=1 if ( rows[0][col_gt].start_with?("0/1") || rows[0][col_gt].start_with?("1/0") )
      end
    end
    count
  end

  def gene_impact(loci)
    # pick-up the most impacting annotation for each locus
    impacts = Hash.new
    loci.each do |locus, rows|
      high = rows.max_by{|x|IMPACTS.index(x[$col_impact])} # a bug here was removed
      fail("the unknown impact in #{rows.inspect}") unless high
      impacts[high[$col_impact]] ||= 0
      impacts[high[$col_impact]] += 1
    end
    impacts.sort_by{|k,v|IMPACTS.reverse.index(k)}.map{|(k,v)|"#{k}=#{v}"}.join("|")
  end

  def gene_flag(loci)
    counts = Hash.new
    loci.each do |locus, rows|
      if rows[0][$col_clinvar] =~ /Pathogenic|pathogenic/
        counts[:clinvar] ||= 0
        counts[:clinvar] += 1
      end
      if rows[0][$col_spliceai] =~ /red|yellow|green/
        counts[:spliceai] ||= 0
        counts[:spliceai] += 1
      end
      # if rows[0][$col_alphamiss] =~ /Pathogenic|pathogenic/
      #   counts[:alphamiss] ||= 0
      #   counts[:alphamiss] += 1
      # end
    end
    flags = Array.new
    flags << "ClinVar=#{counts[:clinvar]}"        if counts[:clinvar]
    flags << "SpliceAI=#{counts[:spliceai]}"      if counts[:spliceai]
    #flags << "AlphaMissing=#{counts[:alphamiss]}" if counts[:aplhamiss]
    flags.join("|")
  end

  def gene_qual(loci)
    quals = Array.new
    loci.each do |locus, rows|
      quals << Float(rows[0][$col_qual]).to_i
    end
    quals.join(",")
  end

  def gene_chrom(loci)
    chroms = Array.new
    loci.each do |locus, rows|
      chroms << rows[0][$col_chrom]
    end
    chroms.uniq.join(",")
  end


  def sample_hom(sidx, loci)
    count = 0
    col_gt = $col_1st_gt + sidx * $sample_cols
    loci.each do |locus, rows|
      count +=1 if rows[0][col_gt].start_with?("1/1")
    end
    count
  end

  def sample_het(sidx, loci)
    count = 0
    col_gt = $col_1st_gt + sidx * $sample_cols
    loci.each do |locus, rows|
      count +=1 if rows[0][col_gt].start_with?("0/1")
      count +=1 if rows[0][col_gt].start_with?("1/0")
    end
    count
  end

  def sample_info(sidx, loci)
    impacts = Hash.new
    col_gt = $col_1st_gt + sidx * $sample_cols
    loci.each do |locus, rows|
      high = rows.max_by{|x|IMPACTS.index(x[$col_impact])} # a bug here was removed.
      gt = rows[0][col_gt]
      if gt.start_with?("0/1") || gt.start_with?("1/0") || gt.start_with?("1/1")
        impacts[high[$col_impact]] ||= 0
        impacts[high[$col_impact]] += 1
      end
    end
    impacts.sort_by{|k,v|IMPACTS.reverse.index(k)}.map{|(k,v)|"#{k}=#{v}"}.join("|")
  end

  def workbook_genewise(wbook, header, tab, xlsx)
    bold_wrap = wbook.styles.add_style(b:true, border:{style: :thin, color: 'dcdcdc'},
                                       alignment: {wrap_text: true})
    normal    = wbook.styles.add_style(i:false, bg_color: WHITE, border:{style: :thin, color: 'dcdcdc'})

    wbook.add_worksheet(:name => SHEET_GENEWISE) do |sheet|
      $col_qual      = header.index(COL_QUAL)
      $col_symbol    = header.index(COL_Symbol)
      $col_unique    = header.index(COL_Unique)
      $col_impact    = header.index(COL_Impact)
      $col_chrom     = header.index(COL_Chrom)
      $col_clinvar   = header.index(COL_ClinVar)
      $col_spliceai  = header.index(COL_SplicaAI)
      #$col_alphamiss = header.index(COL_AlphaMiss)
      $col_genename  = header.index(COL_GeneName)
      $col_alias     = header.index(COL_Alias)
      $col_mim       = header.index(COL_MIM)
      $col_comment   = header.index(COL_Comment)
      $col_phenotype = header.index(COL_Phenotype)
      $col_1st_gt    = header.index{|x|x.end_with?(COL_SUFFIX_GT)}
      $num_samples   = header.count{|x|x.end_with?(COL_SUFFIX_GT)}
      $sample_cols   =
        if header.count{|x|x.end_with?(COL_SUFFIX_DENOVO)} > 0
          8 # GT/DP/AD/GQ/SB/RNC/DENOVO/VA
        else
          6 # GT/DP/AD/GQ/SB/RNC
        end
      hcols = Array.new
      hcols << "symbol" << "unique" << "recessive" << "dominant"
      hcols << "chrom"
      hcols <<  "impact" << "flag" << "QUAL"
      hcols << "OMIM_GeneName" << "OMIM_GeneSymbol" << "OMIM_MIM"
      hcols << "OMIM_comment" << "OMIM_phenotype"
      (0 .. ($num_samples - 1)).each do |nsample|
        col_gt = $col_1st_gt + nsample * $sample_cols
        sname = header[col_gt].sub(/\.GT$/, '')
        hcols << "#{sname}_HOM"
        hcols << "#{sname}_HET"
        hcols << "#{sname}_info"
      end
      sheet.add_row(hcols, style: bold_wrap)

      tab.each do |gene, loci|
        firstent = loci[loci.keys[0]][0]
        rcols = Array.new
        rcols << gene
        rcols << firstent[$col_unique]
        rcols << gene_recessive(loci)
        rcols << gene_dominant(loci)
        rcols << gene_chrom(loci)
        rcols << gene_impact(loci)
        rcols << gene_flag(loci)
        rcols << gene_qual(loci)
        rcols << firstent[$col_genename]
        rcols << firstent[$col_alias]
        rcols << firstent[$col_mim]
        rcols << firstent[$col_comment]
        rcols << firstent[$col_phenotype]
        (0 .. ($num_samples - 1)).each do |sidx|
          rcols << sample_hom(sidx, loci)
          rcols << sample_het(sidx, loci)
          rcols << sample_info(sidx, loci)
        end
        sheet.add_row(rcols, style: normal)
      end
      sheet.column_widths(*([16] * hcols.size))
      sheet.auto_filter = "A1:" + sheet.rows[-1].cells[-1].reference
      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = 'B2'
        pane.state = :frozen_split
        pane.y_split = 1
        pane.x_split = 1
        pane.active_pane = :bottom_right
      end
    end
  end

  def workbook_variants(wbook, header, tab, xlsx)
    colsize   = header.size
    styles    = wbook.styles
    bold_wrap = styles.add_style(b:true, border:{style: :thin, color: 'dcdcdc'},
                                 alignment: {wrap_text: true})
    summary   = styles.add_style(i:true,  bg_color: WHITE, border:{style: :thin, color: 'dcdcdc'})
    detail    = styles.add_style(i:false, bg_color: FLORAL_WHITE, border:{style: :thin, color: 'dcdcdc'})

    wbook.add_worksheet(:name => SHEET_VARIANTS) do |sheet|
      sheet.sheet_pr.outline_pr.summary_below = false
      sheet.add_row(header, style: bold_wrap)
      nrow = 0
      tab.each do |gene, loci|
        loci.each do |locus, rows|
          high = rows.max_by{|x|IMPACTS.index(x[$col_impact])} # a bug here was removed.
          fail("the unknown impact in #{rows.inspect}") unless high
          sheet.add_row(high, style: summary)
          nrow += 1
          outline_start = nrow + 1
          rows.each do |cols|
            sheet.add_row(cols, style: detail)
            nrow += 1
          end
          sheet.outline_level_rows(outline_start, nrow, 1, false)
        end
      end
      sheet.column_widths(*([16] * colsize))
      sheet.auto_filter = "A1:" + sheet.rows[-1].cells[-1].reference
      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = 'B2'
        pane.state = :frozen_split
        pane.y_split = 1
        pane.x_split = 1
        pane.active_pane = :bottom_right
      end
    end
  end

  def create(header, tab, xlsx)
    pkg = Axlsx::Package.new
    wbook = pkg.workbook
    workbook_genewise(wbook, header, tab, xlsx)
    workbook_variants(wbook, header, tab, xlsx)
    warn "Serializing #{xlsx}"
    pkg.use_shared_strings = true # for Apple's Numbers
    pkg.serialize(xlsx) unless opts[:n]
  end

  def run
    annot_max =
      Dir["#{OUTD}/**/*.annot?.vcf.gz"].map{|x|File.basename(x).split(".")[-3].sub(/^annot/,"").to_i}.max

    Dir[
      "#{OUTD}/*.annot#{annot_max}.#{TARGET_SUFFIX}.*.uniq.txt",
    ].sort.each do |uniqtxt|
      next if File.basename(uniqtxt).include?(".raw.")
      warn "Processing #{File.basename(uniqtxt)}..."
      tab = Hash.new
      open(uniqtxt, "r") do |fin|
        header = nil
        fin.each_line.with_index do |row, nrow|
          cols = row.chomp.split("\t")
          if nrow.zero?
            header = cols.dup
            next
          end
          gene  = cols[0]
          locus = cols[1] # key (chrom-pos-ref-alt)
          tab[gene] ||= Hash.new
          tab[gene][locus] ||= Array.new
          tab[gene][locus] << cols # key sharing entries (multiple isoforms & multiple alterantives)
        end
        indname = ReadPedigreeFile.perse[0][:ind]
        model   = File.basename(uniqtxt).split(".")[-3]
        if uniqtxt.include?(OUTSUFFIX2)
          out = "#{EXCELD}/#{indname}.#{model}-#{OUTSUFFIX2}.#{REFNAME}.xlsx"
        else
          out = "#{EXCELD}/#{indname}.#{model}.#{REFNAME}.xlsx"
        end
        next if (File.exist?(out) && !(opts[:f]))
        FileUtils.mkdir_p(EXCELD)
        unless (File.exist?(out) && !opts[:f])
          create(header, tab, out)
        end
      end
    end
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("hnf")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
