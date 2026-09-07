package forms

import (
	"strconv"
	"strings"
	"testing"

	"gno.land/p/nt/uassert/v0"
)

const (
	alice address = "g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5"
	bob   address = "g1w4ek2u3jta047h6lta047h6lta047h6l9huexc"
	carol address = "g1dmt3sa5ucvecxuhf3j6ne5r0e3z4x7h6c03xc0"
)

// newForm creates a three-field form as alice and returns its ID.
func newForm(cur realm, t *testing.T) string {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(alice))

	return Create(cross(cur),
		uniqueSlug("valoper-questionnaire"),
		"Valoper questionnaire", "Six questions the registry asks.",
		"Name|Why gno.land?|Server type",
		"text|textarea|select",
		"1|1|0",
		"||cloud,on-prem,data-center",
		false, 0,
	)
}

// slugs are unique per realm and realm state is shared across this test file,
// so each form gets a fresh one.
var slugSeq int

func uniqueSlug(base string) string {
	slugSeq++
	return base + "-" + strconv.Itoa(slugSeq)
}

func TestCreateStoresTheForm(cur realm, t *testing.T) {
	before := FormCount()
	id := newForm(cur, t)

	uassert.Equal(t, before+1, FormCount())

	f, ok := GetForm(id)
	uassert.True(t, ok)
	uassert.Equal(t, id, f.ID)
	uassert.True(t, strings.HasPrefix(id, "valoper-questionnaire-"))
	uassert.Equal(t, "Valoper questionnaire", f.Title)
	uassert.Equal(t, alice.String(), f.Owner().String())
	uassert.Equal(t, 3, len(f.Fields))
	uassert.Equal(t, string(KindSelect), string(f.Fields[2].Kind))
	uassert.Equal(t, 3, len(f.Fields[2].Options))
	uassert.True(t, f.Fields[0].Required)
	uassert.False(t, f.Fields[2].Required)
	uassert.True(t, f.IsOpen(1))
}

func TestCreateRejectsBadSpecs(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewUserRealm(alice))

	cases := []struct {
		name                                  string
		slug, title, labels, kinds, req, opts string
		deadline                              int64
		want                                  string
	}{
		{"empty slug", "", "T", "A", "text", "1", "", 0, ErrBadSlug.Error()},
		{"slug too short", "ab", "T", "A", "text", "1", "", 0, ErrBadSlug.Error()},
		{"slug uppercase", "Bad-Slug", "T", "A", "text", "1", "", 0, ErrBadSlug.Error()},
		{"slug with spaces", "bad slug", "T", "A", "text", "1", "", 0, ErrBadSlug.Error()},
		{"slug with slash", "bad/slug", "T", "A", "text", "1", "", 0, ErrBadSlug.Error()},
		{"slug double hyphen", "bad--slug", "T", "A", "text", "1", "", 0, ErrBadSlug.Error()},
		{"slug leading hyphen", "-bad", "T", "A", "text", "1", "", 0, ErrBadSlug.Error()},
		{"empty title", "ok-slug", "", "A", "text", "1", "", 0, ErrEmptyTitle.Error()},
		{"no fields", "ok-slug", "T", "", "", "", "", 0, ErrNoFields.Error()},
		{"too many fields", "ok-slug", "T", "1|2|3|4|5|6|7|8|9", "text|text|text|text|text|text|text|text|text", "0|0|0|0|0|0|0|0|0", "", 0, ErrTooManyFields.Error()},
		{"spec mismatch", "ok-slug", "T", "A|B", "text", "1|1", "", 0, ErrFieldSpecMismatch.Error()},
		{"bad kind", "ok-slug", "T", "A", "date", "0", "", 0, ErrBadFieldKind.Error()},
		{"select without options", "ok-slug", "T", "A", "select", "0", "", 0, ErrSelectNoOptions.Error()},
		{"empty label", "ok-slug", "T", " ", "text", "0", "", 0, ErrEmptyLabel.Error()},
		{"deadline in the past", "ok-slug", "T", "A", "text", "0", "", 1, ErrBadDeadline.Error()},
		{"title too long", "ok-slug", strings.Repeat("x", MaxTitleLen+1), "A", "text", "0", "", 0, ErrTitleTooLong.Error()},
	}

	testing.SetHeight(100)

	for _, tc := range cases {
		before := FormCount()
		c := tc
		uassert.AbortsContains(t, cur, c.want, func(cur realm) {
			testing.SetRealm(testing.NewUserRealm(alice))
			Create(cross(cur), c.slug, c.title, "", c.labels, c.kinds, c.req, c.opts, false, c.deadline)
		}, c.name)
		uassert.Equal(t, before, FormCount(), "rejected create must write nothing: "+c.name)
	}
}

func TestCreateRequiresAUserCaller(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/demo/someapp"))

	uassert.AbortsContains(t, cur, ErrNotUserCall.Error(), func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm("gno.land/r/demo/someapp"))
		Create(cross(cur), "code-realm", "T", "", "A", "text", "0", "", false, 0)
	})
}

func TestSlugMustBeUnique(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewUserRealm(alice))
	slug := uniqueSlug("dup")
	Create(cross(cur), slug, "First", "", "A", "text", "0", "", false, 0)

	before := FormCount()
	uassert.AbortsContains(t, cur, ErrSlugTaken.Error(), func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(bob))
		Create(cross(cur), slug, "Second", "", "A", "text", "0", "", false, 0)
	})
	uassert.Equal(t, before, FormCount())
}

func TestCloseReopenAndOwnership(cur realm, t *testing.T) {
	id := newForm(cur, t)

	// bob is not the owner
	testing.SetRealm(testing.NewUserRealm(bob))
	uassert.AbortsContains(t, cur, "owner", func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(bob))
		Close(cross(cur), id)
	})

	testing.SetRealm(testing.NewUserRealm(alice))
	Close(cross(cur), id)
	f, _ := GetForm(id)
	uassert.True(t, f.Closed)
	uassert.False(t, f.IsOpen(1))

	uassert.AbortsContains(t, cur, ErrFormClosed.Error(), func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(alice))
		Close(cross(cur), id)
	})

	Reopen(cross(cur), id)
	f, _ = GetForm(id)
	uassert.False(t, f.Closed)
	uassert.AbortsContains(t, cur, ErrFormOpen.Error(), func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(alice))
		Reopen(cross(cur), id)
	})

	TransferOwnership(cross(cur), id, bob)
	f, _ = GetForm(id)
	uassert.Equal(t, bob.String(), f.Owner().String())

	// alice can no longer close it; bob can
	uassert.AbortsContains(t, cur, "owner", func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(alice))
		Close(cross(cur), id)
	})
	testing.SetRealm(testing.NewUserRealm(bob))
	Close(cross(cur), id)
}

func TestDeadlineClosesTheForm(cur realm, t *testing.T) {
	testing.SetHeight(1000)
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Create(cross(cur), uniqueSlug("deadline"), "Deadline form", "", "A", "text", "0", "", false, 1010)

	f, _ := GetForm(id)
	uassert.True(t, f.IsOpen(1000))
	uassert.True(t, f.IsOpen(1009))
	uassert.False(t, f.IsOpen(1010))

	testing.SetHeight(1010)
	uassert.AbortsContains(t, cur, ErrDeadlinePassed.Error(), func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(alice))
		Submit(cross(cur), id, "late", "", "", "", "", "", "", "")
	})

	// cannot be reopened past the deadline either
	Close(cross(cur), id)
	uassert.AbortsContains(t, cur, ErrDeadlinePassed.Error(), func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(alice))
		Reopen(cross(cur), id)
	})
}

func TestUnknownForm(cur realm, t *testing.T) {
	_, ok := GetForm("nope")
	uassert.False(t, ok)
	uassert.Equal(t, 0, ResponseCount("nope"))

	testing.SetRealm(testing.NewUserRealm(alice))
	uassert.AbortsContains(t, cur, ErrFormNotFound.Error(), func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(alice))
		Close(cross(cur), "nope")
	})
}
