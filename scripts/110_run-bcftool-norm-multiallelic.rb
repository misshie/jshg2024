#!/usr/bin/env ruby
require 'optparse'
require "./00config.rb"

class Klass
  INPUTBCF = GConfig::InputBcf
  OUTPUTBCF = "#{GConfig::FamName}.norm.bcf"
  SAMPLESTXT = GConfig::SamplesTxt

  BCFTOOLS = "/xcatopt/bcftools-1.19/bcftools"
  THREADS = 32

  attr_reader :opts

  def initialize(opts)
    @opts = opts
  end

  def run
    cmd = Array.new
    cmd << BCFTOOLS
    cmd << "query"
    cmd << "-l"
    cmd << INPUTBCF
    cmd << "> #{SAMPLESTXT}"
    warn   cmd.join(" ")
    system cmd.join(" ") unless opts[:n]

    cmd = Array.new
    cmd << BCFTOOLS
    cmd << "norm"
    cmd << "--multiallelics -both"
    cmd << "-Ob"
    cmd << "-o #{OUTPUTBCF}"
    cmd << "--threads #{THREADS}"
    cmd << INPUTBCF
    warn   cmd.join(" ")
    system cmd.join(" ") unless opts[:n]

    cmd = Array.new
    cmd << BCFTOOLS
    cmd << "index"
    cmd << OUTPUTBCF
    warn   cmd.join(" ")
    system cmd.join(" ") unless opts[:n]
  end
end

if $0 == __FILE__
  opts = ARGV.getopts("h")
  Klass.new(opts.map{|k,v|[k.to_sym, v]}.to_h).run
end
