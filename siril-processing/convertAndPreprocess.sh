#!/usr/bin/env bash

set -u


good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }
usage () { die "usage: $0 -d subs-dir -s sequence-name -- PREPROCESS-OPTIONS:[-bias=bias-master|-flat=flat-master|-dark=dark-master|-cfa|-debayer|-equalize_cfa|-stretch]"; }

dir=$(dirname "$0")


subsDir=
sequenceName=
subsky=
while getopts "d:s:" i; do
    case "$i" in
        d) subsDir="${OPTARG}" ;;
        s) sequenceName="${OPTARG}" ;;
        -) break ;;
        ?) usage ;;
        *) usage ;;
    esac
done
shift $(($OPTIND - 1))

[[ -n $subsDir ]] || usage;
[[ -n $sequenceName ]] || usage;

# Positional args after opt args are passed to preprocess
[[ $@ = *--subsky* ]] && subsky="subsky"
preprocessArgs="$@"

good "Converting and proprocessing subs..."

currentSeq="$sequenceName"

#
# Stage: preprocess
#
pp="pp_"
script="requires 1.0.0
convertraw $currentSeq
preprocess $currentSeq -prefix=$pp $preprocessArgs
seqstat $pp$currentSeq $pp$currentSeq.stats.csv basic"

if ! "$dir/sirilWrapper.sh" "$subsDir" "$script"; then
    rm -f $subsDir/$pp{*.fit,.seq}
    die "Siril processing failed";
fi
rm -f $subsDir/${currentSeq}{*.fit,.seq}
currentSeq="$pp$currentSeq"


#
# Stage: cropp
#
#crop="2000,1000,2000,2000"
crop=
if [[ -n "$crop" ]]; then
    pCrop="cropped_"
    if ! $dir/cropSeq.sh \
            -d $subsDir -s $currentSeq -c "$crop"; then
        rm -f $subsDir/$pCrop*.fit
        die "Failed to crop lights"
    fi

    rm -f $subsDir/$currentSeq{*.fit,.seq}

    # Rename cropped subs to pp_...
    for f in $subsDir/$pCrop*.fit; do
        mv $f ${f/$pCrop}
    done
fi


#
# Stage: Subtract sky
#
if [[ -n $subsky ]]; then
    pBkg="bkg_"

    script="requires 1.0.0
seqsubsky $currentSeq 4 -prefix=$pBkg
seqstat ${pBkg}$currentSeq ${pBkg}$currentSeq.stats.csv basic"

    if ! "$dir/sirilWrapper.sh" "$subsDir" "$script"; then
        rm -f $subsDir/$pBkg{*.fit,.seq}
        die "Siril processing failed";
    fi
    rm -f $subsDir/${currentSeq}{*.fit,.seq}

    # Rename subskyed subs to pp_...
    for f in $subsDir/$pBkg*.fit; do
        mv $f ${f/$pBkg}
    done
fi
