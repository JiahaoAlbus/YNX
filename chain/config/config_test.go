package config

import (
	"testing"

	sdk "github.com/cosmos/cosmos-sdk/types"
)

func TestSetBech32Prefixes(t *testing.T) {
	cfg := sdk.GetConfig()
	SetBech32Prefixes(cfg)

	if got, want := cfg.GetBech32AccountAddrPrefix(), Bech32PrefixAccAddr; got != want {
		t.Fatalf("expected bech32 account prefix %q, got %q", want, got)
	}
	if got, want := cfg.GetBech32ValidatorAddrPrefix(), Bech32PrefixValAddr; got != want {
		t.Fatalf("expected validator prefix %q, got %q", want, got)
	}
	if got, want := cfg.GetBech32ConsensusAddrPrefix(), Bech32PrefixConsAddr; got != want {
		t.Fatalf("expected consensus prefix %q, got %q", want, got)
	}
}

func TestMustGetDefaultNodeHome(t *testing.T) {
	t.Parallel()

	if got := MustGetDefaultNodeHome(); got == "" {
		t.Fatal("expected default node home to be non-empty")
	}
}
