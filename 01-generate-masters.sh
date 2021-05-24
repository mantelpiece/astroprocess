#!/usr/bin/env bash


die () { echo "$1" >&2; exit 1; }


if hash siril-cli 2>/dev/null; then
  sirilBin="siril-cli"
elif hash siril 2>/dev/null; then
  sirilBin="siril"
else
  die "Missing dep: siril"
fi

noBiases=${noBiases=""}
noFlats=${noFlats=""}
masterBias=${masterBias=""}
masterFlat=${masterFlat=""}


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


:'                                                              LIGHTS
DARKS                /-> sub()* -> sum()                           | -> sub()
BIASES      -> sum()                                               | -> sub()
FLATS               \-> sub()           /-> sub()    -> sum()      | -> div()
DARKFLATS            \-> sub()  -> sum()                           |
                                                                   |-> register() -> stack()
'


if [[ -z $noBiases && -z $masterBias ]]; then
    true
fi

if [[ -z $noFlats && -z $masterFlat ]]; then
    if [[ -z $masterBias ]]; then
        true
    fi
fi


