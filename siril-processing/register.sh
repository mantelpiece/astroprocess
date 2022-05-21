#!/usr/bin/env bash

set -u

good () { echo -e "\e[32m$*\e[0m"; }
info () { echo -e "\e[34m$*\e[0m"; }
errr () { echo -e "\e[31m$*\e[0m"; }

die () { errr "${1:-""}" >&2; exit "${2:-1}"; }
usage () { die "usage: $0 -d subs-dir -s sequence-name"; }

dir=$(dirname "$0")


subsDir=
sequenceName=
drizzle=
while getopts "d:s:z" i; do
    case "$i" in
        d) subsDir="${OPTARG}" ;;
        s) sequenceName="${OPTARG}" ;;
        z) drizzle="-drizzle" ;;
        -) break ;;
        ?) usage ;;
        *) usage ;;
    esac
done
shift $(($OPTIND - 1))
[[ -n $subsDir ]] || usage;
[[ -n $sequenceName ]] || usage;

good "Registering subs..."

script="requires 1.0.0
register $sequenceName $drizzle"

trap 'rm -f $subsDir/${sequenceName}*' EXIT
if ! "$dir/sirilWrapper.sh" "$subsDir" "$script"; then
    rm -f r_${sequenceName}* r_*.seq
    die "Siril processing failed";
fi
