#!/usr/bin/env ruby

class GConfig
  InputBcf = "comb.both.bcf"
  FamName   = "comb"
  SamplesTxt = "samples.txt"
  DedupCharsSearch = ""
  Mendelian_ParentTrans = false # true
  SSFilter_MaxMAF = 0.005 # 0.5%
  SSFilter_OutSuffix  = "rare"
  BCFTOOLS    = "/xcatopt/bcftools-1.19/bcftools"
  SNPEFF      = "/xcatopt/snpEff-5.1/snpEff.jar"
  ECHTVAR     = "/xcatopt/Echtvar-v0.2.0/echtvar"
  ECHTVAR_DIR = "./EchtVarIndexedDBs"
end

if $0 == __FILE__
  warn "a script for set required consistants."
end

