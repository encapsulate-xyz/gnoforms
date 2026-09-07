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
// # Valoper questionnaire — responses
// 1 response(s). [Back to form](/r/encapsulate/forms:0000001) · [CSV](/r/encapsulate/forms:0000001/responses.csv)
//
// | # | From | Height | Validator name | Networks and AuM | Digital presence | Contact | Why gno.land? | Contributions |
// | --- | --- | --- | --- | --- | --- | --- | --- | --- |
// | 0000001 | g1w4ek2u…uexc | 500 | Encapsulate | 50 chains, mixed AuM | encapsulate.xyz | ops@example.com | Equal-weight PoC valset |  |
//
//
//
// ```csv
// "response_id","author","height","Validator name","Networks and AuM","Digital presence","Contact","Why gno.land?","Contributions"
// "0000001","g1w4ek2u3jta047h6lta047h6lta047h6l9huexc","500","Encapsulate","50 chains, mixed AuM","encapsulate.xyz","ops@example.com","Equal-weight PoC valset",""
//
// ```
//
// func should abort with message containing:	"form title cannot be empty"
// 	Actual abort value:	"this function must be called by a user account" - empty title
// func should abort with message containing:	"a form needs at least one field"
// 	Actual abort value:	"this function must be called by a user account" - no fields
// func should abort with message containing:	"a form can have at most 8 fields"
// 	Actual abort value:	"this function must be called by a user account" - too many fields
// func should abort with message containing:	"labels, kinds and required must describe the same number of fields"
// 	Actual abort value:	"this function must be called by a user account" - spec mismatch
// func should abort with message containing:	"field kind must be one of text, textarea, number, select"
// 	Actual abort value:	"this function must be called by a user account" - bad kind
// func should abort with message containing:	"a select field needs at least one option"
// 	Actual abort value:	"this function must be called by a user account" - select without options
// func should abort with message containing:	"field label cannot be empty"
// 	Actual abort value:	"this function must be called by a user account" - empty label
// func should abort with message containing:	"deadline must be a future chain height or 0"
// 	Actual abort value:	"this function must be called by a user account" - deadline in the past
// func should abort with message containing:	"form title is too long"
// 	Actual abort value:	"this function must be called by a user account" - title too long
// func should abort with message containing:	"owner"
// 	Actual abort value:	"this function must be called by a user account"
// func should abort with message containing:	"form is closed"
// 	Actual abort value:	"this function must be called by a user account"
// func should abort with message containing:	"form is already open"
// 	Actual abort value:	"this function must be called by a user account"
// func should abort with message containing:	"owner"
// 	Actual abort value:	"this function must be called by a user account"
// func should abort with message containing:	"form deadline has passed"
// 	Actual abort value:	"this function must be called by a user account"
// func should abort with message containing:	"form deadline has passed"
// 	Actual abort value:	"this function must be called by a user account"
// func should abort with message containing:	"required field is empty"
// 	Actual abort value:	"this function must be called by a user account" - missing required
// func should abort with message containing:	"value is not one of the select options"
// 	Actual abort value:	"this function must be called by a user account" - not an option
// func should abort with message containing:	"answer exceeds the field's maximum length"
// 	Actual abort value:	"this function must be called by a user account" - answer too long
// func should abort with message containing:	"more answers than the form has fields"
// 	Actual abort value:	"this function must be called by a user account" - too many answers
// func should abort with message containing:	"field expects a number"
// 	Actual abort value:	"this function must be called by a user account"
// func should abort with message containing:	"this address has already responded to this form"
// 	Actual abort value:	"this function must be called by a user account"
// func should abort with message containing:	"no response from this address to withdraw"
// 	Actual abort value:	"this function must be called by a user account"
// func should abort with message containing:	"no response from this address to withdraw"
// 	Actual abort value:	"this function must be called by a user account"
// func should abort with message containing:	"form is closed"
// 	Actual abort value:	"this function must be called by a user account"
// unexpected output:
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
// # Valoper questionnaire — responses
// 1 response(s). [Back to form](/r/encapsulate/forms:0000001) · [CSV](/r/encapsulate/forms:0000001/responses.csv)
//
// | # | From | Height | Validator name | Networks and AuM | Digital presence | Contact | Why gno.land? | Contributions |
// | --- | --- | --- | --- | --- | --- | --- | --- | --- |
// | 0000001 | g1w4ek2u…uexc | 500 | Encapsulate | 50 chains, mixed AuM | encapsulate.xyz | ops@example.com | Equal-weight PoC valset |  |
//
//
//
// ```csv
// "response_id","author","height","Validator name","Networks and AuM","Digital presence","Contact","Why gno.land?","Contributions"
// "0000001","g1w4ek2u3jta047h6lta047h6lta047h6l9huexc","500","Encapsulate","50 chains, mixed AuM","encapsulate.xyz","ops@example.com","Equal-weight PoC valset",""
//
// ```
