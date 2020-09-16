#!/usr/bin/env bash

set -euo pipefail

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }


dir=$(dirname $0)
. $dir/sirilWrapper.sh

path="${1?}"
seqName="${2?}"
cropSpec="${3?}"

script="seqcrop $seqName $cropSpec"

(
  cd "$path" || die "Failed to cd into path $path";
  info "running siril with script:
$script";
  if ! siril_w "$script"; then
    rm -f cropped_${seqName}*
    die "Siril processing failed";
  fi
  rm -f ${seqName}*
)
