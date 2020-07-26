#!/usr/bin/env bash

set -euo pipefail

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }
# usage () { die "\e[0musage: $0 -p IMAGING_PATH [-b MASTER_BIAS] [-f MASTER_FLAT] [-d MASTER_DARK]"; }
usage () { die "\e[0musage: $0 IMAGING_DIRECTORY"; }


#
# Check userland deps
#

if hash siril-cli 2>/dev/null; then
  sirilBin="siril-cli"
elif hash siril 2>/dev/null; then
  sirilBin="siril"
else
  die "Missing dep: siril"
fi
siril_w () ( $sirilBin -s <(echo "$*") 2>&1 | tee "$processingDate.log"; )



#
# Setup processing configuration
#

processingDate="$(date +"%Y-%m-%dT%H%M")"
currentDir="$(dirname "$0")"

imagingDir="${1%/}"
[[ -n "$imagingDir" ]] || { usage; }


darksPath="$imagingDir/Darks"
masterDark="$darksPath/master-dark.fit"
generateDark=
[[ -r "$masterDark" ]] || generateDark="true"


flatsPath="$imagingDir/Flats"
masterFlat="$flatsPath/master-flat.fit"
generateFlat=
[[ -r "$masterFlat" ]] || generateFlat="true"
biasRequired=
[[ -r "$masterFlat" ]] || biasRequired="true"


biasesPath="$imagingDir/Biases"
masterBias="$biasesPath/master-bias.fit"
generateBias=
[[ -r "$masterBias" && -n "$biasRequired" ]] || generateBias="true"



#
# Log configuration
#
info "********    Processinging configuration    ********"
echo "Current directory: $currentDir"
echo "Imaging directory: $imagingDir"

echo
echo "Bias master:"
if [[ -z "$biasRequired" ]]; then
  echo "  Biases master not required as flats master exists"
elif [[ -z "$generateBias" ]]; then
  echo "  Using pre-existing biases master $masterBias"
else
  echo "  Biases master $masterBias not found"
  echo "  Generating biases master from directory $biasesPath"
fi


echo
echo "Flats master:"
if [[ -z "$generateFlat" ]]; then
  echo "  Using pre-existing flats master $masterFlat"
else
  echo "  Flats master $masterFlat not found"
  echo "  Generating flats master from directory $flatsPath"
fi


echo
echo "Darks master:"
if [[ -z "$generateDark" ]]; then
  echo "  Using pre-existing darks master $masterDark"
else
  echo "  Darks master $masterDark not found"
  echo "  Generating darks master from directory $darksPath"
fi

# 1. Find callibration masters
#    a. Path needs to be relative to lights though
# 2. Path to lights
# 3. Session mode? Only perform calibration, don't register or stack
# 4. Region of interest mode?
# 5. Drizzle?
