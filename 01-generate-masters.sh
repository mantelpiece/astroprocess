#!/usr/bin/env bash


die () { echo "$1" >&2; exit 1; }


:${noFlats=""}
:${masterFlat=""}

# Convert NEF to FITS (no demosaicing)

# master bias:
#   * stacking with median algorithm (or Winsorized with rejection <0.5%)
#   * no normalisation
# master dark:
#   * stacking with median algorithm (or Winsorized with rejection <0.5%)
#   * no normalisation
# master dark:
#   * subtract master bias
#   * stacking with median algorithm (or Winsorized with rejection <0.5%)
#   * multiplicated normalisation

# lights:
#   * use cosmetic correction
#   * cfa, debayer, equalize_cfa
#   * stacking: average stacking with rejection, winsorized sigma clipping sigma low/hi 4/3

if [[ -z $noFlats && -z $masterFlat ]]; then
    if [[ -z $masterBias ]]; then
        true
    fi
fi


