#!/usr/bin/env bash

set -u

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }
usage () { die "usage: $0 -d subs-dir -s sequence-name -o output-file [-n normalisation] [-a algorithm] [-r rejection]"; }

dir=$(dirname "$0")


subsDir=
sequenceName=
outputFile=
algorithm="rej"
rejection="3 3"
normalisation="-nonorm"
while getopts "d:s:o:n:a:r:" i; do
    case "$i" in
        d) subsDir="${OPTARG}" ;;
        s) sequenceName="${OPTARG}" ;;
        o) outputFile="${OPTARG}" ;;
        n) normalisation="-norm=${OPTARG}" ;;
        a) algorithm="${OPTARG}" ;;
        r) rejection="${OPTARG}" ;;
        -) break ;;
        ?) usage ;;
        *) usage ;;
    esac
done
[[ -n $subsDir ]] || usage;
[[ -n $sequenceName ]] || usage;
[[ -n $outputFile ]] || usage;

good "Stacking subs..."


script="requires 1.0.0
stack $sequenceName $algorithm $rejection $normalisation -out=$outputFile.fit"


trap 'rm -f $subsDir/{${sequenceName}*,*.seq}' EXIT
if ! "$dir/sirilWrapper.sh" "$subsDir" "$script"; then
    die "Siril processing failed";
fi
