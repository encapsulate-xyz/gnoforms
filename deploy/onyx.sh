#!/usr/bin/env bash
# Deploy gno forms to onyx-1 and verify it end to end, asking for the gnokey
# password once.
#
#   deploy/onyx.sh [key-name]
#
# 1. deploy.sh  — simulate, then addpkg under the key's personal-address namespace
# 2. wait       — onyx-1 parks new packages until the gpao oracle enables them
# 3. smoke.sh   — create/submit/render/withdraw against the live realm
set -euo pipefail
KEY="${1:-encapsulate}"
DIR="$(cd "$(dirname "$0")" && pwd)"
GNOKEY="${GNOKEY:-$DIR/../../.toolchain/bin-v1.5.0/gnokey}"
REMOTE="https://rpc.onyx.testnets.gno.land:443"
ADDR=$("$GNOKEY" list 2>/dev/null | sed -nE "s/.* $KEY \(local\) - addr: (g1[a-z0-9]+).*/\1/p" | head -1)
[ -n "$ADDR" ] || { echo "no local gnokey key named $KEY"; exit 1; }
PKG="gno.land/r/$ADDR/forms"

if [ -z "${GNOKEY_PASSWORD:-}" ]; then
  [ -t 0 ] || { echo "needs a terminal to read the gnokey password — run it in a terminal window, not through a non-interactive shell" >&2; exit 1; }
  read -rsp "gnokey password for $KEY: " GNOKEY_PASSWORD; echo
fi
export GNOKEY_PASSWORD GNOKEY

render_ok() { /usr/bin/curl -s -m 20 "$REMOTE/abci_query?path=%22vm/qrender%22&data=0x$(printf '%s' "$PKG:" | xxd -p | tr -d '\n')" \
  | python3 -c "import sys,json;r=json.loads(sys.stdin.read(),strict=False)['result']['response'];b=r.get('ResponseBase',r);sys.exit(0 if b.get('Data') else 1)"; }

if render_ok; then
  echo "$PKG is already live — skipping deploy"
else
  "$DIR/deploy.sh" "$KEY" "$PKG"
  printf 'waiting for gpao to enable %s ' "$PKG"
  for i in $(seq 1 60); do render_ok && { echo " enabled"; break; }; printf '.'; sleep 3; done
  render_ok || { echo; echo "not enabled after 3 minutes — the package is parked; check the tx and gpao"; exit 1; }
fi

"$DIR/smoke.sh" "$KEY" "$PKG"
echo
echo "live:  https://onyx.testnets.gno.land/r/$ADDR/forms"
echo "demo:  https://onyx.testnets.gno.land/r/$ADDR/forms:demo"
