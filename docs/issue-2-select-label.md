A `gno-select` renders a visible label derived from the parameter name, and a realm has no
way to override it. Users see field ids where a question should be.

### What happens

`gno.land/pkg/gnoweb/markdown/ext_forms.go:735`:

```go
label := titleCase(strings.ReplaceAll(e.Name, "_", " "))
```

Because gnoweb maps form inputs to a fixed function signature, a form with a variable
number of fields must name its parameters positionally (`a1`, `a2`, …). Users then see
**"A3 (required)"** and a **"Select an A3 (required)"** placeholder.

Live example: <https://pearl.testnets.gno.land/r/nym-encapsulate001/forms:feedback> — the
third field reads "Do responses need to be private?" above a select labelled "A3".

### Why a realm cannot fix it

`FormSelect` has no label or placeholder field, and the parser accepts only `selected`,
`description`, `readonly` and `required`. `description` renders as a separate `<div>`
above the control, so it supplements the label rather than replacing it.

Inputs and textareas avoid the problem only because they render their `placeholder`, which
selects do not accept.

### Suggestion

Either accept a `placeholder` (or `label`) attribute on `gno-select`, or fall back to
`description` before the name-derived label when one is present. `p/jeronimoalbi/mdform`
mirrors gnoweb's allowed attributes, so it would follow automatically.

Found on pearl-1 while building the same realm as #6140; `ext_forms.go:735` is unchanged
on master.
