#!/usr/bin/env bash

set -u

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { echo "$1" >&2; exit 1; }
usage () { die "usage: $0 -l lights-dir -b bias -d darks-dir -f flats-dir -D -F
    -l: specify lights directory
    [-bdf]: specify bias/darks/flat subs directory
    [-D]: run as dry-run
    [-F]: force regeneration of masters

    Assumes that within the specified directory, all subs are within a folder named
    LIGHT, BIAS, DARK, FLAT as appropriate"; }

hash jq 2>/dev/null || die "Missing dependency: jq";

dir="$(dirname "$0")"

dryrun=
lightsDir=
sessionConfigArgs=()
while getopts ":l:D" i; do
    case "$i" in
        D) dryrun="dryrun" ;;
        l) lightsDir="${OPTARG%/}" ;;
    esac
done

[[ -d $lightsDir ]] || { echo "Lights dir '$lightsDir' not a directory"; usage; }
configFile="$lightsDir/config.json"


if [[ -n $dryrun ]]; then
    info "\n--- Running as dryrun"
    export AP_DRYRUN="AP_DRYRUN"
fi

info "\n\n+++ 1. Configuring session"
if ! "$dir/00-config.sh" -c "$configFile" $@; then
    die "Failed to configure session processing"
fi


info "\n\n+++ 2. Generating masters"
if ! "$dir/01-generate-masters.sh" -c "$configFile"; then
    die "Failed to configure session processing"
fi


info "\n\n+++ 3. Processing lights"
if ! "$dir/02-process-lights.sh" -c "$configFile"; then
    die "Failed to configure session processing"
fi
