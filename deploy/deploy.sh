#!/usr/bin/env bash
# Stage the realm under any package path and deploy it to a gno.land network.
#
#   deploy/deploy.sh <key-name> <pkgpath> [chain-id] [remote]
#
#   deploy/deploy.sh encapsulate gno.land/r/g1abc.../test            # throwaway, no namespace needed
#   deploy/deploy.sh encapsulate gno.land/r/encapsulate/forms          # the real one
#
# Simulates first (-simulate only never broadcasts) to size gas and the
# storage deposit, then broadcasts for real.
#
# On pearl-1 namespace enforcement is off (vm:p/sysnames_pkgpath is unset),
# so any path works without registering a name. Mainnet may enforce it:
# register "encapsulate" via r/sys/namereg/v1.Register first there.
set -euo pipefail
KEY="${1:?key name}"; PKGPATH="${2:?package path}"
CHAIN="${3:-pearl-1}"; REMOTE="${4:-https://rpc.pearl.testnets.gno.land:443}"
GNOKEY="${GNOKEY:-$(dirname "$0")/../../.toolchain/bin/gnokey}"
SRC="$(cd "$(dirname "$0")/.." && pwd)/r/encapsulate/forms"
STAGE="$(mktemp -d)/$(basename "$PKGPATH")"
mkdir -p "$STAGE"
# copy realm source only — no tests, no filetests — and rewrite the module path
for f in "$SRC"/*.gno; do case "$f" in *_test.gno) ;; *) cp "$f" "$STAGE/";; esac; done
printf 'module = "%s"\ngno = "0.9"\n' "$PKGPATH" > "$STAGE/gnomod.toml"
echo "staged $(ls "$STAGE" | wc -l | tr -d ' ') files for $PKGPATH in $STAGE"
echo "--- simulate ---"
"$GNOKEY" maketx addpkg -pkgpath "$PKGPATH" -pkgdir "$STAGE" \
  -gas-fee 1000000ugnot -gas-wanted 50000000 -max-deposit 100000000ugnot \
  -chainid "$CHAIN" -remote "$REMOTE" -broadcast -simulate only "$KEY"
echo "--- broadcast ---"
"$GNOKEY" maketx addpkg -pkgpath "$PKGPATH" -pkgdir "$STAGE" \
  -gas-fee 1000000ugnot -gas-wanted 50000000 -max-deposit 100000000ugnot \
  -chainid "$CHAIN" -remote "$REMOTE" -broadcast "$KEY"
echo "deployed: https://${REMOTE#https://rpc.}" | sed 's/:443//'
