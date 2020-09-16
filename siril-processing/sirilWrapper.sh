if hash siril-cli 2>/dev/null; then
  sirilBin="siril-cli"
elif hash siril 2>/dev/null; then
  sirilBin="siril"
else
  die "Missing dep: siril"
fi

siril_w () ( $sirilBin -s <(echo "$*"); )
