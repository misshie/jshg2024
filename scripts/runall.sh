#!/bin/bash
set -euo pipefail

export RUBY_YJIT_ENABLE=1

100_query-sample.sh
110_run-bcftool-norm-multiallelic.rb
120_run-SnpEff-hg38.rb
130_Echtvar.rb
140_AddInfoFlags.rb
150_AddOMIM.rb
160_AddOthers.rb
170_SnpSiftFilter.rb
180_inheritence-models.rb
190_SnpSiftExtractFields.rb
200_CountUniqueID.rb
210_make-genewise-variants-xlsx.rb
