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
imagingPath=
userLights=
userBiases=
userDarks=
userFlats=
roi=
session=
while getopts "i:l:b:d:f:r:S" i; do
  case "$i" in
    i) imagingPath="${OPTARG%/}" ;;
    l) userLights="${OPTARG%/}" ;;
    b) userBiases="${OPTARG%/}" ;;
    d) userDarks="${OPTARG%/}" ;;
    f) userFlats="${OPTARG%/}" ;;
    r) roi="${OPTARG}" ;;
    S) session="true" ;;
    -) break ;;
    ?) usage ;;
    *) usage ;;
  esac
done
[[ -d "$imagingPath" ]] || { usage "Imaging dir must be provided"; }



#
# Setup processing configuration
#

processingDate="$(date +"%Y-%m-%dT%H%M")"
currentDir="$(dirname "$0")"
lightsPath="${userLights:-"$imagingPath/Lights"}"
[[ -d "$lightsPath" ]] || { usage "Failed to find lights directory $lightsPath"; }

# Assume imaging path is .../$TARGET/$DATE
stackName=
fullPath=$(realpath $imagingPath)
imagingDate=${fullPath##*/}
sansDate=${fullPath%/*}
targetName=${sansDate##*/}
processingDate=$(date +'%Y%m%dT%H%M')
stackName="stack_${targetName}_${imagingDate}_${processingDate}"


declare -A masterDirs=( [dark]="Darks" [flat]="Flats" [bias]="Biases" )
generateMasterConfig () {
  local masterType="$1"
  local userDir="$2"

  local path="${userDir:-"$imagingPath/${masterDirs[$masterType]}"}"
  local generateMaster=
  local master=
  if [[ -d "$path" ]]; then
    local maybeMaster="$path/master-$masterType.fit"
    if [[ -r "$maybeMaster" ]]; then
      master="$path/master-$masterType.fit"
    else
      generateMaster="true"
    fi
  elif [[ -r "$path" ]]; then
    master="$path"
  else
    die "Failed to find ${masterType} master/raws in $path"
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
[[ -n "$biasRequired" && -z "$biasesPath" && -z "$masterBias" ]] && usage "Master bias missing"


cat <<EOF
targetName="$targetName"
imagingDate="$imagingDate"
processingDate="$processingDate"
stackName="$stackName"
roi="$roi"
session="$session"

imagingPath="$imagingPath"
lightsPath="$lightsPath"
biasesPath="$biasesPath"
flatsPath="$flatsPath"
darksPath="$darksPath"

generateBias="$biasRequired"
generateFlat="$generateFlat"
generateDark="$generateDark"

masterBias="$masterBias"
masterFlat="$masterFlat"
masterDark="$masterDark"
EOF
