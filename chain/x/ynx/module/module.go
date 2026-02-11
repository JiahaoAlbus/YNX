package module

import (
	"context"
	"encoding/json"
	"fmt"

	"cosmossdk.io/core/appmodule"

	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/codec"
	cdctypes "github.com/cosmos/cosmos-sdk/codec/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/types/module"

	gwruntime "github.com/grpc-ecosystem/grpc-gateway/runtime"

	ynxkeeper "github.com/JiahaoAlbus/YNX/chain/x/ynx/keeper"
	ynxtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"
)

const ConsensusVersion = 1

var (
	_ module.AppModuleBasic = AppModule{}
	_ module.HasGenesis     = AppModule{}
	_ module.HasServices    = AppModule{}

	_ appmodule.AppModule       = AppModule{}
	_ appmodule.HasBeginBlocker = AppModule{}
)

type AppModuleBasic struct {
	cdc codec.Codec
}

func (AppModuleBasic) Name() string { return ynxtypes.ModuleName }

func (AppModuleBasic) RegisterLegacyAminoCodec(cdc *codec.LegacyAmino) {
	ynxtypes.RegisterLegacyAminoCodec(cdc)
}

func (AppModuleBasic) RegisterInterfaces(r cdctypes.InterfaceRegistry) {
	ynxtypes.RegisterInterfaces(r)
}

func (AppModuleBasic) RegisterGRPCGatewayRoutes(_ client.Context, _ *gwruntime.ServeMux) {}

type AppModule struct {
	AppModuleBasic
	keeper ynxkeeper.Keeper
}

func NewAppModule(cdc codec.Codec, k ynxkeeper.Keeper) AppModule {
	return AppModule{
		AppModuleBasic: AppModuleBasic{cdc: cdc},
		keeper:         k,
	}
}

func (am AppModule) IsOnePerModuleType() {}

func (am AppModule) IsAppModule() {}

func (am AppModule) RegisterServices(cfg module.Configurator) {
	ynxtypes.RegisterMsgServer(cfg.MsgServer(), ynxkeeper.NewMsgServerImpl(am.keeper))
	ynxtypes.RegisterQueryServer(cfg.QueryServer(), ynxkeeper.NewQueryServerImpl(am.keeper))
}

func (am AppModule) DefaultGenesis(cdc codec.JSONCodec) json.RawMessage {
	return cdc.MustMarshalJSON(ynxtypes.DefaultGenesis())
}

func (am AppModule) ValidateGenesis(cdc codec.JSONCodec, _ client.TxEncodingConfig, bz json.RawMessage) error {
	var gs ynxtypes.GenesisState
	if err := cdc.UnmarshalJSON(bz, &gs); err != nil {
		return fmt.Errorf("failed to unmarshal %s genesis state: %w", ynxtypes.ModuleName, err)
	}
	return gs.Validate()
}

func (am AppModule) InitGenesis(ctx sdk.Context, cdc codec.JSONCodec, data json.RawMessage) {
	var gs ynxtypes.GenesisState
	cdc.MustUnmarshalJSON(data, &gs)
	am.keeper.InitGenesis(ctx, &gs)
}

func (am AppModule) ExportGenesis(ctx sdk.Context, cdc codec.JSONCodec) json.RawMessage {
	gs := am.keeper.ExportGenesis(ctx)
	return cdc.MustMarshalJSON(gs)
}

func (AppModule) ConsensusVersion() uint64 { return ConsensusVersion }

func (am AppModule) BeginBlock(ctx context.Context) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	return am.keeper.SplitInflationToTreasury(sdkCtx)
}

