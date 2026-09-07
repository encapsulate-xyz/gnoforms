#!/usr/bin/env bash
# Print a -gas-fee that clears the current block gas price with headroom.
#
#   deploy/gasfee.sh <gas-wanted> [remote] [headroom-multiplier]
#
# Pearl prices gas dynamically (auth/gasprice moves block to block; it went
# 17 -> 191 -> 232 ugnot/1000gas within minutes of two heavy deploys), so a
# fixed fee gets rejected with "insufficient fees". -gas-fee is the total
# paid, so headroom on the price costs nothing unless the price actually rises.
set -euo pipefail
GW="${1:?gas-wanted}"; REMOTE="${2:-https://rpc.pearl.testnets.gno.land:443}"; MULT="${3:-1.7}"
RAW=$(/usr/bin/curl -s -m 20 "$REMOTE/abci_query?path=%22auth/gasprice%22&data=0x")
python3 - "$GW" "$MULT" <<PY
import sys, json, base64, math
gw=int(sys.argv[1]); mult=float(sys.argv[2])
r=json.loads('''$RAW''', strict=False)['result']['response']
b=r.get('ResponseBase', r); j=json.loads(base64.b64decode(b['Data']).decode())
gas=int(j['gas']); amt=int(''.join(c for c in j['price'] if c.isdigit()))
per1000=amt*1000/gas
fee=math.ceil(gw*per1000/1000*mult)
print(f"block price: {per1000:.0f} ugnot/1000gas  ->  -gas-wanted {gw} -gas-fee {fee}ugnot  (x{mult} headroom)")
PY
