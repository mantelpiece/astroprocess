#!/usr/bin/env bash

die () { echo "$1" >&2; exit 1; }
good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }
siril_w () { siril-cli -s <(echo "$*") >&2; }


session1="./2020-05-18/Lights/pp_light_*.fit"
session2="./2020-05-25/Lights/pp_light_*.fit"
processingDir="./Processing"

stackName="stack_$(date +"%Y-%m-%dT%R").fit"
lightsScript="register pp_light_
stack r_pp_light_ rej 3 3 -norm=addscale -out=./$stackName"


good "**** Processing config ****"

echo "Session 1:"
echo "    preprocessed lights: $session1"
echo "Session 2:"
echo "    preprocessed lights: $session2"


echo -e "\n\nProcessing"
echo -e "lights will be moved to directory $processingDir"
echo -e "\noutput stack: $stackName"
echo -e "\nprocessing script:\n$lightsScript"


echo -en "\n\n continue processing (ctrl-c to cancel)?..."
read -r throwaway



info "\n\n**** Moving preprocessed lights to working dir $outputDir"
mkdir -p $processingDir
n=0
for x in $session1 $session2; do
  # ln -s "$x" "$processingDir/pp_light_$(printf '%05d' $n).fit"
  mv "$x" "$processingDir/pp_light_$(printf '%05d' $n).fit"
  n=$(( n + 1))
done


info "\n**** Registering and stacking sessions ****"
(
  cd $processingDir
  if ! siril_w "$lightsScript"; then
    die "Siril failed during lights preprocessing"
  fi
  rm -f r_pp_light_*
  echo "Not deleting raw pp_light files"
  echo "Stack file $processingDir/$stackName"
)

info "\n**** Success ****"
mkdir -p Stacks
cp $processingDir/$stackName ./Stacks/
echo "Final stack ./Stacks/$stackName"