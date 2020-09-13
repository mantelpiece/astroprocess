#!/usr/bin/env bash
# Logs environment config of stacking parameters

#
# Log configuration
#
info "********    Processinging configuration    ********"
echo "Current directory: $currentDir"
echo "Imaging directory: $imagingDir"

echo
echo "Bias master:"
if [[ -z "$biasRequired" ]]; then
  echo "  Biases master not required as flats master exists"
elif [[ -z "$generateBias" ]]; then
  echo "  Using pre-existing biases master $masterBias"
else
  echo "  Biases master $masterBias not found"
  echo "  Generating biases master from directory $biasesPath"
fi


echo
echo "Flats master:"
if [[ -z "$generateFlat" ]]; then
  echo "  Using pre-existing flats master $masterFlat"
else
  echo "  Flats master $masterFlat not found"
  echo "  Generating flats master from directory $flatsPath"
fi


echo
echo "Darks master:"
if [[ -z "$generateDark" ]]; then
  echo "  Using pre-existing darks master $masterDark"
else
  echo "  Darks master $masterDark not found"
  echo "  Generating darks master from directory $darksPath"
fi


echo
echo "Processing lights:"
echo "  lights directory: $lightsPath"
