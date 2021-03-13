#!/usr/bin/env bash

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }

[[ -d "./tests" ]] || { die "Run from astroprocess dir"; }
hash colordiff >&2 || { die "Missing dep: colordiff"; }


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


isError=
runTest () {
  local theBin="$scriptDir/../configure-stacking.sh"
  local title="$1"
  local testDir="$2"
  local stackArgs="${3:-""}"

  local cmd="$theBin -i $testDir $stackArgs"
  local snapshotFile="$testDir/snapshot.txt"

  [[ -r "$snapshotFile" ]] || { die "Missing snapshot for test $cmd"; }

  echo ""
  info "Running test: $title"
  local output=
  if ! output=$($cmd); then
    errr "Script errored out"
    return
  fi

  local diff=$(cdiff <(echo "$output") $snapshotFile)

  if [[ -n $updateSnapshots && -n "$diff" ]]; then
    echo "Updating snapshot for $cmd"
    $cmd > $snapshotFile
    return
  fi

  if [[ -z "$diff" ]]; then
    good "Pass"
  else
    isError="yes"
    errr "Fail - output did not match snapshot"

    info "Output:"
    $cmd
    echo
    info "<actual, >expected"
    echo "$diff"
    exit 1
  fi
}

theBin="$scriptDir/../stack.sh"
# Test that default calibration directories within imaging root are used
runTest "All calibration masters exist" "./tests/has-masters"
runTest "No masters exist, raw subs in default locations" "./tests/no-masters"
runTest "All masters exist flat master" "./tests/no-flats-master"
runTest "No flat or bias master" "./tests/no-flats-biases-masters"
runTest "No bias master" "./tests/no-biases-master"

# Test specifying calibration frame dirs to be used
runTest "Specific flats directory" \
    "./tests/specific-flats-dir" "-f ./tests/no-flats-master/Flats"

# Test specifying calibration master to be used
runTest "Precreated bias master" \
    "./tests/precreated-biases-master" \
    "-b ./tests/_precreated/Biases/master-bias-iso800.fit"

runTest "Precreated master flat" \
  "./tests/precreated-flats-master" \
  "-f ./tests/_precreated/Flats/master-flat-iso800.fit"

runTest "Precreated dark and flat masters" \
  "./tests/precreated-masters" \
  "-f ./tests/_precreated/Flats/master-flat-iso800.fit -d ./tests/_precreated/Darks/master-dark-iso800.fit"


echo ""
[[ -z "$isError" ]] || errr "Test cases failed" && good "Much success!"
