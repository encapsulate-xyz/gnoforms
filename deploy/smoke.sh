#!/usr/bin/env bash
# End-to-end check of a deployed gno forms realm, on chain, through gnokey.
#
#   deploy/smoke.sh <key-name> <realm-pkgpath> [chain-id] [remote]
#
# Creates a public demo form (slug "demo") if it does not exist yet, submits a
# response, checks the form page, the responses table and the CSV render, then
# withdraws the response so the demo is left open and empty for anyone to try.
# Uses GNOKEY_PASSWORD if set (deploy/onyx.sh exports it), else gnokey prompts.
set -euo pipefail
KEY="${1:?key name}"; PKG="${2:?realm pkgpath}"
CHAIN="${3:-onyx-1}"; REMOTE="${4:-https://rpc.onyx.testnets.gno.land:443}"
GNOKEY="${GNOKEY:-$(dirname "$0")/../../.toolchain/bin-v1.5.0/gnokey}"
SLUG=demo

gk() { if [ -n "${GNOKEY_PASSWORD:-}" ]; then printf '%s\n' "$GNOKEY_PASSWORD" | "$GNOKEY" "$@" -insecure-password-stdin "$KEY"; else "$GNOKEY" "$@" "$KEY"; fi; }
abci() { /usr/bin/curl -s -m 25 "$REMOTE/abci_query?path=%22$1%22&data=0x$(printf '%s' "$2" | xxd -p | tr -d '\n')" \
  | python3 -c "import sys,json,base64;r=json.loads(sys.stdin.read(),strict=False)['result']['response'];b=r.get('ResponseBase',r);print(base64.b64decode(b['Data']).decode() if b.get('Data') else '')"; }
render() { abci vm/qrender "$PKG:$1"; }
count() { abci vm/qeval "$PKG.ResponseCount(\"$SLUG\")" | grep -oE '^\([0-9]+' | tr -d '('; }
FEE=$("$(dirname "$0")/gasfee.sh" 40000000 "$REMOTE" 2 | sed -E 's/.*-gas-fee ([0-9]+ugnot).*/\1/')
call() { local fn="$1"; shift; local args=(); for a in "$@"; do args+=(-args "$a"); done
  gk maketx call -pkgpath "$PKG" -func "$fn" "${args[@]}" -gas-fee "$FEE" -gas-wanted 40000000 \
    -max-deposit 5000000ugnot -chainid "$CHAIN" -remote "$REMOTE" -broadcast >/dev/null; }
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; exit 1; }

echo "--- smoke test: $PKG on $CHAIN"
if render "$SLUG" | grep -q "gno-form"; then
  pass "demo form already exists"
else
  call Create "$SLUG" "Try gno forms" \
    "A live demo of gno forms on $CHAIN. Fill it in with Adena: your answers are stored on chain, and you can withdraw your response at any time to get your storage deposit back." \
    "Your name or handle|What would you use an on-chain form for?|Which network do you mainly build on?" \
    "text|textarea|select" "1|0|1" "||gno.land mainnet,onyx-1 testnet,another chain" \
    false 0
  render "$SLUG" | grep -q "gno-form" && pass "Create: form page renders a fillable gno-form" || fail "Create: form page has no gno-form"
fi
render "" | grep -q "Try gno forms" && pass "index lists the demo form" || fail "index does not list the demo form"

before=$(count); before=${before:-0}
call Submit "$SLUG" "encapsulate smoke test" "Checking the deploy end to end." "onyx-1 testnet" "" "" "" "" ""
after=$(count)
[ "$after" = $((before + 1)) ] && pass "Submit: response count $before -> $after" || fail "Submit: response count $before -> $after"
render "$SLUG/responses" | grep -q "encapsulate smoke test" && pass "responses table shows the answer" || fail "responses table missing the answer"
render "$SLUG/responses.csv" | grep -q "Checking the deploy end to end." && pass "CSV export contains the answer" || fail "CSV export missing the answer"

call Withdraw "$SLUG"
final=$(count)
[ "$final" = "$before" ] && pass "Withdraw: response count back to $final" || fail "Withdraw: response count $final, expected $before"
echo "--- all checks passed"
