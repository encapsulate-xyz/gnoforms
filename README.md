# gno forms

Publish a form, collect responses on chain, read them back rendered. gnoweb is the UI.

**Live on onyx-1:** https://onyx.testnets.gno.land/r/g1eyr3hfdcup4rr5xlcd63vc5t64a03u9kecx2v0/forms —
try it at [`forms:demo`](https://onyx.testnets.gno.land/r/g1eyr3hfdcup4rr5xlcd63vc5t64a03u9kecx2v0/forms:demo).

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
gnokey maketx call -pkgpath gno.land/r/g1eyr3hfdcup4rr5xlcd63vc5t64a03u9kecx2v0/forms -func Create \
  -args "valoper-questionnaire" \
  -args "Valoper questionnaire" \
  -args "The six questions the registry asks." \
  -args "Validator name|Networks and AuM|Digital presence|Contact|Why gno.land?|Contributions" \
  -args "text|textarea|text|text|textarea|textarea" \
  -args "1|1|0|1|1|0" \
  -args "" \
  -args true -args 0 \
  -gas-fee 100000ugnot -gas-wanted 40000000 -max-deposit 5000000ugnot -broadcast \
  -chainid onyx-1 -remote https://rpc.onyx.testnets.gno.land:443 <key>
```

The first argument is the form's slug — its ID and its URL segment: lowercase
letters, digits, single hyphens, 3–48 characters, unique per realm.

Then open `/r/g1eyr3hfdcup4rr5xlcd63vc5t64a03u9kecx2v0/forms:valoper-questionnaire` in gnoweb. The form is fillable there;
submitting signs a transaction with your wallet. Responses render at
`…/responses` and as CSV at `…/responses.csv`.

Field kinds: `text`, `textarea`, `number`, `select` (options comma-separated in
the fourth argument). Up to 8 fields. `true` as the eighth argument limits each
address to one response; the ninth is an optional closing chain height.

## Deploy

Target: **onyx-1**, the testnet on the mainnet line (gno `v1.5.0`). Build `gnokey` from
the tag the chain runs (`git checkout v1.5.0`), not from `master`.

```sh
deploy/onyx.sh <key>     # prompts for the password once: deploy, wait for approval, smoke test
```

or step by step:

```sh
deploy/deploy.sh <key> gno.land/r/<your-g1-address>/forms   # simulate, then addpkg
deploy/smoke.sh  <key> gno.land/r/<your-g1-address>/forms   # create/submit/render/withdraw on chain
```

Two things differ from the old Pearl testnet, both inherited from mainnet:

- **Namespaces are GovDAO-only.** There is no self-service `nym-` registration, so the
  realm goes under your personal-address namespace, `gno.land/{r,p}/<your g1 address>/…`,
  which any account may deploy to.
- **Code submission is `inert`.** An `addpkg` is stored parked and only goes live when
  the gpao approval oracle sends `MsgEnablePackage` — within seconds, for any package
  that typechecks against the imports already on chain. `deploy/onyx.sh` waits for it.

`deploy.sh` stages the realm source (no tests) under the given path, rewrites the package
clause to match the last path element (the VM requires it), runs a `-simulate only` pass to
size gas and the storage deposit, then broadcasts. Deployed realms are immutable — a fix is
a new path (`forms/v2`).

The realm imports the versioned library paths that ship from gno `v1.5.0` on
(`p/jeronimoalbi/mdform/v0`, `p/moul/md/v0`, `p/moul/mdtable/v0`, `p/moul/txlink/v0`,
`p/nt/avl/pager/v0`). Pearl, where it first ran at `/r/nym-encapsulate001/forms`, has
been shut down.

## Creating a form in the browser

The index page renders a form that creates forms: slug, title, description, and up to
eight rows of field label / type / required / options. Blank rows are skipped.
Submitting hands the wallet a `CreateForm` call with every argument already filled in —
nothing is typed into the wallet. `Create` (pipe-separated specs) remains for gnokey.

Every `CreateForm` parameter is a string on purpose: gnoweb submits `""` for an empty or
unticked input, and `""` is not a valid `bool` or `int64` to the VM — a `bool` parameter
would fail at simulation with `unexpected bool value ""` before the realm could say
anything useful.

## Known limitations (v1)

- Adena shows a storage deposit of 0 GNOT when its simulation fails — that's the failed
  simulation, not a free transaction.

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
