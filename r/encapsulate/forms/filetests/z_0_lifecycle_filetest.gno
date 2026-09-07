// PKGPATH: gno.land/r/demo/main

// One full pass: create, render the fillable form, respond, render the
// table and the CSV. The rendered output is the product, so it is printed.

package main

import (
	"testing"

	"gno.land/r/encapsulate/forms"
)

const (
	owner address = "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"
	bob   address = "g1w4ek2u3jta047h6lta047h6lta047h6l9huexc"
)

func main(cur realm) {
	testing.SetHeight(500)
	testing.SetRealm(testing.NewUserRealm(owner))
	id := forms.Create(cross(cur),
		"Valoper questionnaire",
		"The six questions r/gnops/valopers asks, as fields.",
		"Validator name|Networks and AuM|Digital presence|Contact|Why gno.land?|Contributions",
		"text|textarea|text|text|textarea|textarea",
		"1|1|0|1|1|0",
		"",
		true, 0,
	)

	println("--- form page ---")
	println(forms.Render(id))

	testing.SetRealm(testing.NewUserRealm(bob))
	forms.Submit(cross(cur), id,
		"Encapsulate", "50 chains, mixed AuM", "encapsulate.xyz", "ops@example.com",
		"Equal-weight PoC valset", "", "", "")

	println("--- responses ---")
	println(forms.Render(id + "/responses"))

	println("--- csv ---")
	println(forms.Render(id + "/responses.csv"))
}

// Output:
// --- form page ---
// # Valoper questionnaire
// The six questions r/gnops/valopers asks, as fields.
//
// **Status:** open · **Responses:** 0 · **Owner:** `g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5` · one response per address
//
// [View responses](/r/encapsulate/forms:0000001/responses) · [CSV](/r/encapsulate/forms:0000001/responses.csv)
//
// ## Respond
// <gno-form exec="Submit">
// <gno-input name="id" value="0000001" readonly="true" description="Form ID" />
// <gno-input name="a1" placeholder="Validator name *" description="Validator name *" required="true" />
// <gno-textarea name="a2" placeholder="Networks and AuM *" rows="4" required="true" />
// <gno-input name="a3" placeholder="Digital presence" description="Digital presence" />
// <gno-input name="a4" placeholder="Contact *" description="Contact *" required="true" />
// <gno-textarea name="a5" placeholder="Why gno.land? *" rows="4" required="true" />
// <gno-textarea name="a6" placeholder="Contributions" rows="4" />
// </gno-form>
//
// ### Owner actions
// [Close]($help&func=Close&id=0000001) · [Withdraw my response]($help&func=Withdraw&id=0000001)
//
// --- responses ---
// # Valoper questionnaire — responses
// 1 response(s). [Back to form](/r/encapsulate/forms:0000001) · [CSV](/r/encapsulate/forms:0000001/responses.csv)
//
// | # | From | Height | Validator name | Networks and AuM | Digital presence | Contact | Why gno.land? | Contributions |
// | --- | --- | --- | --- | --- | --- | --- | --- | --- |
// | 0000001 | g1w4ek2u…uexc | 500 | Encapsulate | 50 chains, mixed AuM | encapsulate.xyz | ops@example.com | Equal-weight PoC valset |  |
//
//
//
// --- csv ---
// ```csv
// "response_id","author","height","Validator name","Networks and AuM","Digital presence","Contact","Why gno.land?","Contributions"
// "0000001","g1w4ek2u3jta047h6lta047h6lta047h6l9huexc","500","Encapsulate","50 chains, mixed AuM","encapsulate.xyz","ops@example.com","Equal-weight PoC valset",""
//
// ```
