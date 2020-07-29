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

updateSnapshots=
while getopts "u" i; do
  case "$i" in
    u) updateSnapshots="true" ;;
    -) break ;;
    ?) usage ;;
    *) usage ;;
  esac
done


runTest () {
  local theBin="$scriptDir/../stack.sh"
  local testDir="$1"
  local stackArgs="${2:-""}"

  local cmd="$theBin -i $testDir $stackArgs"
  local snapshotFile="$testDir/snapshot.txt"

  [[ -r "$snapshotFile" ]] || { die "Missing snapshot for test $cmd"; }

  echo ""
  info "Running test: $cmd"
  local diff=$(cdiff <($cmd) $snapshotFile)

  if [[ -n $updateSnapshots && -n "$diff" ]]; then
    echo "Updating snapshot for $cmd"
    $cmd > $snapshotFile
    return
  fi

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
# Test that default calibration directories within imaging root are used
runTest "./tests/has-masters"
runTest "./tests/no-masters"
runTest "./tests/no-flats-master"
runTest "./tests/no-flats-biases-masters"
runTest "./tests/no-biases-master"

# Test specifying calibration frame dirs to be used
runTest "./tests/specific-flats-dir" "-f ./tests/no-flats-master/Flats"



# runTest "./tests/precreated-flats-master"


echo ""
good "Done"
