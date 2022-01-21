#!/usr/bin/env bash

set -u

die () { echo "$1" >&2; exit 1; }
good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }


scriptDir="$(realpath $(dirname "$0"))"
sirils="$scriptDir/siril-processing"


# session1="./2021-02-23/LIGHT/pp_light_*.fit"
# session2="./2021-02-26/LIGHT/pp_light_*.fit"
# session3="./2021-03-10/LIGHT/pp_light_*.fit"
# session4="./2021-03-12/LIGHT/pp_light_*.fit"
# sessions="$session1 $session2 $session3 $session4"


#
# Process CLI arguments
#
sessions=()
drizzle=
while getopts "s:d" i; do
    case "$i" in
        s) sessions+=("${OPTARG%/}") ;;
        d) drizzle="-drizzle" ;;
        -) break ;;
        ?) usage ;;
        *) usage ;;
    esac
done

# Assume current directory is TARGET
currentDir=$(pwd)
target=${currentDir##*/}

# Maybe accept target dir???
targetDir=$currentDir
processingDir="$targetDir/processing"
outputDir="$targetDir/stacks"
stackName="stack_${target}_$(date +"%Y%m%dT%H%M")"

mkdir -p "$processingDir" || die "Failed to create processing dir $processingDir"
mkdir -p "$outputDir" || die "Failed to create output dir $outputDir"


info "--- Multisession configuration"
echo "Preprocessed directory: ./$(realpath --relative-to . $processingDir)"
echo "Output stack: ./$(realpath --relative-to . $outputDir/$stackName)"

[[ -n "$drizzle" ]] && echo "Subframes will be drizzled before stacking"

totalLights=0
allSessionLightsGlobs=()
for ((i=0; i < ${#sessions[@]}; i++)); do
    session="${sessions[i]}"

    config="$session/config.json"
    [[ -r $config ]] || die "Cannot find config for session $session"

    sessionLightsGlob="$(<$config jq -r '.lightDir')/pp_light_*.fit"
    allSessionLightsGlobs+=($sessionLightsGlob)

    numSessionLights=$(ls $sessionLightsGlob | wc -l)

    echo -e "\nSession $(( i + 1 )) config:"
    echo "    preprocessed lights glob: $sessionLightsGlob"
    echo "    matching files: $numSessionLights"

    totalLights=$(( totalLights + numSessionLights ))
    if [[ $numSessionLights = 0 ]]; then
        echo "No processed lights matching glob found for session $session. Continue?"
        read -r
    fi
done

good "\n\nContinue processing (ctrl-c to cancel)?..."
read -r


info "\n--- Copying preprocessed lights to processing dir"
n=0
echo ""
for x in ${allSessionLightsGlobs[@]}; do
    [[ -f "$x" ]] || continue
    echo -e "\e[1A\e[KCopying $x ($n of $totalLights) ..."

    # ln -s "$x" "$processingDir/pp_light_$(printf '%05d' $n).fit"
    mv "$x" "$processingDir/pp_light_$(printf '%05d' $n).fit"
    n=$(( n + 1))
done


info "\n--- Registering all lights"
if ! $sirils/register.sh -d "$processingDir" -s "pp_light_" "$drizzle"; then
    die "Failed to register multisession lights"
fi


info "\n--- Stacking all lights"
if ! $sirils/stack.sh -d "$processingDir" -s "r_pp_light_" -r "5 5" -n "addscale" -o "$stackName"; then
    die "Failed to stack multisession lights"
fi


good "\n**** Success ****"
mv $processingDir/$stackName.fit $outputDir/
echo "Final stack $outputDir/$stackName"
