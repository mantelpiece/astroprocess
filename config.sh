#!/usr/bin/env bash

die () { echo "$1" >&2; exit 1; }

set -eo pipefail


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
        *) die "NOPE" ;;
    esac
done

lightsDir="$userLights/${subDirs[light]}"
if [[ -z "$userLights" || ! -d "$lightsDir" ]]; then
    die "Lights dir $lightsDir not found"
fi
echo "lightsDir=\"$lightsDir\""

if [[ -n $userFlats ]]; then
    inputDir="$userFlats"
    masterType="flat"
    subDir="${subDirs[$masterType]}"
    dir="$inputDir/$subDir"

    if [[ ! -d "$dir" ]]; then
        die "Directory $dir not found"
    fi

    if [[ -r "$dir/master-$masterType.fit" ]]; then
        master="$dir/master-$masterType.fit"
        echo "master${masterType^}=\"$master\""
    else
        echo "${masterType}Dir=\"$dir\""
    fi
fi

if [[ -n $userDarks ]]; then
    inputDir="$userDarks"
    masterType="dark"
    subDir="${subDirs[$masterType]}"
    dir="$inputDir/$subDir"

    if [[ ! -d "$dir" ]]; then
        die "Directory $dir not found"
    fi

    if [[ -r "$dir/master-$masterType.fit" ]]; then
        master="$dir/master-$masterType.fit"
        echo "master${masterType^}=\"$master\""
    else
        echo "${masterType}Dir=\"$dir\""
    fi
fi

if [[ -n $userBiases ]]; then
    inputDir="$userBiases"
    masterType="bias"
    subDir="${subDirs[$masterType]}"
    dir="$inputDir/$subDir"

    if [[ ! -d "$dir" ]]; then
        die "Directory $dir not found"
    fi

    if [[ -r "$dir/master-$masterType.fit" ]]; then
        master="$dir/master-$masterType.fit"
        echo "master${masterType^}=\"$master\""
    else
        echo "${masterType}Dir=\"$dir\""
    fi
fi

