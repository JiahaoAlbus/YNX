package keeper

import (
	"strings"
	"testing"

	ynxconfig "github.com/JiahaoAlbus/YNX/chain/config"

	sdk "github.com/cosmos/cosmos-sdk/types"
)

func TestParseAnyAddressSupportsBech32AndHex(t *testing.T) {
	cfg := sdk.GetConfig()
	ynxconfig.SetBech32Prefixes(cfg)

	bech32Addr := sdk.AccAddress(bytesRepeat(0x11, 20)).String()
	parsedBech32, err := parseAnyAddress(sdk.Context{}, bech32Addr)
	if err != nil {
		t.Fatalf("expected bech32 address to parse, got error: %v", err)
	}
	if !parsedBech32.Equals(sdk.AccAddress(bytesRepeat(0x11, 20))) {
		t.Fatal("expected parsed bech32 address to match source")
	}

	parsedHex, err := parseAnyAddress(sdk.Context{}, "0x2222222222222222222222222222222222222222")
	if err != nil {
		t.Fatalf("expected hex address to parse, got error: %v", err)
	}
	if got, want := parsedHex.String(), sdk.AccAddress(bytesRepeat(0x22, 20)).String(); got != want {
		t.Fatalf("expected parsed hex address %s, got %s", want, got)
	}
}

func TestParseAnyAddressRejectsUnsupportedFormats(t *testing.T) {
	_, err := parseAnyAddress(sdk.Context{}, "not-an-address")
	if err == nil {
		t.Fatal("expected unsupported address format error")
	}
	if !strings.Contains(err.Error(), "unsupported address format") {
		t.Fatalf("expected unsupported format error, got %v", err)
	}
}

func bytesRepeat(b byte, n int) []byte {
	out := make([]byte, n)
	for i := range out {
		out[i] = b
	}
	return out
}
