Title: gno-form: an unticked checkbox submits its `value` as if it were checked

---

## What happens

In a `gno-form` with an `exec` function, a checkbox the user never touches still
contributes its `value` attribute to the transaction. A boolean-ish parameter is
therefore always "on", and a user cannot send "off" from the browser.

Every other input type in the same form behaves correctly.

## Reproduction

A realm rendering a form with `p/jeronimoalbi/mdform`:

```go
form := mdform.New("exec", "Submit")
form.Input("name", "placeholder", "Name")
form.Select("kind", "text", "selected", "true")
form.Select("kind", "number")
form.Checkbox("required", "1", "description", "Required?")
res.Write(form.String())
```

Open the page, fill in `name`, leave the checkbox alone, submit. The transaction carries
`required="1"`.

## Evidence from chain

Live example: <https://pearl.testnets.gno.land/r/nym-encapsulate001/test2> — a realm whose
index renders a form for creating forms, with eight rows of
`label / kind / required / options`.

In transaction `5bca8a623d4d47146d2c3def47e05b3a86d538306a192f56622cab9a4e7cb657`
(`pearl-1`, height 269777) five rows were filled in and rows 6-8 were left completely
untouched. Decoded arguments for those three rows:

| arg | control | submitted | expected |
| --- | --- | --- | --- |
| `l6`, `l7`, `l8` | text input | `""` | `""` ✓ |
| `k6`, `k7`, `k8` | select, default `text` | `"text"` | `"text"` ✓ |
| `o6`, `o7`, `o8` | text input | `""` | `""` ✓ |
| **`r6`, `r7`, `r8`** | **checkbox, `value="1"`** | **`"1"`** | **`""`** ✗ |
| `onePerAddr` | checkbox, `value="1"` | `"1"` | `""` ✗ |
| `deadline` | number input | `""` | `""` ✓ |

Untouched selects sent their default and untouched text/number inputs sent empty, so this
is specific to checkboxes. Across the three forms created on that realm, every field came
out `required` and every form has one-response-per-address enabled — neither was chosen.

## Not the realm's markdown, and not the rendered HTML

The realm emits no `checked` attribute:

```
<gno-input type="checkbox" name="r6" value="1" description="Field 6 required" />
```

and gnoweb renders it unchecked — the full tag as served:

```html
<input type="checkbox" id="r6_43" name="r6" value="1" aria-labelledby="desc_r6_43"
       data-action-function-target="param-input"
       data-action="change->action-function#updateAllArgs"
       data-action-function-param-value="r6" />
```

There is no `checked` anywhere on the page. So the value is introduced after rendering,
during argument collection.

## Lead (unconfirmed)

In `gno.land/pkg/gnoweb/frontend/js/controller-action-function.ts`,
`_getParamCurrentValue` does filter checkboxes by `.checked`, but `_initializeArgs` only
pushes a value when it is truthy:

```ts
const paramValue = this._getParamCurrentValue(paramName);
this._params[paramName] = paramValue;
if (paramValue) this._updateArgInDOM(paramName, paramValue);
```

An unchecked box therefore never writes its empty value into the arg nodes or the
execute URL. Whether something else then supplies `"1"` is where our trail ends — we did
not find where the arg nodes and the `function-execute` action URL are first populated,
and we have not confirmed this hypothesis. The observed behaviour above is the part we
are confident about.

## Impact

Any realm using a checkbox in a `gno-form` receives its value unconditionally. Since a Gno
function cannot take `""` for a `bool` (`unexpected bool value ""`), such parameters tend
to be declared as strings — so this fails silently rather than loudly.

## Workaround

Use a two-option `<select>` (`no` / `yes`) instead of a checkbox; untouched selects submit
their `selected` option correctly.

## Environment

- `pearl-1`, gnoweb as served at `pearl.testnets.gno.land`
- realm built against `chain/pearl` (`c4c72fdd288c`)
- wallet: Adena

---

## Possible second issue, unrelated defect class

`gno-select` has no way to set its visible label. `ext_forms.go:735` derives it from the
parameter name — `titleCase(strings.ReplaceAll(e.Name, "_", " "))` — and `mdform`'s
`selectAttributes` (`description`, `readonly`, `required`, `selected`) has no
`placeholder`, so a realm cannot override it. A form whose parameters are necessarily
positional (`a1`, `a2`, …, because gnoweb maps inputs to a fixed function signature) shows
users "Select an A3 (required)". Inputs and textareas avoid this only because they render
their `placeholder`.

Suggestion: accept `placeholder` on `gno-select`, or fall back to `description` when
present, before the name-derived label.
