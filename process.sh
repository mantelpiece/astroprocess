#!/usr/bin/env bash

set -euo pipefail

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }
usage () { die "\e[0m$0 -p IMAGING_PATH [-b MASTER_BIAS] [-f MASTER_FLAT] [-d MASTER_DARK]"; }

hash siril 2>/dev/null || { die "Mising dep: siril"; }


siril_w () { siril-cli -s <(echo "$*") >&2; }



# Initialise
imagingPath=
lightsPath="Lights"
biasPath="Biases"
flatsPath="Flats"
darksPath="Darks"
session=
masterBias="/mnt/c/Users/Brendan/Documents/astrophotography/Imaging/calibration_library/bias/iso800/master-bias_iso800_134frames.fit"
masterFlat=
masterDark=
while getopts "p:L:F:D:B:b:f:d:S" i; do
  case "$i" in
    p) imagingPath="$OPTARG" ;;
    L) lightsPath="$OPTARG" ;;
    B) biasesPath="$OPTARG" ;;
    F) flatsPath="$OPTARG" ;;
    D) darksPath="$OPTARG" ;;
    b) masterBias="$OPTARG" ;;
    f) masterFlat="$OPTARG" ;;
    d) masterDark="$OPTARG" ;;
    S) session="${OPTARG:-session}" ;;
    -) break ;;
    ?) usage ;;
    *) usage ;;
  esac
done
[[ -n "$imagingPath" ]] || { usage; }
[[ -d $imagingPath ]] || { die "$imagingPath not found"; }
currentDir=$(pwd)
stackName="stack_$(date +"%Y-%m-%dT%H:%m.fit")"
[[ $stackName =~ "stack_" ]] || { die "Failed to generate output stack name"; }

info "**** Processing configuration ****"

if [[ -z "$masterBias" ]]; then
  die "No master bias"
else
  echo "master bias:
    using $masterBias"
fi

maybeMasterFlat="$currentDir/$imagingPath/$flatsPath/master-flat.fit"
if [[ -f "$maybeMasterFlat" ]]; then
  masterFlat="$maybeMasterFlat"
  echo "master flat:
    found $masterFlat... use as master flat"
else
  echo "master flat - no master flat found:
    processing $imagingPath/$flatsPath"
fi

maybeMasterDark="$currentDir/$imagingPath/Darks/master-dark.fit"
if [[ -f "$maybeMasterDark" ]]; then
  masterDark="$maybeMasterDark"
  echo "master dark:
    found $masterDark... use as master dark"
else
  echo "master dark - no master dark found:
    processing $imagingPath/$darksPath"
fi

echo "processing lights:
    $imagingPath/$lightsPath"

[[ -n "$session" ]] && echo -e "\nrunning in session mode, only pre-processing will be applied to lights and they will not be registered or stacked"


echo -e "\nOutput stack will be $imagingPath/Stacks/$stackName"

echo -ne "\n\nContinue processing? .... "
read -r input



if [[ -z "$masterBias" ]] && [[ -n "$masterFlat" ]]; then
  info "\n**** Generating master bias ****"
  masterBias="$(generateMasterBias)"
  biasesScript="convertraw bias_
stack bias_ rej 3 3 -nonorm -out=master-bias.fit"

  echo "Master bias generation script:
$biasesScript"

  (
    cd "$imagingPath/$biasesPath";
    if ! siril_w "$biasesScript"; then
      rm -f bias_*
      die "Siril error generating master bias"
    fi
    rm -f bias_*
    echo "$(pwd)/master-bias.fit"
  )

  masterBias="$biasesPath/master-bias.fit"
  good "Created master bias $masterBias"
fi


if [[ -z "$masterFlat" ]]; then
  info "\n**** Generating master flat ****"

  flatsScript="convertraw flat_
preprocess flat_ -bias=$masterBias
stack pp_flat_ rej 3 3 -norm=mul -out=master-flat.fit"
  echo "Master flat generation script
$flatsScript"

  (
    cd "$imagingPath/$flatsPath"
    if ! siril_w "$flatsScript"; then
      rm -f flat_* pp_flat_*
      die "Siril error processing flats"
    fi
    rm -f flat_* pp_flat_*
  )
  masterFlat="../$flatsPath/master-flat.fit"
  good "Created master flat $masterFlat"
fi



if [[ -z "$masterDark" ]]; then
  info "\n**** Generating master dark ****"

  darksScript="convertraw dark_
stack dark_ rej 3 3 -nonorm -out=master-dark.fit"
  echo "Master dark script
$darksScript"

  (
    cd "$imagingPath/$darksPath";
    if ! siril_w "$darksScript"; then
      rm -f dark_*
      die "Siril error while generating master dark"
    fi
    rm -f dark_*
  )
  masterDark="../$darksPath/master-dark.fit"
fi



info "\n**** Processing lights ****"
  preprocess="convertraw light_
preprocess light_ -dark=$masterDark -flat=$masterFlat -cfa -equalize_cfa -debayer"
  register="register pp_light_"
  stack="stack r_pp_light_ rej 3 3 -norm=addscale -out=../Stacks/$stackName"


mkdir -p $imagingPath/Stacks

info "\n***** Light processing script ******"
echo "$preprocess"
[[ -z "$session" ]] && echo -e "$register\n$stack"


info "\n**** Begin light processing ****"

(
  cd "$imagingPath/$lightsPath"
    info "\n**** Converting and preprocessing lights ****"
  if ! siril_w "$preprocess"; then
    rm -f light_* pp_light_*
    die "Siril failed during lights preprocessing"
  fi
  rm -f light_*

  if [[ -z "$session" ]]; then
    info "\n**** Registering and stacking lights ****"
    if ! siril_w "$register"; then
      rm -f r_pp_light_*
      die "Siril failed during register of lights"
    fi

    rm -f pp_light_*
    if ! siril_w "$stack"; then
      die "Siril failed during lights stacking"
    fi

    rm -f light_* pp_light_* r_pp_light_*
  fi

)
good "**** Success ****"
good "Final stack $imagingPath/Stacks/final-stack.fit"
