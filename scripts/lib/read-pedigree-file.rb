#!/usr/bin/env ruby
require 'optparse'

class ReadPedigreeFile
  PEDFILES = ["00pedigree.ped", "0pedigree.ped", "pedigree.ped"]
  PEDFORMAT = Struct.new(:fam, :ind, :pat, :mat, :sex, :aff)

  class << self
    def perse(ped = nil)
      ped_lines(ped)
    end

    def trio_dnm2(ped = nil)
      kid, kid_s, dad, mom = nil, nil, nil, nil
      ped_lines(ped).each_with_index do |c, idx|
        case
        when (c.pat != "0") && (c.mat != "0") && (c.aff == "2")
          kid   = c.ind.dup
          kid_s = c.sex.dup
        when (c.pat == "0") && (c.mat == "0") && (c.sex == "1")
          dad = c.ind.dup
        when (c.pat == "0") && (c.mat == "0") && (c.sex == "2")
          mom = c.ind.dup
        end
      end

      # "1X:ABCD_EFGH_17_0099,ABCD_EFGH_17_0099Father,ABCD_EFGH_17_0099Mother"
      case kid_s
      when "1"
        out = "1X:#{kid},#{dad},#{mom}"
      when "2"
        out = "2X:#{kid},#{dad},#{mom}"
      else
        out = "1X:#{kid},#{dad},#{mom}"
      end
      out
    end

    def cfm_indices(ped = nil)
      kid, dad, mom = nil, nil, nil
      ped_lines(ped).sort_by{|x|x.ind}.each_with_index do |c, idx|
        case
        when (c.pat != "0") && (c.mat != "0") && (c.aff == "2")
          kid = idx
        when (c.pat == "0") && (c.mat == "0") && (c.sex == "1")
          dad = idx
        when (c.pat == "0") && (c.mat == "0") && (c.sex == "2")
          mom = idx
        end
      end
      [kid, dad, mom]
    end

    def affs_unaffs_others_indices(ped = nil)
      affs, unaffs, others  = Array.new, Array.new, Array.new
      ped_lines(ped).sort_by{|x|x.ind}.each_with_index do |c, idx|
        case
        when c.aff == "1"
          unaffs << idx
        when c.aff == "2"
          affs << idx
        else
          others << idx
        end
      end
      [affs, unaffs, others]
    end

    private

    def ped_lines(ped)
      unless ped
        PEDFILES.each{|x|ped=x if File.exist?(x)}
      end
      fail "A pedigree file is not found." unless File.exist?(ped)
      File.readlines(ped).
        map{|x|x.chomp.squeeze(" ")}.
        reject{|x|x.start_with?("#")}.
        reject{|x|x.empty?}.
        map{|x|PEDFORMAT.new(*x.split(/\t| /))}
    end
  end
end

if $0 == __FILE__
  warn "test mode:"
  pp ReadPedigreeFile.perse()
  pp ReadPedigreeFile.trio_dnm2()
  pp ReadPedigreeFile.cfm_indices()
end
