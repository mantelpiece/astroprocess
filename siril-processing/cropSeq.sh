#!/usr/bin/env bash

set -euo pipefail


good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }
usage () { die "usage: $0 -d subs-dir -s sequence-name x,y,width,height"; }

dir=$(dirname "$0")

subsDir=
sequenceName=
cropSpec=
while getopts "d:s:c:" i; do
    case "$i" in
        d) subsDir="$OPTARG" ;;
        s) sequenceName="$OPTARG" ;;
        c) cropSpec="$OPTARG" ;;
        -) break ;;
        ?) usage ;;
        *) usage ;;
    esac
done
[[ -n $subsDir ]] || usage;
[[ -n $sequenceName ]] || usage;
[[ -n $cropSpec ]] || usage;


IFS=',' read -r x y width height <<<$cropSpec


script="requires 1.0.0
seqcrop $sequenceName $x $y $width $height"


trap 'rm -f ${sequenceName}*' EXIT
trap 'rm -f cropped_${sequenceName}*' ERR
if ! "$dir/sirilWrapper.sh" "$subsDir" "$script"; then
    die "Siril processing failed";
fi
