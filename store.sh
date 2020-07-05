#!/usr/bin/env bash


die () { echo "$1" >&2; exit 1; }
usage () { die "usage: $0 [-e] dir"; }


editsOnly=
while getopts "e" i; do
  case "$i" in
    e) editsOnly="editsOnly" ;;
    -) break ;;
    ?) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND-1))

src="$1"
[[ -n "$src" ]] || { usage; }

scriptDir="$(dirname "$0")"
destRootDir="$scriptDir"
dest="$destRootDir"

# rlptgoD - archive mode (-a)
# r - recursive
# l - copy symlinks as symlinks
# p - preserve permissions
# t - preserve times
# g - preserve group
# o - preserve owner
# D - same as --devices --specials
# C - cvs-exclude
# h - human-readable output


filterFile=$(mktemp)
[[ -f "$filterFile" ]] || { die "Failed to create temp file"; }
trap 'rm -f $filterFile' ERR EXIT
cat <<EOF >$filterFile
- [LBDF]_*.fit
- [LBDF]_*.txt
- *.xmp
- *.Description.txt
- .DS_Store
EOF

[[ -n "$editsOnly" ]] && { echo -e "- *.nef\n- *.NEF\n" >>$filterFile; }


echo "Storing $src into $dest"
if [[ "$src" =~ .*/ ]]; then
  echo "Contents of $src will be stored into folder ${dest##*/} in destination"
else
  echo "Directory "${src##*/}" will be stored to folder ${dest##*/} in destination"
fi

[[ -n "$editsOnly" ]] && { echo -e "\nSkipping raw data (NEF) files"; }

echo -e "\nFilter rules:"
cat $filterFile
echo -ne "\nContinue? (ctrl-c to cancel)..."
read -r


rsync -rtogpCh --progress --filter=". $filterFile" $src $dest
