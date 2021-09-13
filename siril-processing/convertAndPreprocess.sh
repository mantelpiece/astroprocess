#!/usr/bin/env bash

set -u


good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }
usage () { die "usage: $0 -d subs-dir -s sequence-name -- PREPROCESS-OPTIONS:[-bias=bias-master|-flat=flat-master|-dark=dark-master|-cfa|-debayer|-equalize_cfa|-stretch]"; }

dir=$(dirname "$0")


subsDir=
sequenceName=
while getopts "d:s:" i; do
    case "$i" in
        d) subsDir="${OPTARG}" ;;
        s) sequenceName="${OPTARG}" ;;
        -) break ;;
        ?) usage ;;
        *) usage ;;
    esac
done
shift $(($OPTIND - 1))

[[ -n $subsDir ]] || usage;
[[ -n $sequenceName ]] || usage;
# Positional args after opt args are passed to preprocess
preprocessArgs="$@"

good "\nConverting and proprocessing subs..."

script="requires 0.99.9
convertraw $sequenceName
preprocess $sequenceName $preprocessArgs"

trap 'rm -f ${sequenceName}* pp_*.seq' EXIT
if ! "$dir/sirilWrapper.sh" "$subsDir" "$script"; then
    rm -f pp_${sequenceName}*,pp_*.seq
    die "Siril processing failed";
fi
