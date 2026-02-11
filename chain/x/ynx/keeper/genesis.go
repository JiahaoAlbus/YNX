package keeper

import (
	"fmt"

	sdk "github.com/cosmos/cosmos-sdk/types"

	ynxtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"
)

func (k Keeper) InitGenesis(ctx sdk.Context, data *ynxtypes.GenesisState) {
	if err := data.Validate(); err != nil {
		panic(err)
	}

	if err := k.Params.Set(ctx, data.Params); err != nil {
		panic(err)
	}
	if err := k.SystemConfig.Set(ctx, data.System); err != nil {
		panic(err)
	}
	if err := k.SystemContracts.Set(ctx, data.SystemContracts); err != nil {
		panic(err)
	}

	if !data.System.Enabled {
		return
	}

	cacheCtx, write := ctx.CacheContext()
	contracts, err := k.deploySystemContracts(cacheCtx, data.System)
	if err != nil {
		panic(err)
	}

	if err := k.SystemContracts.Set(cacheCtx, contracts); err != nil {
		panic(err)
	}

	// If treasury_address is unset, default it to the deployed treasury contract.
	params, err := k.Params.Get(cacheCtx)
	if err != nil {
		panic(err)
	}
	if params.TreasuryAddress == "" && contracts.Treasury != "" {
		params.TreasuryAddress = mustHexToBech32Acc(cacheCtx, contracts.Treasury)
		if err := k.Params.Set(cacheCtx, params); err != nil {
			panic(err)
		}
	}

	write()
}

func (k Keeper) ExportGenesis(ctx sdk.Context) *ynxtypes.GenesisState {
	params, err := k.Params.Get(ctx)
	if err != nil {
		panic(err)
	}
	system, err := k.SystemConfig.Get(ctx)
	if err != nil {
		panic(err)
	}
	contracts, err := k.SystemContracts.Get(ctx)
	if err != nil {
		panic(err)
	}

	return &ynxtypes.GenesisState{
		Params:          params,
		System:          system,
		SystemContracts: contracts,
	}
}

// mustHexToBech32Acc converts a 0x hex address into a bech32 account address using the chain's
// configured prefix.
//
// Panics on invalid input.
func mustHexToBech32Acc(ctx sdk.Context, hexAddr string) string {
	acc, err := parseAnyAddress(ctx, hexAddr)
	if err != nil {
		panic(fmt.Errorf("invalid address: %w", err))
	}
	return acc.String()
}
