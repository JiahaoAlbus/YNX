package module

import (
	"testing"

	"github.com/cosmos/cosmos-sdk/codec"
	cdctypes "github.com/cosmos/cosmos-sdk/codec/types"

	ynxtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"
)

func TestAppModuleBasicDefaultGenesisAndValidation(t *testing.T) {
	t.Parallel()

	cdc := codec.NewProtoCodec(cdctypes.NewInterfaceRegistry())
	am := AppModuleBasic{cdc: cdc}

	if got, want := am.Name(), ynxtypes.ModuleName; got != want {
		t.Fatalf("expected module name %q, got %q", want, got)
	}

	fullModule := AppModule{AppModuleBasic: am}
	genesis := fullModule.DefaultGenesis(cdc)
	if err := fullModule.ValidateGenesis(cdc, nil, genesis); err != nil {
		t.Fatalf("expected default genesis to validate, got error: %v", err)
	}
}

func TestAppModuleConsensusVersion(t *testing.T) {
	t.Parallel()

	if got, want := (AppModule{}).ConsensusVersion(), uint64(ConsensusVersion); got != want {
		t.Fatalf("expected consensus version %d, got %d", want, got)
	}
}
