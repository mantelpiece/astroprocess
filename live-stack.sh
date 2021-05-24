#!/usr/bin/bash

set -eu

die () { echo "$1" >&2; exit 1; }
usage () { die "usage: $0 [-a] lights_dir
    lights_dir : directory of lights to watch for
    -a : optional, process all existing lights before watching"; }

lightsDir="$1"
[[ -d $lightsDir ]] || usage;
liveDir="$HOME/live-stack"
mkdir -p "$liveDir"


echo "Live stacking all NEF files"
echo "  raw files: $lightsDir"
echo "  live stack: $liveDir"
echo ""
echo "Stacking until cancelled (ctrl-c)"

i=1
while true; do
    processed="$liveDir/processed.txt"
    touch "$processed"
    numProcessed="$(wc -l <"$processed" | awk '{print $1}')"

    unprocessedFiles="$(grep -v -x -f "$processed" <(find "$lightsDir" -name '*.nef'))"
    numUnprocessed="$(wc -l <<<"$unprocessedFiles")"

    if [[ $numUnprocessed -lt 2 ]]; then
        echo "... waiting for new sub"
        sleep 10
        continue
    fi

    echo ""
    echo "---- Found $numUnprocessed unprocessed files ($numProcessed processed)"
    if [[ "$numProcessed" -lt 2 ]]; then
        file1=$(head -n1 <<<"$unprocessedFiles")
        file2=$(head -n2 <<<"$unprocessedFiles" | tail -n1)
        echo "Processing 2 files into fresh stack
        $file1 and
        $file2"
        echo "Copying files"
        cp "$file1" "$liveDir"/Live_00001.nef
        cp "$file2" "$liveDir"/Live_00002.nef

        toProcess="$file1
$file2"
    else
        file1=$(head -n1 <<<"$unprocessedFiles")
        echo "Appending 1 file to existing stack"
        echo "... copying $file1"
        cp "$file1" "$liveDir"/Live_00001.nef
        toProcess="$file1"
    fi
    echo "... copy complete"


    liveStackSsf="requires 0.99.9
convertraw Live_
preprocess Live_ -cfa -equalize_cfa -debayer
register pp_Live_
stack r_pp_Live_ sum -nonorm -out=Live_00002.fit
load Live_00002.fit
asinh 10
rmgreen 1
savejpg live-$(printf '%05d' $i) 100"

    echo "--- Stacking...."
    time siril-cli -s <(echo "$liveStackSsf") -d "$liveDir" >/dev/null
    echo "$toProcess" >>"$processed"
    echo "Stack complete"

    echo "---- Latest stack at $liveDir/live.jpg"
    rm "$liveDir"/*.seq "$liveDir"/r_*.fit "$liveDir"/pp_*.fit "$liveDir"/*.nef
    i=$((i+1))
done


























cp "$file1" "$liveDir"/Live_00001.nef
cp "$file2" "$liveDir"/Live_00002.nef

liveStackSsf="requires 0.99.9
convertraw Live_
preprocess Live_ -cfa -equalize_cfa -debayer
register pp_Live_
stack r_pp_Live_ sum -nonorm -out=Live_00002.fit
load Live_00002.fit
asinh 10
rmgreen
savejpg live.jpg 100"

siril-cli -s <(echo "$liveStackSsf") -d "$liveDir"
rm "$liveDir"/*.seq "$liveDir"/pp_*.fit "$liveDir"/r_*.fit
