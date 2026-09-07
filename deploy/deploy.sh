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
# 1. Simulate. -simulate only never broadcasts, so the fee attached here is not
#    paid — but the ante handler still requires the account to be ABLE to pay
#    it (after reserving the deposit cap). So size the ceiling from the balance:
#    the biggest gas-wanted whose fee fits in ~70% of what is spendable.
DEPOSIT_CAP=15000000   # ugnot; a 100KB realm deposits ~10.6 GNOT
BAL=$(/usr/bin/curl -s -m 20 "$REMOTE/abci_query?path=%22bank/balances/$("$GNOKEY" list 2>/dev/null | sed -nE "s/.* $KEY \(local\) - addr: (g1[a-z0-9]+).*/\1/p" | head -1)%22&data=0x" \
  | python3 -c "import sys,json,base64; r=json.loads(sys.stdin.read(),strict=False)['result']['response']; b=r.get('ResponseBase',r); v=base64.b64decode(b['Data']).decode().strip().strip('\"') if b.get('Data') else '0ugnot'; print(''.join(c for c in v if c.isdigit()) or 0)")
PRICE=$("$(dirname "$0")/gasfee.sh" 1000000 "$REMOTE" 1 | sed -E 's/block price: ([0-9]+).*/\1/')
SIM_GW=$(( (BAL - DEPOSIT_CAP) * 7 / 10 * 1000 / PRICE ))
[ "$SIM_GW" -gt 300000000 ] && SIM_GW=300000000
[ "$SIM_GW" -ge 80000000 ] || { echo "balance ${BAL}ugnot only covers a ${SIM_GW}-gas ceiling at ${PRICE}ugnot/1000gas — top up from the faucet or wait for the price to fall"; exit 1; }
SIM_FEE=$("$(dirname "$0")/gasfee.sh" "$SIM_GW" "$REMOTE" 1.0 | sed -E 's/.*-gas-fee ([0-9]+ugnot).*/\1/')
echo "--- simulate (balance ${BAL}ugnot, price ${PRICE}/1000gas -> ceiling $SIM_GW, unpaid) ---"
SIM_OUT=$("$GNOKEY" maketx addpkg -pkgpath "$PKGPATH" -pkgdir "$STAGE" \
  -gas-fee "$SIM_FEE" -gas-wanted "$SIM_GW" -max-deposit "${DEPOSIT_CAP}ugnot" \
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
  -gas-fee "$FEE" -gas-wanted "$GW" -max-deposit "${DEPOSIT_CAP}ugnot" \
  -chainid "$CHAIN" -remote "$REMOTE" -broadcast "$KEY"
echo "deployed: https://${REMOTE#https://rpc.}" | sed 's/:443//'
