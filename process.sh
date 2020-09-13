#!/usr/bin/env bash

set -euo pipefail

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }
usage () { die "\e[0m$0 -p IMAGING_PATH [-b MASTER_BIAS] [-f MASTER_FLAT] [-d MASTER_DARK]"; }


if hash siril-cli 2>/dev/null; then
  sirilBin="siril-cli"
elif hash siril 2>/dev/null; then
  sirilBin="siril"
else
  die "Missing dep: siril"
fi
siril_w () ( $sirilBin -s <(echo "$*"); )


# 1. Find callibration masters
#    a. Path needs to be relative to lights though
# 2. Path to lights
# 3. Session mode? Only perform calibration, don't register or stack
# 4. Region of interest mode?
# 5. Drizzle?


#
# Initialise
#
processingDate="$(date +"%Y-%m-%dT%H%M.fit")"

imagingPath=
session=
#masterBias="/mnt/c/Users/Brendan/Documents/astrophotography/Imaging/calibration_library/bias/iso800/master-bias_iso800_134frames.fit"
masterBias=
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
stackName="stack_$processingDate"
[[ $stackName =~ "stack_" ]] || { die "Failed to generate output stack name"; }
lightsPath="${lightsPath:-$imagingPath/Lights}"
biasesPath="${biasesPath:-$imagingPath/Biases}"
flatsPath="${flatsPath:-$imagingPath/Flats}"
darksPath="${darksPath:-$imagingPath/Darks}"

#
# Configuration...
#
info "**** Processing configuration ****"

#
# Master Flat
#
maybeMasterFlat="${masterFlat:-$flatsPath/master-flat.fit}"
echo "master flat:
  .. checking $maybeMasterFlat"
if [[ -f "$maybeMasterFlat" ]]; then
  masterFlat="$maybeMasterFlat"
  echo "  .. found $masterFlat"
else
  masterFlat=
  flatsDir="$flatsPath"
  if [[ ! -d "$flatsDir" ]]; then
    die "  .. flats directory $flatsDir not found"
  fi
  echo "  .. no master flat found - processing $flatsDir"
fi

#
# Master Bias
#
if [[ -n "$masterFlat" ]]; then
  echo -e "\nmaster bias:
  .. not required as master flat already exists"
else
  maybeMasterBias="${masterBias:-"$biasesPath/master-bias.fit"}"
  echo -e "\nmaster bias:
  .. checking $maybeMasterBias"
  if [[ -f "$maybeMasterBias" ]]; then
    masterBias=$maybeMasterBias
    echo "  .. using $masterBias"
  else
    echo "  .. no master found - processing $biasesPath"
  fi
fi


#
# Master Darks
#
maybeMasterDark="${masterDark:-$darksPath/master-dark.fit}"
echo -e "\nmaster dark:
  .. checking $maybeMasterDark"
if [[ -f "$maybeMasterDark" ]]; then
  masterDark="$maybeMasterDark"
  echo "  .. found $masterDark"
else
  echo "  .. no master dark found - processing $darksPath"
fi


#
# Lights
#
echo -e "\nlights:
  .. processing $lightsPath"

if [[ -n "$session" ]]; then
  echo -e "\nrunning in session mode, only pre-processing will be applied to lights and they will not be registered or stacked"
else
  echo -e "\nOutput stack will be $imagingPath/Stacks/$stackName"
fi

echo -ne "\n\nContinue processing? .... "
read -r input
start=$(date -u +'%s')


#
# Processing biases
#
if [[ -z "$masterBias" ]] && [[ -z "$masterFlat" ]]; then
  info "\n**** Generating master bias ****"
  biasesScript="convertraw bias_
stack bias_ rej 3 3 -nonorm -out=master-bias.fit"

  echo "Master bias generation script:
$biasesScript"

  (
    cd "$biasesPath";
    if ! siril_w "$biasesScript"; then
      rm -f bias_*
      die "Siril error generating master bias"
    fi
    rm -f bias_*
  )

  masterBias="$biasesPath/master-bias.fit"
  good "Created master bias $masterBias"
fi


#
# Processing flats
#
if [[ -z "$masterFlat" ]]; then
  bias="$(realpath --relative-to $flatsPath $masterBias)"
  info "\n**** Generating master flat ****"

  flatsScript="convertraw flat_
preprocess flat_ -bias=$bias
stack pp_flat_ rej 3 3 -norm=mul -out=master-flat.fit"
  echo "Master flat generation script
$flatsScript"

  (
    cd "$flatsPath"
    if ! siril_w "$flatsScript"; then
      rm -f flat_* pp_flat_*
      die "Siril error processing flats"
    fi
    rm -f flat_* pp_flat_*
  )
  masterFlat="$flatsPath/master-flat.fit"
  good "Created master flat $masterFlat"
fi



#
# Processing darks
#
if [[ -z "$masterDark" ]]; then
  info "\n**** Generating master dark ****"

  darksScript="convertraw dark_
stack dark_ rej 3 3 -nonorm -out=master-dark.fit"
  echo "Master dark script
$darksScript"

  (
    cd "$darksPath";
    if ! siril_w "$darksScript"; then
      rm -f dark_*
      die "Siril error while generating master dark"
    fi
    rm -f dark_*
  )
  masterDark="$darksPath/master-dark.fit"
fi



#
# Processing lights
#
stack="$currentDir/$imagingPath/Stacks/$stackName"
flat="$(realpath --relative-to $lightsPath $currentDir/$masterFlat)"
dark="$(realpath --relative-to $lightsPath $currentDir/$masterDark)"
info "\n**** Processing lights ****"

preprocess="convertraw light_
preprocess light_ -dark=$dark -flat=$flat -cfa -equalize_cfa -debayer"
register="register pp_light_"
stack="stack r_pp_light_ rej 3 3 -norm=addscale -out=$stack"

# Drizzled ROI
#   preprocess="convertraw light_
# preprocess light_ -dark=$dark -flat=$flat -cfa -equalize_cfa -debayer
# seqcrop pp_light_ 2000 1000 2000 2000"
#   register="register cropped_pp_light_ -drizzle"
#   stack="stack r_cropped_pp_light_ rej 3 3 -norm=addscale -out=$stack"

mkdir -p $imagingPath/Stacks

info "\n***** Light processing script ******"
echo "$preprocess"
[[ -z "$session" ]] && echo -e "$register\n$stack"


info "\n**** Begin light processing ****"

(
  cd "$lightsPath"
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
if [[ -z "$session" ]]; then
  echo "Final stack $imagingPath/Stacks/$stackName"
else
  echo "preprocessed lights are in $lightsPath"
fi
end=$(date -u +'%s')
runtime=$(( end - start ))
echo "   elapsed time: $(date -d@$runtime -u +'%H:%M:%S')"
