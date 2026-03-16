package exif

import "testing"

func TestInferLensName(t *testing.T) {
	tests := []struct {
		camera   string
		focal    float64
		wantLens string
		wantOK   bool
	}{
		// K-5 primes
		{"PENTAX K-5", 15, "smc PENTAX-DA 15mm F4 ED AL Limited", true},
		{"PENTAX K-5", 50, "smc PENTAX-FA Macro 50mm F2.8", true},
		{"PENTAX K-5", 70, "smc PENTAX-DA 70mm F2.4 Limited", true},
		{"PENTAX K-5", 40, "smc PENTAX-DA 40mm F2.8 Limited", true},
		{"PENTAX K-5", 35, "smc PENTAX-DA 35mm F2.4 AL", true},
		{"PENTAX K-5", 135, "Pentax SMC-A 135/2.8", true},
		// K-5 zooms
		{"PENTAX K-5", 16, "smc PENTAX-DA 16-45mm F4 ED AL", true},
		{"PENTAX K-5", 30, "smc PENTAX-DA 16-45mm F4 ED AL", true},
		{"PENTAX K-5", 200, "Sigma 150-500mm F5-6.3 APO DG OS HSM", true},
		{"PENTAX K-5", 500, "Sigma 150-500mm F5-6.3 APO DG OS HSM", true},
		// K-S2 primes
		{"PENTAX K-S2", 15, "smc PENTAX-DA 15mm F4 ED AL Limited", true},
		{"PENTAX K-S2", 70, "smc PENTAX-DA 70mm F2.4 Limited", true},
		// K-S2 zooms — Sigma 10-20 at wide end
		{"PENTAX K-S2", 10, "Sigma 10-20", true},
		{"PENTAX K-S2", 13, "Sigma 10-20", true},
		// K-S2 zooms — Sigma 17-50 in mid range
		{"PENTAX K-S2", 17, "Sigma 17-50/2.8", true},
		{"PENTAX K-S2", 28, "Sigma 17-50/2.8", true},
		// K-S2 zooms — Sigma 18-200 for tele
		{"PENTAX K-S2", 100, "Sigma 18-200 C", true},
		// K-S2 zooms — Sigma 150-500 for long tele
		{"PENTAX K-S2", 300, "Sigma 150-500mm F5-6.3 APO DG OS HSM", true},
		// K100D
		{"PENTAX K100D", 50, "smc PENTAX-FA Macro 50mm F2.8", true},
		{"PENTAX K100D", 16, "smc PENTAX-DA 16-45mm F4 ED AL", true},
		{"PENTAX K100D", 200, "Sigma 55-200mm F4-5.6 DC", true},
		// Unknown camera
		{"Nikon Z5", 50, "", false},
		// Unknown focal length for known camera
		{"PENTAX K-5", 85, "", false},
	}

	for _, tt := range tests {
		lens, ok := InferLensName(tt.camera, tt.focal)
		if ok != tt.wantOK {
			t.Errorf("InferLensName(%q, %g): ok=%v, want %v", tt.camera, tt.focal, ok, tt.wantOK)
			continue
		}
		if lens != tt.wantLens {
			t.Errorf("InferLensName(%q, %g) = %q, want %q", tt.camera, tt.focal, lens, tt.wantLens)
		}
	}
}

func TestInferLensNameCoversAllKnownFocalLengths(t *testing.T) {
	// Verify that all focal lengths actually seen in the EXIF data
	// can be resolved to a lens for each Pentax camera.
	k5Focals := []float64{15, 16, 35, 40, 50, 70, 135, 150, 170, 200, 230, 270, 310, 340, 400, 440, 500}
	for _, fl := range k5Focals {
		lens, ok := InferLensName("PENTAX K-5", fl)
		if !ok {
			t.Errorf("K-5 focal %.0fmm: no lens inferred", fl)
		} else {
			t.Logf("K-5 %.0fmm → %s", fl, lens)
		}
	}
}
