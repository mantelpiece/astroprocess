#!/usr/bin/env bash

set -euo pipefail

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }
usage () { die "\e[0m$0 -p IMAGING_PATH [-b MASTER_BIAS] [-f MASTER_FLAT] [-d MASTER_DARK]"; }

hash siril 2>/dev/null || { die "Mising dep: siril"; }
siril_w () { siril-cli -s <(echo "$*") >&2; }



precheck () {
  maybeMasterFlat="$currentDir/$imagingPath/Flats/master-flat.fit"
  if [[ -f "$maybeMasterFlat" ]]; then
    masterFlat="$maybeMasterFlat"
    info "$masterFlat exists... use as master flat"
  else
    info "no master flat found"
  fi

  maybeMasterDark="$currentDir/$imagingPath/Darks/master-dark.fit"
  if [[ -f "$maybeMasterDark" ]]; then
    masterDark="$maybeMasterDark"
    info "$masterDark exists... use as master dark"
  else
    info "no master dark found"
  fi
}


main () {
  if [[ -z "$masterBias" ]] && [[ -n "$masterFlat" ]]; then
    info "Generating bias $masterBias"
    masterBias="$(generateMasterBias)"
  fi

  if [[ -z "$masterFlat" ]]; then
    info "Generating master flat $masterFlat..."
    masterFlat="$(generateMasterFlat)"
    good "Created $masterFlat"
  fi

  if [[ -z "$masterDark" ]]; then
    info "Generating master dark $masterDark"
    masterDark="$(generateMasterDark)"
  fi

  info "Processing lights..."
  if ! output=$(processLights); then
    die "********* GENERATION FAILED"
  fi
  good "****************** SUCCESS *******************"
  echo "output: $output"
}



generateMasterBias () {
  biasesScript="convertraw bias_
stack bias_ rej 3 3 -nonorm -out=master-bias.fit"

  (
    cd "$biasDir";
    if ! siril_w "$biasesScript"; then
      rm -f bias_*
      die "Siril error"
    fi
    rm -f bias_*
    echo "$(pwd)/master-bias.fit"
  )
  masterBias="$imagingPath/Bias/master-bias.fit"
}

generateMasterFlat () {
  flatsScript="convertraw flat_
preprocess flat_ -bias=$currentDir/$masterBias
stack pp_flat_ rej 3 3 -norm=mul -out=master-flat.fit"

  (
    cd "$imagingPath/Flats"
    if ! siril_w "$flatsScript"; then
      rm -f flat_* pp_flat_*
      die "Siril error processing flats"
    fi
    rm -f flat_* pp_flat_*
  )
  masterFlat="$currentDir/$imagingPath/Flat/master-flat.fit"
}


generateMasterDark () {
  darksScript="convertraw dark_
stack dark_ rej 3 3 -nonorm -out=master-dark.fit"

  (
    info "Using master bias - $masterBias" >&2
    cd "$imagingPath/Darks";
    if ! siril_w "$darksScript"; then
      rm -f dark_*
      die "Siril error while generating master dark"
    fi
    rm -f dark_*
  )
  masterDark="$currentDir/$imagingPath/Dark/master-dark.fit"
}


processLights () {
  lightsScript='convertraw light_
preprocess light_ -dark='"$masterDark"' -flat='"$masterFlat"' -cfa -equalize_cfa -debayer
register pp_light_
stack r_pp_light_ rej 3 3 -norm=addscale -out=../Stacks/stack.fit'
info "***** Light processing script ******" >&2
echo "$lightsScript" >&2
info "*****                         ******" >&2

  (
    info "Using master flat - $masterFlat" >&2
    info "Using master dark - $masterDark" >&2
    cd "$imagingPath/Lights"
    if ! siril_w "$lightsScript"; then
      rm -f light_* pp_light_* r_pp_light_*
      die "Siril failed during lights preprocessing"
    fi
    rm -f light_* pp_light_* r_pp_light_*

    echo "$(pwd)/../Stacks/final-stack.fit"
  )
}


imagingPath=
masterBias=
masterFlat=
masterDark=
while getopts "p:b:f:d:" i; do
  case "$i" in
    p) imagingPath="$OPTARG" ;;
    b) masterBias="$OPTARG" ;;
    f) masterFlat="$OPTARG" ;;
    d) masterDark="$OPTARG" ;;
    -) break ;;
    ?) usage ;;
    *) usage ;;
  esac
done
[[ -n "$imagingPath" ]] || { usage; }
[[ -d $imagingPath ]] || { die "$imagingPath not found"; }
currentDir=$(pwd)

precheck
main
