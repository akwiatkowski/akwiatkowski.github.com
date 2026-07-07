package views

import "strconv"

// formatThousands renders a non-negative integer with non-breaking spaces as
// thousands separators (Polish convention), e.g. 15234 → "15 234". Used for
// the big totals in the homepage hero so they stay readable at a glance.
func formatThousands(n int) string {
	digits := strconv.Itoa(n)
	if len(digits) <= 3 {
		return digits
	}
	var out []byte
	for i, d := range []byte(digits) {
		if i > 0 && (len(digits)-i)%3 == 0 {
			out = append(out, "\u00a0"...) // NBSP keeps the number on one line
		}
		out = append(out, d)
	}
	return string(out)
}
