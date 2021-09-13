#!/usr/bin/env bash

die () { echo "$1" >&2; exit 1; }
usage () { die "usage: $0 -l lights-dir -c config-file [-d darks-dir] [-f flats-dir] [-b biases-dir]"; }


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
configFile=
forceRegeneration=
while getopts "Fl:d:f:b:c:" i; do
    case "$i" in
        l) userLights="${OPTARG%/}" ;;
        d) userDarks="${OPTARG%/}" ;;
        f) userFlats="${OPTARG%/}" ;;
        F) forceRegeneration="forceRegeneration" ;;
        b) userBiases="${OPTARG%/}" ;;
        c) configFile="$OPTARG" ;;
        *) usage ;;
    esac
done
[[ -d $userLights ]] || usage
[[ -r $configFile ]] || usage

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

    if [[ -n $forceRegeneration ]] && [[ $masterType != "bias" ]]; then
        echo "\"${masterType}Dir\": \"$dir\""

    elif [[ -r "$dir/master-$masterType.fit" ]]; then
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

if ! biasesConfig=$(configureSubframes "$userBiases" "bias"); then
    die "Failed to config biases"
fi
if ! flatsConfig=$(configureSubframes "$userFlats" "flat"); then
    die "Failed to config flats"
fi
if ! darksConfig=$(configureSubframes "$userDarks" "dark"); then
    die "Failed to config darks"
fi


# Output config as JSON
tee $configFile <<EOF
{
    $lightConfig,
    $biasesConfig,
    $flatsConfig,
    $darksConfig
}
EOF
