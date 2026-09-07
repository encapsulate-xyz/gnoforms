#!/usr/bin/env bash
# Stage the realm under any package path and deploy it to a gno.land network.
#
#   deploy/deploy.sh <key-name> <pkgpath> [chain-id] [remote]
#
#   deploy/deploy.sh encapsulate gno.land/r/nym-encapsulate001/test    # throwaway
#   deploy/deploy.sh encapsulate gno.land/r/nym-encapsulate001/forms   # the real one
#
# Simulates first (-simulate only never broadcasts) to size gas and the
# storage deposit, then broadcasts for real.
#
# Namespace enforcement is ON: register the name first via
# r/sys/namereg/v1.Register (self-service names must match nym-[a-z]{5,13}\d{3}).
set -euo pipefail
KEY="${1:?key name}"; PKGPATH="${2:?package path}"
CHAIN="${3:-pearl-1}"; REMOTE="${4:-https://rpc.pearl.testnets.gno.land:443}"
GNOKEY="${GNOKEY:-$(dirname "$0")/../../.toolchain/bin/gnokey}"
SRC="$(cd "$(dirname "$0")/.." && pwd)/r/encapsulate/forms"
STAGE="$(mktemp -d)/$(basename "$PKGPATH")"
mkdir -p "$STAGE"
# copy realm source only — no tests — rewrite the module path, and rename the
# package to the last path element: the VM rejects a mismatch (vm/errors.go:88)
NAME="$(basename "$PKGPATH")"
for f in "$SRC"/*.gno; do case "$f" in *_test.gno) ;; *) sed -e "s/^package forms\$/package $NAME/" -e "s|^// Package forms |// Package $NAME |" "$f" > "$STAGE/$(basename "$f")";; esac; done
printf 'module = "%s"\ngno = "0.9"\n' "$PKGPATH" > "$STAGE/gnomod.toml"
echo "staged $(ls "$STAGE" | wc -l | tr -d ' ') files for $PKGPATH in $STAGE"
GW=60000000
FEE=$("$(dirname "$0")/gasfee.sh" "$GW" "$REMOTE" | sed -E 's/.*-gas-fee ([0-9]+ugnot).*/\1/')
echo "using -gas-wanted $GW -gas-fee $FEE (from auth/gasprice)"
echo "--- simulate ---"
"$GNOKEY" maketx addpkg -pkgpath "$PKGPATH" -pkgdir "$STAGE" \
  -gas-fee "$FEE" -gas-wanted "$GW" -max-deposit 20000000ugnot \
  -chainid "$CHAIN" -remote "$REMOTE" -broadcast -simulate only "$KEY"
echo "--- broadcast ---"
"$GNOKEY" maketx addpkg -pkgpath "$PKGPATH" -pkgdir "$STAGE" \
  -gas-fee "$FEE" -gas-wanted "$GW" -max-deposit 20000000ugnot \
  -chainid "$CHAIN" -remote "$REMOTE" -broadcast "$KEY"
echo "deployed: https://${REMOTE#https://rpc.}" | sed 's/:443//'
