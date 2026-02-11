package keeper

import (
	"context"

	sdk "github.com/cosmos/cosmos-sdk/types"

	ynxtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"
)

type queryServer struct {
	k Keeper
}

func NewQueryServerImpl(k Keeper) ynxtypes.QueryServer {
	return &queryServer{k: k}
}

func (q queryServer) Params(ctx context.Context, _ *ynxtypes.QueryParamsRequest) (*ynxtypes.QueryParamsResponse, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	params, err := q.k.Params.Get(sdkCtx)
	if err != nil {
		return nil, err
	}
	return &ynxtypes.QueryParamsResponse{Params: params}, nil
}

func (q queryServer) SystemContracts(ctx context.Context, _ *ynxtypes.QuerySystemContractsRequest) (*ynxtypes.QuerySystemContractsResponse, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	system, err := q.k.SystemConfig.Get(sdkCtx)
	if err != nil {
		return nil, err
	}
	contracts, err := q.k.SystemContracts.Get(sdkCtx)
	if err != nil {
		return nil, err
	}
	return &ynxtypes.QuerySystemContractsResponse{System: system, SystemContracts: contracts}, nil
}

