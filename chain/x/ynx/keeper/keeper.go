package keeper

import (
	"context"

	"cosmossdk.io/collections"
	storetypes "cosmossdk.io/core/store"

	"github.com/cosmos/cosmos-sdk/codec"

	authkeeper "github.com/cosmos/cosmos-sdk/x/auth/keeper"
	bankkeeper "github.com/cosmos/cosmos-sdk/x/bank/keeper"
	mintkeeper "github.com/cosmos/cosmos-sdk/x/mint/keeper"

	feemarketkeeper "github.com/cosmos/evm/x/feemarket/keeper"
	evmkeeper "github.com/cosmos/evm/x/vm/keeper"

	ynxtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"
)

type Keeper struct {
	cdc          codec.BinaryCodec
	storeService storetypes.KVStoreService
	authority    string

	accountKeeper authkeeper.AccountKeeper
	bankKeeper    bankkeeper.Keeper
	mintKeeper    mintkeeper.Keeper

	evmKeeper       *evmkeeper.Keeper
	feeMarketKeeper feemarketkeeper.Keeper

	Schema          collections.Schema
	Params          collections.Item[ynxtypes.Params]
	SystemConfig    collections.Item[ynxtypes.SystemConfig]
	SystemContracts collections.Item[ynxtypes.SystemContracts]
}

func NewKeeper(
	cdc codec.BinaryCodec,
	storeService storetypes.KVStoreService,
	authority string,
	accountKeeper authkeeper.AccountKeeper,
	bankKeeper bankkeeper.Keeper,
	mintKeeper mintkeeper.Keeper,
	evmKeeper *evmkeeper.Keeper,
	feeMarketKeeper feemarketkeeper.Keeper,
) Keeper {
	sb := collections.NewSchemaBuilder(storeService)

	k := Keeper{
		cdc:            cdc,
		storeService:   storeService,
		authority:      authority,
		accountKeeper:  accountKeeper,
		bankKeeper:     bankKeeper,
		mintKeeper:     mintKeeper,
		evmKeeper:      evmKeeper,
		feeMarketKeeper: feeMarketKeeper,
		Params:          collections.NewItem(sb, ynxtypes.ParamsKey, "params", codec.CollValue[ynxtypes.Params](cdc)),
		SystemConfig:    collections.NewItem(sb, ynxtypes.SystemConfigKey, "system_config", codec.CollValue[ynxtypes.SystemConfig](cdc)),
		SystemContracts: collections.NewItem(sb, ynxtypes.SystemContractsKey, "system_contracts", codec.CollValue[ynxtypes.SystemContracts](cdc)),
	}

	schema, err := sb.Build()
	if err != nil {
		panic(err)
	}
	k.Schema = schema

	return k
}

func (k Keeper) GetAuthority() string { return k.authority }

func (k Keeper) GetParams(ctx context.Context) (ynxtypes.Params, error) {
	return k.Params.Get(ctx)
}

