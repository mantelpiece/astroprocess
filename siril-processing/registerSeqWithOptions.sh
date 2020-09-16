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
options="${3:-""}"

script="register $seqName $options"

(
  cd "$path" || die "Failed to cd into path $path";
  info "running siril with script:
$script";
  if ! siril_w "$script"; then
    rm -f $seqName* r_$seqName*
    die "Siril processing failed";
  fi
  rm -f $seqName*
)
