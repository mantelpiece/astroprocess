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
siril_w () ( $sirilBin -s <(echo "$*"); )


# Delegate stacking parameter configuration to `configure-stacking.sh`
scriptDir="$(realpath $(dirname "$0"))"
processingDate="$(date +"%Y-%m-%dT%H%M.fit")"
session=

if ! config=$("$scriptDir/configure-stacking.sh" "$@"); then
  die "Failed to configure stacking"
fi
# Set config into shell
eval $config


#
# Configuration...
#
info "**** Processing configuration ****"

#
# Master Flat
#
echo "master flat:
  .. checking $flatsPath"
if [[ -r "$masterFlat" ]]; then
  echo "  .. found $masterFlat"
else
  if [[ ! -d "$flatsPath" ]]; then
    die "  .. flats directory $flatsPath not found"
  fi
  echo "  .. no master flat found - processing $flatsPath"
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
  fi
fi


#
# Master Darks
#
echo -e "\nmaster dark:
  .. checking $darksPath"
if [[ -r "$masterDark" ]]; then
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
