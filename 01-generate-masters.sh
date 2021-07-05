#!/usr/bin/env bash

set -u

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { echo "$1" >&2; exit 1; }


hash jq 2>/dev/null || die "Missing dependency: jq";

dir="$(dirname "$0")"


# Convert NEF to FITS (no demosaicing)

# master bias:
#   * stacking with median algorithm (or Winsorized with rejection <0.5%)
#   * no normalisation
# master dark:
#   * stacking with median algorithm (or Winsorized with rejection <0.5%)
#   * no normalisation
# master flat:
#   * subtract master bias
#   * stacking with median algorithm (or Winsorized with rejection <0.5%)
#   * multiplicated normalisation

# lights:
#   * use cosmetic correction
#   * cfa, debayer, equalize_cfa
#   * stacking: average stacking with rejection, winsorized sigma clipping sigma low/hi 4/3


#                                                                 LIGHTS
# DARKS                /-> sub()* -> sum()                           | -> sub()
# BIASES      -> sum()                                               | -> sub()
# FLATS               \-> sub()           /-> sub()    -> sum()      | -> div()
# DARKFLATS            \-> sub()  -> sum()                           |
#                                                                    |-> register() -> stack()
#
# * only subtract masterBias from darks if dark optimisation is used

info "\n---- Parsing initial config"
config=$(cat ./config.json)
echo "Initial config:"
echo "$config"

lightDir=$(<<<$config jq -r '.lightDir // empty')
noBias=$(<<<$config jq -r '.noBias // empty')
noFlat=$(<<<$config jq -r '.noFlat // empty')
noDark=$(<<<$config jq -r '.noDark // empty')
biasesDir=$(<<<$config jq -r '.biasDir // empty')
flatsDir=$(<<<$config jq -r '.flatDir // empty')
darksDir=$(<<<$config jq -r '.darkDir // empty')
masterBias=$(<<<$config jq -r '.masterBias // empty')
masterFlat=$(<<<$config jq -r '.masterFlat // empty')
masterDark=$(<<<$config jq -r '.masterDark // empty')

setConfig () {
    cfg="$1"
    name="$2"
    value="$3"

    <<<$cfg jq ".$name = \"$value\""
}



info "\n---- Generating masters"
if [[ -n "$biasesDir" ]]; then
    info "\n---- Generating master bias"
    $dir/siril-processing/convertAndStackWithRejectionAndNoNorm.sh \
        "$biasesDir" "bias_" "master-bias" || die "Failed to generate master bias";
    masterBias="$biasesDir/master-bias.fit"

    config=$(setConfig "$config" "masterBias" "$masterBias")
    good "Created master bias $masterBias"
fi


if [[ -n "$flatsDir" ]]; then
    info "\n---- Generating master flat"
    if [[ -z $masterBias ]]; then
        echo "WARNING generating master flat without using master bias"
        $dir/siril-processing/convertAndStack.sh \
            -d "$flatsDir" -s "flat_" -a "rej" -n "-norm=mul" -o "master-flat" || die "Failed to generate master flat";
    else
        bias="$(realpath --relative-to "$flatsDir" "$masterBias")"
        echo "Using calibrating flats with bias $bias"
        $dir/siril-processing/convertAndPreprocess.sh \
            -d "$flatsDir" -s "flat_" -- "'-bias=$bias'" || die "Failed to preprocess flats";
        $dir/siril-processing/stack.sh \
            -d "$flatsDir" -s "pp_flat_" -n "-norm=mul" -o "master-flat" || die "Failed to stack flats";
    fi
    masterFlat="$flatsDir/master-flat.fit"

    config=$(setConfig "$config" "masterFlat" "$masterFlat")
    good "Created master flat $masterFlat"
fi


if [[ -n "$darksDir" ]]; then
    info "\n---- Generating master dark"
    if [[ -n $masterBias ]]; then
        echo "Not subtracting master bias from master dark"
        echo "Light frames SHOULD NOT BE callibrated with master bias unless dark optimisation is used"
    fi

    $dir/siril-processing/convertAndStack.sh \
        -d "$darksDir" -s "dark_" -a rej -n "-nonorm" -o "master-dark" || die "Failed to generate master dark";
    masterDark="$darksDir/master-dark.fit"

    config=$(setConfig "$config" "masterDark" "$masterDark")
    good "Created master dark $masterFlat"
fi

echo "Updated config with generated masters:"
echo "$config" | tee .config.json

