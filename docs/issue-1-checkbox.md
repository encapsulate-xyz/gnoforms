### Description

In a `gno-form` with an `exec` function, a checkbox the user never ticks still contributes
its `value` to the transaction. A boolean-ish parameter is therefore always "on", and there
is no way to submit "off" from the browser. Every other input type in the same form behaves
correctly.

Because a Gno function cannot accept `""` for a `bool` (`unexpected bool value ""`), such
parameters tend to be declared as strings — so this fails silently rather than loudly.

### Your environment

* gnoweb as served at `pearl.testnets.gno.land`
* Gno commit: `c4c72fdd288c757e8da0d93aae867fa479b1b15c` (tag `chain/pearl`); the JS quoted
  below is unchanged on master
* Desktop browser with the Adena extension

### Steps to reproduce

1. Deploy a realm whose `Render` emits a form with `p/jeronimoalbi/mdform`:

   ```go
   form := mdform.New("exec", "Submit")
   form.Input("name", "placeholder", "Name")
   form.Checkbox("required", "1", "description", "Required?")
   res.Write(form.String())
   ```

2. Open the page, fill in `name`, leave the checkbox untouched, submit.
3. Inspect the transaction the wallet is handed.

A form already deployed for this is at
<https://pearl.testnets.gno.land/r/nym-encapsulate001/test2>, whose index renders eight
rows of `label / kind / required / options`.

### Expected behaviour

An unticked checkbox contributes no value, as an unticked checkbox does in an ordinary HTML
form.

### Actual behaviour

It contributes its `value` attribute, indistinguishable from having been ticked.

### Logs

Transaction `5bca8a623d4d47146d2c3def47e05b3a86d538306a192f56622cab9a4e7cb657` (pearl-1,
height 269777). Five rows were filled in; rows 6-8 were left completely untouched. Decoded
arguments for those rows:

| arg | control | submitted | expected |
| --- | --- | --- | --- |
| `l6`, `l7`, `l8` | text input | `""` | `""` ✓ |
| `k6`, `k7`, `k8` | select, default `text` | `"text"` | `"text"` ✓ |
| `o6`, `o7`, `o8` | text input | `""` | `""` ✓ |
| **`r6`, `r7`, `r8`** | **checkbox, `value="1"`** | **`"1"`** | **`""`** ✗ |
| `deadline` | number input | `""` | `""` ✓ |

Untouched selects sent their default and untouched text/number inputs sent empty, so the
behaviour is specific to checkboxes.

It is not the realm's markdown, which emits no `checked`:

```
<gno-input type="checkbox" name="r6" value="1" description="Field 6 required" />
```

and not the rendered HTML, which is also unchecked — the full served tag:

```html
<input type="checkbox" id="r6_43" name="r6" value="1" aria-labelledby="desc_r6_43"
       data-action-function-target="param-input"
       data-action="change->action-function#updateAllArgs"
       data-action-function-param-value="r6" />
```

There is no `checked` anywhere on the page, so the value appears during argument collection
rather than at render time.

### Proposed solution

I traced this partway and stopped short of confirming it, so treat the mechanism as a
hypothesis and the behaviour above as the finding.

In `gno.land/pkg/gnoweb/frontend/js/controller-action-function.ts`,
`_getParamCurrentValue` does filter checkboxes by `.checked`, but `_initializeArgs` only
pushes a value when it is truthy (line 127 on master):

```ts
const paramValue = this._getParamCurrentValue(paramName);
this._params[paramName] = paramValue;
if (paramValue) this._updateArgInDOM(paramName, paramValue);
```

An unchecked box therefore never writes its empty value into the arg nodes or the execute
URL. What then supplies `"1"` is where I stopped — I did not find where those are first
populated. If that is the cause, initialising every param unconditionally (writing the
empty string rather than skipping it) would fix it.

Workaround for realm authors meanwhile: use a two-option `<select>` (`no` / `yes`).
Untouched selects submit their `selected` option correctly — verified at
<https://pearl.testnets.gno.land/r/nym-encapsulate001/test3>.
