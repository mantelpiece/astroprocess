#!/usr/bin/env bash

die () { echo "$1" >&2; exit 1; }
usage () { die "usage: $0 -l lights-dir [-d darks-dir] [-f flats-dir] [-b biases-dir]"; }


# shellcheck disable=SC2016
: 'Input
target: $NAME
imagingDate: $IMAGING_DATE

flats: $FLAT_DATE
darks: $DARK_DATE
biases: $ISO



Output:
Lights: $NAME/$DATE/LIGHT
Darks: /_Darks/$DATE/DARK
Flats: /_Flats/$DATE/FLAT
Biases: /_Biases/$ISO/master-flat.fit
'
declare -A subDirs=( [dark]="DARK" [flat]="FLAT" [light]="LIGHT" [darkflat]="DARKFLAT" [bias]="BIAS" )

userLights=
userDarks=
userFlats=
userBiases=
while getopts "l:d:f:b:" i; do
    case "$i" in
        l) userLights="${OPTARG%/}" ;;
        d) userDarks="${OPTARG%/}" ;;
        f) userFlats="${OPTARG%/}" ;;
        b) userBiases="${OPTARG%/}" ;;
        *) usage ;;
    esac
done
[[ -d $userLights ]] || usage

configureSubframes () {
    local inputDir=$1
    local masterType=$2
    local subDir="${subDirs[$masterType]}"
    local dir="$inputDir/$subDir"

    if [[ -z "$inputDir" ]]; then
        echo "\"no${masterType^}\": true"
        return
    fi

    if [[ ! -d "$dir" ]]; then
        die "$masterType directory '$dir' not found"
    fi

    if [[ -r "$dir/master-$masterType.fit" ]]; then
        master="$dir/master-$masterType.fit"
        echo "\"master${masterType^}\": \"$master\""
    else
        echo "\"${masterType}Dir\": \"$dir\""
    fi
}

if [[ -z $userLights ]]; then
    die "Must specify lights dir"
else
    lightConfig=$(configureSubframes "$userLights" "light")
fi

biasesConfig=$(configureSubframes "$userBiases" "bias")
flatsConfig=$(configureSubframes "$userFlats" "flat")
darksConfig=$(configureSubframes "$userDarks" "dark")


# Output config as JSON
cat <<EOF
{
    $lightConfig,
    $biasesConfig,
    $flatsConfig,
    $darksConfig
}
EOF
