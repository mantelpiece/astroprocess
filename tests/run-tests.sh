#!/usr/bin/env bash

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }

[[ -d "./tests" ]] || { die "Run from astroprocess dir"; }


function cdiff() {
  colordiff -wW 165 "$@";
}


scriptDir="$(dirname "$0")"


runTest () {
  local cmd="$1"
  local snapshotFile="$2/snapshot.txt"
  [[ -r "$snapshotFile" ]] || { die "Missing snapshot for test $cmd"; }

  info "Running test: $cmd"
  local diff=$(cdiff <($cmd) $snapshotFile)

  if [[ -z "$diff" ]]; then
    good "Pass"
  else
    errr "Fail - output did not match snapshot"

    echo "Output:"
    $cmd
    echo
    echo "$diff"
    exit 1
  fi
}

theBin="$scriptDir/../stack.sh"
runTest "$theBin ./tests/has-masters" "tests/has-masters"
runTest "$theBin ./tests/no-masters" "tests/no-masters"
runTest "$theBin ./tests/no-flats-master" "tests/no-flats-master"
runTest "$theBin ./tests/no-flats-biases-masters" "tests/no-flats-biases-masters"
runTest "$theBin ./tests/no-biases-master" "tests/no-biases-master"

runTest "$theBin ./tests/precreated-flats-master/

echo
good "Done"
