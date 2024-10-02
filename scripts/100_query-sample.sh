#!/bin/bash
set -euo pipefail

/xcatopt/bcftools-1.19/bcftools query -l comb.both.bcf | tee samples.txt
