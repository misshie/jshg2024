#!/usr/bin/env ruby

class GConfig
  InputBcf = "comb.both.bcf"
  FamName   = "comb"
  SamplesTxt = "samples.txt"
  DedupCharsSearch = ""
  Mendelian_ParentTrans = false # true
  SSFilter_MaxMAF = 0.005 # 0.5%
  SSFilter_OutSuffix  = "rare"
end

if $0 == __FILE__
  warn "a script for set required consistants."
end

