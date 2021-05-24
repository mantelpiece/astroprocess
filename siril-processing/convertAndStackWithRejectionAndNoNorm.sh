#!/usr/bin/env bash


good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }

dir=$(dirname "$0")


path="${1?}"
seqName="${2?}"
output="${3?}"

script="requires 0.99.9
convertraw ${seqName}
stack ${seqName} rej 3 3 -nonorm -out=$output.fit"


trap 'rm -f ${seqName}*' EXIT
if ! "$dir/sirilWrapper.sh" "$path" "$script"; then
    die "Siril processing failed";
fi
