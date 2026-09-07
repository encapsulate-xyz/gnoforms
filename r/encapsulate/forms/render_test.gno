package forms

import (
	"strings"
	"testing"

	"gno.land/p/nt/uassert/v0"
)

func TestRenderRoutes(cur realm, t *testing.T) {
	id := newForm(cur, t)

	index := Render("")
	uassert.True(t, strings.Contains(index, "Valoper questionnaire"), "index lists the form")
	uassert.True(t, strings.Contains(index, "Create a form"), "index shows create help")
	uassert.True(t, strings.Contains(index, `exec="CreateForm"`), "index renders the create form")
	uassert.True(t, strings.Contains(index, `name="slug"`) && strings.Contains(index, `name="l8"`) && strings.Contains(index, `name="onePerAddr"`), "create form maps every CreateForm parameter")

	// Regression guard for the gnoweb checkbox bug: an untouched checkbox
	// submits its value attribute, which silently made every field required.
	// The required and one-per-address controls must stay selects.
	uassert.False(t, strings.Contains(index, `type="checkbox"`), "no checkboxes in the create form")
	uassert.True(t, strings.Contains(index, `<gno-select name="r1" value="no"`), "required defaults to no")
	uassert.True(t, strings.Contains(index, `<gno-select name="onePerAddr" value="no"`), "one-per-address defaults to no")

	page := Render(id)
	uassert.True(t, strings.Contains(page, "# Valoper questionnaire"))
	uassert.True(t, strings.Contains(page, "gno-form"), "form page contains a gnoweb form")
	uassert.True(t, strings.Contains(page, `exec="Submit"`) || strings.Contains(page, "exec=Submit"), "form targets Submit")
	uassert.True(t, strings.Contains(page, `name="a1"`) || strings.Contains(page, "name=a1"), "first field maps to a1")
	uassert.True(t, strings.Contains(page, "data-center"), "select options render")
	uassert.True(t, strings.Contains(page, "Close"), "owner action present")

	empty := Render(id + "/responses")
	uassert.True(t, strings.Contains(empty, "No responses yet"))

	testing.SetRealm(testing.NewUserRealm(bob))
	Submit(cross(cur), id, "Bob", "Line one\nLine two", "on-prem", "", "", "", "", "")

	table := Render(id + "/responses")
	uassert.True(t, strings.Contains(table, "| Name |"), "table header uses field labels")
	uassert.True(t, strings.Contains(table, "Line one Line two"), "newlines flattened in table cells")
	uassert.True(t, strings.Contains(table, "on-prem"))

	csv := Render(id + "/responses.csv")
	uassert.True(t, strings.Contains(csv, `"response_id","author","height","Name","Why gno.land?","Server type"`), "csv header")
	uassert.True(t, strings.Contains(csv, `"Bob"`))
	uassert.True(t, strings.Contains(csv, bob.String()), "csv has full address")

	uassert.True(t, strings.Contains(Render("nope"), "Form not found"))
	uassert.True(t, strings.Contains(Render("nope/responses"), "Form not found"))
}

func TestRenderClosedFormHidesTheForm(cur realm, t *testing.T) {
	id := newForm(cur, t)
	testing.SetRealm(testing.NewUserRealm(alice))
	Close(cross(cur), id)

	page := Render(id)
	uassert.False(t, strings.Contains(page, "gno-form"), "closed form is not fillable")
	uassert.True(t, strings.Contains(page, "not accepting"))
	uassert.True(t, strings.Contains(page, "Reopen"))
}

func TestCSVEscapesQuotes(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Create(cross(cur), uniqueSlug("quotes"), "Quotes", "", "Say", "text", "0", "", false, 0)

	testing.SetRealm(testing.NewUserRealm(bob))
	Submit(cross(cur), id, `he said "hi", then left`, "", "", "", "", "", "", "")

	csv := Render(id + "/responses.csv")
	uassert.True(t, strings.Contains(csv, `"he said ""hi"", then left"`), "embedded quotes doubled")
}
