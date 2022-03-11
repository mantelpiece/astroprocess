#!/usr/bin/bash

set -eu

die () { echo "$1" >&2; exit 1; }
usage () { die "usage: $0 [-a] lights_dir
    lights_dir : directory of lights to watch for
    -a : optional, process all existing lights before watching"; }

lightsDir="$1"
[[ -d $lightsDir ]] || usage;
liveDir="/mnt/c/astrophotography/live-stack"
# liveDir="$HOME/live-stack"
mkdir -p "$liveDir"


echo "Live stacking all NEF files"
echo "  raw files: $lightsDir"
echo "  live stack: $liveDir"
echo ""
echo "Stacking until cancelled (ctrl-c)"

LOG="$liveDir/log.txt"


convertToFit () {
    local inputFile="$1"
    local outputFit="$2"

    cp "$inputFile" "$liveDir"

    convertFrameSsf="requires 1.0.0
setext fit
convertraw LIGHT_ -debayer"

    siril-cli -s <(echo "$convertFrameSsf") -d "$liveDir" >>$LOG || die "Failed to convert raw"
    mv "$liveDir/LIGHT_00001.fit" "$liveDir/$outputFit" || die "Failed to rename converted raw"
}


addFrameToStack () {
    echo "--- Stacking...."
    rm -f "$liveDir"/*.seq
    liveStackSsf="requires 1.0.0
setext fit
set16bits
register main
stack r_main sum -nonorm
load r_main_stacked
resample 0.5
savejpg stack"
    siril-cli -s <(echo "$liveStackSsf") -d "$liveDir" >>$LOG 2>&1 || die "Failed to stack"

    mv $liveDir/r_main_stacked.fit $liveDir/main_00001.fit || die "Failed to rename stack"
}


i=1
while true; do
    processed="$liveDir/processed.txt"
    touch "$processed"
    numProcessed="$(wc -l <"$processed" | awk '{print $1}')"

    # unprocessedFiles="$(grep -v -x -f "$processed" <(find "$lightsDir" -name 'LIGHT*.nef'))"
    unprocessedFiles=$(comm -23 <(find "$lightsDir" -name 'LIGHT*.nef') "$processed" | cut -f1 -d' ')
    numUnprocessed=0
    [[ -n $unprocessedFiles ]] && numUnprocessed="$(wc -l <<<"$unprocessedFiles")"

    echo "... waiting for new sub"
    if [[ $numUnprocessed -lt 1 ]]; then
        sleep 10
        continue
    fi

    fileToProcess=$(head -n1 <<<"$unprocessedFiles")
    echo "Processing $(basename "$fileToProcess")"
    if [[ ! -r $liveDir/main_00001.fit ]]; then
        convertToFit "$fileToProcess" main_00001.fit
        echo "$fileToProcess" >>"$processed"
    else
        convertToFit "$fileToProcess" main_00002.fit

        echo "Stacking imaging $i"
        rm -f "$liveDir"/*.seq
        addFrameToStack
        echo "$fileToProcess" >>"$processed"
    fi

    echo "Cleanup..."
    rm -f "$liveDir"/*.seq "$liveDir"/r_*.fit "$liveDir"/pp_*.fit "$liveDir"/*.nef >>$LOG
    echo ""

    i=$(( i + 1 ))
done
