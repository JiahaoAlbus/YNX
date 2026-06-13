package types

import "testing"

func TestDefaultParamsUseZeroFounderFee(t *testing.T) {
	t.Parallel()

	params := DefaultParams()
	if params.FeeFounderBps != 0 {
		t.Fatalf("expected default founder fee bps to be 0, got %d", params.FeeFounderBps)
	}
}
