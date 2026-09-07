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
# 1. Simulate with a huge ceiling. -simulate only never broadcasts, so the fee
#    attached here is never paid; it only has to satisfy the mempool's minimum.
SIM_GW=300000000
SIM_FEE=$("$(dirname "$0")/gasfee.sh" "$SIM_GW" "$REMOTE" 1.05 | sed -E 's/.*-gas-fee ([0-9]+ugnot).*/\1/')
echo "--- simulate (ceiling $SIM_GW, unpaid) ---"
SIM_OUT=$("$GNOKEY" maketx addpkg -pkgpath "$PKGPATH" -pkgdir "$STAGE" \
  -gas-fee "$SIM_FEE" -gas-wanted "$SIM_GW" -max-deposit 30000000ugnot \
  -chainid "$CHAIN" -remote "$REMOTE" -broadcast -simulate only "$KEY" 2>&1 | tee /dev/stderr) || true
USED=$(printf '%s' "$SIM_OUT" | sed -nE 's/^GAS USED:[[:space:]]+([0-9]+).*/\1/p' | head -1)
[ -n "$USED" ] || { echo "simulation did not report GAS USED — aborting"; exit 1; }
printf '%s' "$SIM_OUT" | grep -q "Error" && { echo "simulation reported an error — aborting"; exit 1; }

# 2. Size the real transaction from what the simulation used: +10% gas ceiling,
#    fee = ceiling x live price x 1.15. -gas-fee is paid in full, so headroom is
#    deliberately small; if the price jumps between the two steps, just rerun.
GW=$(( USED + USED / 10 ))
FEE=$("$(dirname "$0")/gasfee.sh" "$GW" "$REMOTE" 1.15 | sed -E 's/.*-gas-fee ([0-9]+ugnot).*/\1/')
echo "--- broadcast: gas used $USED -> -gas-wanted $GW -gas-fee $FEE ---"
"$GNOKEY" maketx addpkg -pkgpath "$PKGPATH" -pkgdir "$STAGE" \
  -gas-fee "$FEE" -gas-wanted "$GW" -max-deposit 30000000ugnot \
  -chainid "$CHAIN" -remote "$REMOTE" -broadcast "$KEY"
echo "deployed: https://${REMOTE#https://rpc.}" | sed 's/:443//'
