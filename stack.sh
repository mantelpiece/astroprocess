#!/usr/bin/env bash

set -euo pipefail

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }
usage () { die "\e[0musage: $0 -i IMAGING_DIR [-b MASTER_BIAS] [-f MASTER_FLAT] [-d MASTER_DARK]"; }


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
# Process CLI arguments
#
imagingDir=
userBiases=
userDarks=
userFlats=
while getopts "i:b:d:f:" i; do
  case "$i" in
    i) imagingDir="${OPTARG%/}" ;;
    b) userBiases="${OPTARG%/}" ;;
    d) userDarks="${OPTARG%/}" ;;
    f) userFlats="${OPTARG%/}" ;;
    -) break ;;
    ?) usage ;;
    *) usage ;;
  esac
done
[[ -n "$imagingDir" ]] || { usage; }



#
# Setup processing configuration
#

processingDate="$(date +"%Y-%m-%dT%H%M")"
currentDir="$(dirname "$0")"
lightsPath="$imagingDir/Lights"
[[ -d "$lightsPath" ]] || { die "Failed to find lights directory $lightsPath"; }

# Darks
darksPath="${userDarks:-"$imagingDir/Darks"}"
generateDark=
if [[ -d "$darksPath" ]]; then
  masterDark="$darksPath/master-dark.fit"
  [[ -r "$masterDark" ]] || generateDark="true"
elif [[ -r "$darksPath" ]]; then
  masterDark="$darksPath"
else
  die "Failed to find darks in $darksPath"
fi

# Flats
flatsPath="${userFlats:-"$imagingDir/Flats"}"
generateFlat=
biasRequired=
if [[ -d "$flatsPath" ]]; then
  masterFlat="$flatsPath/master-flat.fit"
  if [[ ! -r "$masterFlat" ]]; then
    generateFlat="true"
    biasRequired="true"
  fi
elif [[ -r "$flatsPath" ]]; then
  masterFlat="$flatsPath"
else
  die "Failed to find flats in $flatsPath"
fi

# Biases
generateBias=
if [[ -n "$biasRequired" ]]; then
  biasesPath="${userBiases:-"$imagingDir/Biases"}"
  if [[ -d "$biasesPath" ]]; then
    masterBias="$biasesPath/master-bias.fit"
    [[ -r "$masterBias" ]] || generateBias="true"
  elif [[ -r "$biasesPath" ]]; then
    masterBias="$biasesPath"
  else
    die "Failed to find biases in $biasesPath"
  fi
fi


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


echo
echo "Processing lights:"
echo "  lights directory: $lightsPath"

# 1. Find callibration masters
#    a. Path needs to be relative to lights though
# 2. Path to lights
# 3. Session mode? Only perform calibration, don't register or stack
# 4. Region of interest mode?
# 5. Drizzle?
