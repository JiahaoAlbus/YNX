package keeper

import (
	"context"

	errorsmod "cosmossdk.io/errors"

	sdk "github.com/cosmos/cosmos-sdk/types"
	errortypes "github.com/cosmos/cosmos-sdk/types/errors"

	ynxtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"
)

type msgServer struct {
	k Keeper
}

func NewMsgServerImpl(k Keeper) ynxtypes.MsgServer {
	return &msgServer{k: k}
}

func (s msgServer) UpdateParams(ctx context.Context, req *ynxtypes.MsgUpdateParams) (*ynxtypes.MsgUpdateParamsResponse, error) {
	if req == nil {
		return nil, errorsmod.Wrap(errortypes.ErrInvalidRequest, "empty request")
	}
	if req.Authority != s.k.authority {
		return nil, errorsmod.Wrapf(errortypes.ErrUnauthorized, "invalid authority: %s", req.Authority)
	}

	if err := req.Params.Validate(); err != nil {
		return nil, errorsmod.Wrap(errortypes.ErrInvalidRequest, err.Error())
	}

	sdkCtx := sdk.UnwrapSDKContext(ctx)
	if err := s.k.Params.Set(sdkCtx, req.Params); err != nil {
		return nil, err
	}

	return &ynxtypes.MsgUpdateParamsResponse{}, nil
}

