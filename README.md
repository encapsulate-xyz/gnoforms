# gno forms

Publish a form, collect responses on chain, read them back rendered. gnoweb is the UI.

## Why

Collecting structured input on gno.land currently means a Web2 backend — the
team's own builder-funding application is a Google Form feeding a Google Sheet.
The plumbing for the on-chain version already exists and is core-built:
`p/jeronimoalbi/mdform` renders a form as Gno-flavoured markdown, and gnoweb
turns it into a real HTML form that submits a transaction. It was used by
exactly one thing. This realm is the general product on top of it.

## Use

Create a form (from gnokey or the "Create a form" link on the index page):

```sh
gnokey maketx call -pkgpath gno.land/r/nym-encapsulate001/forms -func Create \
  -args "Valoper questionnaire" \
  -args "The six questions the registry asks." \
  -args "Validator name|Networks and AuM|Digital presence|Contact|Why gno.land?|Contributions" \
  -args "text|textarea|text|text|textarea|textarea" \
  -args "1|1|0|1|1|0" \
  -args "" \
  -args true -args 0 \
  -gas-fee 1000000ugnot -gas-wanted 5000000 -broadcast -chainid pearl-1 \
  -remote https://rpc.pearl.testnets.gno.land:443 <key>
```

Then open `/r/nym-encapsulate001/forms:<id>` in gnoweb. The form is fillable there;
submitting signs a transaction with your wallet. Responses render at
`…/responses` and as CSV at `…/responses.csv`.

Field kinds: `text`, `textarea`, `number`, `select` (options comma-separated in
the fourth argument). Up to 8 fields. `true` as the seventh argument limits each
address to one response; the eighth is an optional closing chain height.

## Deploy

```sh
# register a namespace once (free). Self-service names must match nym-[a-z]{5,13}\d{3};
# short names like "encapsulate" go through a GovDAO "Register User" proposal.
gnokey maketx call -pkgpath gno.land/r/sys/namereg/v1 -func Register -args nym-encapsulate001 \
  -gas-fee 1000000ugnot -gas-wanted 45000000 -chainid pearl-1 \
  -remote https://rpc.pearl.testnets.gno.land:443 -broadcast <key>

# throwaway first
deploy/deploy.sh <key> gno.land/r/nym-encapsulate001/test

# the real path, once the browser flow has been tested
deploy/deploy.sh <key> gno.land/r/nym-encapsulate001/forms
```

Live on Pearl: https://pearl.testnets.gno.land/r/nym-encapsulate001/test

The script stages the realm source (no tests) under the given path and rewrites
the package clause to match the last path element (the VM requires it), runs a
`-simulate only` pass to size gas and the storage deposit, then broadcasts.
Deploying this realm costs ~55M gas and a ~6.8 GNOT storage deposit on Pearl.
Deployed realms are immutable — a fix is a new path (`forms/v2`), which is why
the throwaway comes first.

## What's deliberately not here

- **Private responses.** Everything on chain is public. Sealing answers needs
  client-side encryption before the transaction exists, which a realm cannot do
  through gnoweb. v2, if someone asks.
- **Owners deleting responses.** The storage refund goes to whoever deletes, so
  an owner deleting a response would receive the respondent's deposit. Owners
  close forms; respondents withdraw their own.
- **Editing a form after responses exist.** It would change what the answers
  mean.

## Layout

```
r/encapsulate/forms/
  types.gno     Field, Form, Response
  forms.gno     Create, Close, Reopen, TransferOwnership, field-spec parsing
  submit.gno    Submit, Withdraw, validation
  render.gno    index, form page (mdform), responses table, CSV
  filetests/    one full lifecycle with the rendered pages pinned
```

## Tests

```sh
gno test ./r/encapsulate/forms/
```

Every rejected `Create` and `Submit` also asserts that nothing was written.

One thing that cost time and is worth knowing: functions that authenticate via
`cur.Previous().IsUser()` must have `testing.SetRealm(testing.NewUserRealm(addr))`
called **inside** any `uassert.AbortsContains` closure — the closure runs from
uassert's frame, so a realm set outside it isn't the previous realm inside.
