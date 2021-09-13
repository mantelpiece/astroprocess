#!/usr/bin/env bash

set -u

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { echo "$1" >&2; exit 1; }
usage () { die "usage: $0 -c config-file"; }

hash jq 2>/dev/null || die "Missing dependency: jq";

dir="$(dirname "$0")"

configFile=
dryrun=
while getopts "c:D" i; do
    case "$i" in
        c) configFile="$OPTARG" ;;
        D) dryrun="dryrun" ;;
        *) usage ;;
    esac
done
[[ -n $configFile ]] || usage;
[[ -r $configFile ]] || die "Config has not been generated - run 00-config.sh and 01-generate-masters.sh";

if [[ -n $dryrun ]]; then
    info "\n--- Running as dryrun"
    export AP_DRYRUN="AP_DRYRUN"
fi


info "\n---- Configuring calibration"
calibration=
lightDir=$(<config.json jq -r '.lightDir')

masterBias=$(<config.json jq -r '.masterBias // empty')
masterFlat=$(<config.json jq -r '.masterFlat // empty')
masterDark=$(<config.json jq -r '.masterDark // empty')

stackName=
fullPath=$(realpath $lightDir)
imagingDate=${fullPath##*/LIGHT}
sansDate=${fullPath%/*}
targetName=${sansDate##*/}
processingDate=$(date +'%Y%m%dT%H%M')
stackName="stack_${targetName}_${imagingDate}_${processingDate}"
outputStack="../Stacks/${stackName}"
mkdir -p "$lightDir/../Stacks"

if [[ -n $masterDark ]]; then
    relativeMasterDark="$(realpath --relative-to=$lightDir $masterDark)"
    echo "Using master dark (path relative to lights directory): $relativeMasterDark"
    calibration="$calibration -dark=$relativeMasterDark"
elif [[ -n $masterBias ]]; then
    relativeMasterBias="$(realpath --relative-to=$lightDir $masterBias)"
    echo "Using master bias (path relative to lights directory): $relativeMasterBias"
    calibration="$calibration -bias=$relativeMasterBias"
else
    echo "Warning: not calibrating with either a master dark or a master bias"
fi

if [[ -n $masterFlat ]]; then
    relativeMasterFlat="$(realpath --relative-to=$lightDir $masterFlat)"
    echo "Using master flat (path relative to lights directory): $relativeMasterFlat"
    calibration="$calibration -flat=$relativeMasterFlat"
fi


info "\n---- Pre-processing light subs"

currentSeq="light_"
if ! $dir/siril-processing/convertAndPreprocess.sh \
        -d $lightDir -s $currentSeq -- $calibration -equalize_cfa -debayer -stretch; then
    rm -f ${lightDir}/{light_,pp_}*.fit
    die "Failed to preprocess lights"
fi
rm -f ${lightDir}/light_*.fit
currentSeq="pp_$currentSeq"

# exit


info "\n---- Registering preprocessed subs"
if ! $dir/siril-processing/register.sh -d "$lightDir" -s "$currentSeq"; then
    rm -f ${lightDir}/{light_,pp_,r_pp}*.fit
    die "Failed to register light subs"
fi
rm -f ${lightDir}/{light_,pp_}*.fit
currentSeq="r_$currentSeq"


info "\n---- Stacking registered subs"
if ! $dir/siril-processing/stack.sh -d "$lightDir" -r "5 5" -s "$currentSeq" -n "addscale" -o "$outputStack"; then
    rm -f ${lightDir}/{light_,pp_,r_pp}*.fit
    die "Failed to stack lights"
fi
rm -f ${lightDir}/{light_,pp_,r_pp}*.fit
