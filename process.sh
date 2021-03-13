#!/usr/bin/env bash

set -euo pipefail

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }


if hash siril-cli 2>/dev/null; then
  sirilBin="siril-cli"
elif hash siril 2>/dev/null; then
  sirilBin="siril"
else
  die "Missing dep: siril"
fi

# Delegate stacking parameter configuration to `configure-stacking.sh`
currentDir="$(pwd)"
scriptDir="$(realpath $(dirname "$0"))"
sirils="$scriptDir/siril-processing"

if ! config=$("$scriptDir/configure-stacking.sh" "$@"); then
  die "Failed to configure stacking"
fi
# Set config into shell
eval $config
echo "$config"


#
# Configuration...
#
info "**** Processing configuration ****"

#
# Master Flat
#
if [[ -n "$noFlats" ]]; then
  echo -e "\nnot using flat frames"
else
  echo "master flat:
    .. checking $flatsPath"
  if [[ -r "$masterFlat" ]]; then
    echo "  .. found $masterFlat"
  else
    if [[ ! -d "$flatsPath" ]]; then
      die "  .. flats directory $flatsPath not found"
    fi
    echo "  .. no master flat found - processing $flatsPath"
    masterFlat="$flatsPath/master-flat.fit"
  fi

  #
  # Master Bias
  #
  echo -e "\nmaster bias:"
  if [[ -z "$generateBias" ]]; then
    echo -e " .. not required as master flat already exists"
  else
    echo -e " .. checking $biasesPath"
    if [[ -r "$masterBias" ]]; then
      echo "  .. using $masterBias"
    else
      echo "  .. no master found - processing $biasesPath"
      masterBias="$biasesPath/master-flat.fit"
    fi
  fi
fi


#
# Master Darks
#
if [[ -n "$noDarks" ]]; then
  echo -e "\nnot using dark frames"
else
  echo -e "\nmaster dark:
    .. checking $darksPath"
  if [[ -r "$masterDark" ]]; then
    echo "  .. found $masterDark"
  else
    echo "  .. no master dark found - processing $darksPath"
    masterDark="$darksPath/master-dark.fit"
  fi
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

echo "I need to set masters even if they dont exist"
echo -ne "\n\nContinue processing? .... "
read -r input
start=$(date -u +'%s')


#
# Processing biases
#
if [[ ! -r "$masterBias" ]] && [[ -n "$generateBias" ]]; then
  info "\n**** Generating master bias ****"
  $sirils/convertAndStackWithRejectionAndNoNorm.sh \
      "$biasesPath" "bias_" "master-bias"
  masterBias="$biasesPath/master-bias.fit"
  good "Created master bias $masterBias"
fi


#
# Processing flats
#
if [[ ! -r "$masterFlat" ]] && [[ -n "$generateFlat" ]]; then
  bias="$(realpath --relative-to $flatsPath $masterBias)"
  info "\n**** Generating master flat ****"
  $sirils/convertAndPreprocessWithCalibration.sh \
      "$flatsPath" "flat_" "-bias=$bias"
  $sirils/stackSeqWithRejection.sh \
      "$flatsPath" "pp_flat_" "mul" "master-flat"
  good "Created master flat $masterFlat"
fi



#
# Processing darks
#
if [[ ! -r "$masterDark" ]] && [[ -n "$generateDark" ]]; then
  info "\n**** Generating master dark ****"
  $sirils/convertAndStackWithRejectionAndNoNorm.sh \
      "$darksPath" "dark_" "master-dark"
  masterDark="$darksPath/master-dark.fit"
  good "Created master dark $masterDark"
fi


#
# Processing lights
#
info "\n**** Processing lights ****"

info "\n**** Begin light processing ****"
mkdir -p $imagingPath/Stacks
flat="$(realpath --relative-to "$lightsPath" "$currentDir/$masterFlat")"
dark="$(realpath --relative-to "$lightsPath" "$currentDir/$masterDark")"
outputStack="$(realpath --relative-to $lightsPath "$imagingPath/Stacks/${stackName}")"

calibrationFrames=""
[[ -z "$noDarks" ]] && calibrationFrames="$calibrationFrames -dark=$dark"
[[ -z "$noFlats" ]] && calibrationFrames="$calibrationFrames -flat=$flat"
$sirils/convertAndPreprocessWithCalibration.sh \
    "$lightsPath" "light_" "$calibrationFrames -cfa -equalize_cfa -debayer"
currentSeq="pp_light_"


if [[ -n "$roi" ]]; then
  echo "Using ROI and drizzle for processing lights"
  $sirils/cropSeq.sh "$lightsPath" "$currentSeq" "$roi"
  currentSeq="cropped_$currentSeq"
fi


if [[ -z "$session" ]]; then
  drizzle=${roi:+"-drizzle"}
  $sirils/registerSeqWithOptions.sh "$lightsPath" "$currentSeq" "$drizzle"
  currentSeq="r_$currentSeq"

  $sirils/stackSeqWithRejection.sh "$lightsPath" "$currentSeq" "addscale" "$outputStack"
fi


good "**** Success ****"
if [[ -z "$session" ]]; then
  echo "Final stack $imagingPath/Stacks/$stackName"
else
  echo "preprocessed lights are in $lightsPath"
fi
end=$(date -u +'%s')
runtime=$(( end - start ))
echo "   elapsed time: $(date -d@$runtime -u +'%H:%M:%S')"
