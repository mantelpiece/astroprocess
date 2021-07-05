#!/usr/bin/env bash

info () { echo -e "\e[34m$*\e[0m"; }

die () { echo "$1" >&2; exit 1; }
usage () { die "usage: $0 dir script"; }


if hash siril-cli 2>/dev/null; then
  sirilBin="siril-cli"
elif hash siril 2>/dev/null; then
  sirilBin="siril"
else
  die "Missing dep: siril"
fi

workingDir="$1"
[[ -n $workingDir ]] || usage
script="$2"
[[ -n $script ]] || usage


echo -e "\nRunning siril:"
echo "Working dir: $workingDir"
echo "Script: $script"

echo -e "\nSiril logs:"
$sirilBin -d "$workingDir" -s <(echo "$script")
