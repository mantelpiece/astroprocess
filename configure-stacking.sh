#!/usr/bin/env bash

set -euo pipefail

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m" >&2; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }
usage () { die "${1:-""}\n\n\e[0musage: $0 -i IMAGING_DIR [-b MASTER_BIAS] [-f MASTER_FLAT] [-d MASTER_DARK]"; }


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
[[ -n "$imagingDir" ]] || { usage "Imaging dir must be provided"; }



#
# Setup processing configuration
#

processingDate="$(date +"%Y-%m-%dT%H%M")"
currentDir="$(dirname "$0")"
lightsPath="$imagingDir/Lights"
[[ -d "$lightsPath" ]] || { usage "Failed to find lights directory $lightsPath"; }


declare -A masterDirs=( [dark]="Darks" [flat]="Flats" [bias]="Biases" )
generateMasterConfig () {
  local masterType="$1"
  local userDir="$2"

  local path="${userDir:-"$imagingDir/${masterDirs[$masterType]}"}"
  local generateMaster=
  local master=
  if [[ -d "$path" ]]; then
    master="$path/master-$masterType.fit"
    [[ -r "$master" ]] || generateMaster="true"
  elif [[ -r "$path" ]]; then
    master="$path"
  else
    die "Failed to find ${masterType}s in $path"
  fi

  cat <<EOF
${masterType}sPath="$path"
generate${masterType^}="$generateMaster"
master${masterType^}="$master"
EOF
}

darksPath=
generateDark=
masterDark=
eval $(generateMasterConfig "dark" "$userDarks")


flatsPath=
generateFlat=
masterFlat=
eval $(generateMasterConfig "flat" "$userFlats")

biasRequired=
[[ -r "$masterFlat" ]] || biasRequired="true"
biasesPath=
generateBias=
masterBias=
eval $(generateMasterConfig "bias" "$userBiases")


[[ -z "$darksPath" && -z "$masterDark" ]] && usage "Master dark missing"
[[ -z "$flatsPath" && -z "$masterFlat" ]] && usage "Master flat missing"
[[ -n "$biasRequired" && -z "$flatsPath" && -z "$masterFlat" ]] && usage "Master bias missing"


cat <<EOF
generateBias="$biasRequired"
generateFlat="$generateFlat"
generateDark="$generateDark"

lightsPath="$lightsPath"
biasesPath="$biasesPath"
flatsPath="$flatsPath"
darksPath="$darksPath"

masterBias="$masterBias"
masterFlat="$masterFlat"
masterDark="$masterDark"
EOF
