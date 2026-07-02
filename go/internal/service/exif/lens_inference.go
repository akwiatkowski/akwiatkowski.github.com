// Package exif — lens_inference.go provides focal-length-based lens identification
// for cameras that don't write the LensModel EXIF tag (Pentax bodies).
//
// Pentax cameras store lens info only in proprietary MakerNotes, which the Go
// EXIF library doesn't parse. Since the photographer's lens kit is known, we can
// infer the lens from (camera model, focal length) pairs.
//
// The mapping covers prime lenses (exact focal match) and zoom lenses (focal
// length falls within the zoom range). When a focal length is ambiguous between
// multiple zooms, the most commonly used lens is preferred.
package exif

// InferLensName attempts to identify the lens from camera model and focal length.
// Returns the raw EXIF-style lens string (matching keys in the lensNames dictionary)
// and true if a match is found, or ("", false) if the lens cannot be determined.
//
// This is used as a fallback when the standard LensModel EXIF tag is empty.
func InferLensName(camera string, focalLength float64) (string, bool) {
	rules, ok := lensInferenceRules[camera]
	if !ok {
		return "", false
	}

	// Try prime lenses first (exact focal length match)
	for _, rule := range rules {
		if rule.maxFocal == 0 && rule.minFocal == focalLength {
			return rule.lens, true
		}
	}

	// Try zoom lenses (focal length within range)
	for _, rule := range rules {
		if rule.maxFocal > 0 && focalLength >= rule.minFocal && focalLength <= rule.maxFocal {
			return rule.lens, true
		}
	}

	return "", false
}

type lensRule struct {
	minFocal float64 // For primes: exact focal length. For zooms: wide end.
	maxFocal float64 // For primes: 0. For zooms: tele end.
	lens     string  // Raw EXIF lens string (matches lensNames dictionary keys)
}

// lensInferenceRules maps camera models to their known lens kits.
// Rules are ordered: primes first (exact match), then zooms (range match).
// When zooms overlap, the more commonly used lens should appear first.
//
// Lens strings use the raw EXIF format so they map through the existing
// lensNames dictionary for human-readable display.
var lensInferenceRules = map[string][]lensRule{
	// Pentax K-5: mostly primes + one superzoom
	// Used ~2011-2017, primarily with Pentax Limited primes
	"PENTAX K-5": {
		// Primes (unambiguous by focal length)
		{minFocal: 15, lens: "smc PENTAX-DA 15mm F4 ED AL Limited"},
		{minFocal: 35, lens: "smc PENTAX-DA 35mm F2.4 AL"},
		{minFocal: 40, lens: "smc PENTAX-DA 40mm F2.8 Limited"},
		{minFocal: 50, lens: "smc PENTAX-FA Macro 50mm F2.8"},
		{minFocal: 70, lens: "smc PENTAX-DA 70mm F2.4 Limited"},
		{minFocal: 135, lens: "Pentax SMC-A 135/2.8"},
		// Zooms
		{minFocal: 16, maxFocal: 45, lens: "smc PENTAX-DA 16-45mm F4 ED AL"},
		{minFocal: 150, maxFocal: 500, lens: "Sigma 150-500mm F5-6.3 APO DG OS HSM"},
	},

	// Pentax K-S2: primes + multiple zooms
	// Used ~2015-2018, wider lens kit including Sigma zooms
	"PENTAX K-S2": {
		// Primes (unambiguous)
		{minFocal: 15, lens: "smc PENTAX-DA 15mm F4 ED AL Limited"},
		{minFocal: 35, lens: "smc PENTAX-DA 35mm F2.4 AL"},
		{minFocal: 40, lens: "smc PENTAX-DA 40mm F2.8 Limited"},
		{minFocal: 50, lens: "smc PENTAX-FA Macro 50mm F2.8"},
		{minFocal: 70, lens: "smc PENTAX-DA 70mm F2.4 Limited"},
		{minFocal: 135, lens: "Pentax SMC-A 135/2.8"},
		// Zooms — order matters for overlapping ranges
		{minFocal: 10, maxFocal: 14, lens: "Sigma 10-20"},          // 10-14mm: only Sigma 10-20
		{minFocal: 17, maxFocal: 45, lens: "Sigma 17-50/2.8"},      // 17-50mm: prefer Sigma 17-50 (most used)
		{minFocal: 150, maxFocal: 500, lens: "Sigma 150-500mm F5-6.3 APO DG OS HSM"},
		{minFocal: 55, maxFocal: 149, lens: "Sigma 18-200 C"},      // 55-149mm: Sigma 18-200 range
	},

	// Pentax K100D: first camera, limited kit
	// Used ~2006-2011
	"PENTAX K100D": {
		// Primes
		{minFocal: 50, lens: "smc PENTAX-FA Macro 50mm F2.8"},
		// Zooms
		{minFocal: 16, maxFocal: 45, lens: "smc PENTAX-DA 16-45mm F4 ED AL"},
		{minFocal: 55, maxFocal: 200, lens: "Sigma 55-200mm F4-5.6 DC"},
	},
}
