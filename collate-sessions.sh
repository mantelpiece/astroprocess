#!/usr/bin/env bash

die () { echo "$1" >&2; exit 1; }
good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }


scriptDir="$(realpath $(dirname "$0"))"
sirils="$scriptDir/siril-processing"


session1="./2020-09-13/Lights/cropped_pp_light_*.fit"
session2="./2020-09-14/Lights/cropped_pp_light_*.fit"
session3="./2020-06-17/Lights/pp_light_*.fit"
sessions="$session1 $session2"


#
# Process CLI arguments
#
drizzle=
while getopts "d" i; do
  case "$i" in
    d) drizzle="-drizzle" ;;
    -) break ;;
    ?) usage ;;
    *) usage ;;
  esac
done

# Assume current directory is TARGET
currentDir=$(pwd)
target=${currentDir##*/}
processingDir="./Processing"
stackName="stack_${target}_$(date +"%Y-%m-%dT%H%M")"


good "**** Processing config ****"

echo "Session 1:"
echo "    preprocessed lights: $session1"
echo "Session 2:"
echo "    preprocessed lights: $session2"
echo "Session 3:"
echo "    preprocessed lights: $session3"


echo -e "\n\nProcessing"
if [[ -n "$drizzle" ]]; then
  echo -e "subframes will be drizzled before stacking"
fi
echo -e "lights will be moved to directory $processingDir"
echo -e "\noutput stack: $stackName"


echo -en "\n\ncontinue processing (ctrl-c to cancel)?..."
read -r


info "\n\n**** Moving preprocessed lights to working dir $processingDir"
mkdir -p $processingDir
n=0
for x in $sessions; do
  [[ -f "$x" ]] || continue
  # ln -s "$x" "$processingDir/pp_light_$(printf '%05d' $n).fit"
  mv "$x" "$processingDir/pp_light_$(printf '%05d' $n).fit"
  n=$(( n + 1))
done


info "\n**** Registering and stacking sessions ****"
$sirils/registerSeqWithOptions.sh "$processingDir" "pp_light_" "$drizzle"
$sirils/stackSeqWithRejection.sh "$processingDir" "r_pp_light_" "addscale" "$stackName"



info "\n**** Success ****"
mkdir -p Stacks
cp $processingDir/$stackName.fit ./Stacks/
echo "Final stack ./Stacks/$stackName"
