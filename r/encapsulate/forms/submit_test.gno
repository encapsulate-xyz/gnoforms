package forms

import (
	"strings"
	"testing"

	"gno.land/p/nt/uassert/v0"
)

func TestSubmitStoresAnswers(cur realm, t *testing.T) {
	id := newForm(cur, t)

	testing.SetHeight(42)
	testing.SetRealm(testing.NewUserRealm(bob))
	Submit(cross(cur), id, "Bob", "Because.", "cloud", "", "", "", "", "")

	uassert.Equal(t, 1, ResponseCount(id))

	f, _ := GetForm(id)
	var got *Response
	f.responses.Iterate("", "", func(_ string, v any) bool { got = v.(*Response); return true })
	uassert.Equal(t, bob.String(), got.Author.String())
	uassert.Equal(t, int64(42), got.Height)
	uassert.Equal(t, 3, len(got.Answers))
	uassert.Equal(t, "Bob", got.Answers[0])
	uassert.Equal(t, "cloud", got.Answers[2])
}

func TestSubmitTrimsAndAllowsOptionalEmpty(cur realm, t *testing.T) {
	id := newForm(cur, t)

	testing.SetRealm(testing.NewUserRealm(bob))
	Submit(cross(cur), id, "  Bob  ", " Because. ", "", "", "", "", "", "")

	f, _ := GetForm(id)
	var got *Response
	f.responses.Iterate("", "", func(_ string, v any) bool { got = v.(*Response); return true })
	uassert.Equal(t, "Bob", got.Answers[0])
	uassert.Equal(t, "Because.", got.Answers[1])
	uassert.Equal(t, "", got.Answers[2])
}

// A rejected submission must leave no trace.
func TestSubmitRejectsAndWritesNothing(cur realm, t *testing.T) {
	id := newForm(cur, t)
	testing.SetRealm(testing.NewUserRealm(bob))

	long := strings.Repeat("x", MaxTextLen+1)

	cases := []struct {
		name string
		a    [8]string
		want string
	}{
		{"missing required", [8]string{"", "Because.", "cloud"}, ErrRequired.Error()},
		{"not an option", [8]string{"Bob", "Because.", "moon"}, ErrNotAnOption.Error()},
		{"answer too long", [8]string{long, "Because.", ""}, ErrAnswerTooLong.Error()},
		{"too many answers", [8]string{"Bob", "Because.", "", "extra"}, ErrTooManyAnswers.Error()},
	}

	for _, tc := range cases {
		c := tc
		uassert.AbortsContains(t, cur, c.want, func(cur realm) {
			testing.SetRealm(testing.NewUserRealm(bob))
			Submit(cross(cur), id, c.a[0], c.a[1], c.a[2], c.a[3], c.a[4], c.a[5], c.a[6], c.a[7])
		}, c.name)
		uassert.Equal(t, 0, ResponseCount(id), "rejected submit must write nothing: "+c.name)
	}
}

func TestSubmitValidatesNumbers(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Create(cross(cur), "Numbers", "", "Age", "number", "1", "", false, 0)

	testing.SetRealm(testing.NewUserRealm(bob))
	uassert.AbortsContains(t, cur, ErrNotANumber.Error(), func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(bob))
		Submit(cross(cur), id, "forty", "", "", "", "", "", "", "")
	})
	uassert.Equal(t, 0, ResponseCount(id))

	Submit(cross(cur), id, "40.5", "", "", "", "", "", "", "")
	uassert.Equal(t, 1, ResponseCount(id))
}

func TestOnePerAddress(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Create(cross(cur), "One each", "", "A", "text", "0", "", true, 0)

	testing.SetRealm(testing.NewUserRealm(bob))
	Submit(cross(cur), id, "first", "", "", "", "", "", "", "")
	uassert.AbortsContains(t, cur, ErrAlreadyResponded.Error(), func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(bob))
		Submit(cross(cur), id, "second", "", "", "", "", "", "", "")
	})
	uassert.Equal(t, 1, ResponseCount(id))

	// a different address is fine
	testing.SetRealm(testing.NewUserRealm(carol))
	Submit(cross(cur), id, "carol", "", "", "", "", "", "", "")
	uassert.Equal(t, 2, ResponseCount(id))
}

func TestWithdraw(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewUserRealm(alice))
	id := Create(cross(cur), "Withdrawable", "", "A", "text", "0", "", true, 0)

	testing.SetRealm(testing.NewUserRealm(bob))
	uassert.AbortsContains(t, cur, ErrNoResponse.Error(), func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(bob))
		Withdraw(cross(cur), id)
	})

	Submit(cross(cur), id, "mine", "", "", "", "", "", "", "")
	uassert.Equal(t, 1, ResponseCount(id))

	// the owner cannot withdraw someone else's response
	testing.SetRealm(testing.NewUserRealm(alice))
	uassert.AbortsContains(t, cur, ErrNoResponse.Error(), func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(alice))
		Withdraw(cross(cur), id)
	})
	uassert.Equal(t, 1, ResponseCount(id))

	testing.SetRealm(testing.NewUserRealm(bob))
	Withdraw(cross(cur), id)
	uassert.Equal(t, 0, ResponseCount(id))

	// and can respond again afterwards, even with one-per-address
	Submit(cross(cur), id, "again", "", "", "", "", "", "", "")
	uassert.Equal(t, 1, ResponseCount(id))
}

func TestSubmitToClosedForm(cur realm, t *testing.T) {
	id := newForm(cur, t)
	testing.SetRealm(testing.NewUserRealm(alice))
	Close(cross(cur), id)

	uassert.AbortsContains(t, cur, ErrFormClosed.Error(), func(cur realm) {
		testing.SetRealm(testing.NewUserRealm(bob))
		Submit(cross(cur), id, "Bob", "Because.", "", "", "", "", "", "")
	})
	uassert.Equal(t, 0, ResponseCount(id))
}
