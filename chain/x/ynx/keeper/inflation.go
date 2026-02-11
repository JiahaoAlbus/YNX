package keeper

import (
	errorsmod "cosmossdk.io/errors"
	sdkmath "cosmossdk.io/math"

	sdk "github.com/cosmos/cosmos-sdk/types"
	errortypes "github.com/cosmos/cosmos-sdk/types/errors"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"

	ynxtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"
)

func (k Keeper) SplitInflationToTreasury(ctx sdk.Context) error {
	params, err := k.Params.Get(ctx)
	if err != nil {
		return err
	}
	if params.InflationTreasuryBps == 0 {
		return nil
	}
	if params.TreasuryAddress == "" {
		return nil
	}
	if params.InflationTreasuryBps > ynxtypes.BPSDenominator {
		return errorsmod.Wrapf(errortypes.ErrInvalidRequest, "inflation_treasury_bps out of range: %d", params.InflationTreasuryBps)
	}

	treasuryAddr, err := sdk.AccAddressFromBech32(params.TreasuryAddress)
	if err != nil {
		return errorsmod.Wrap(errortypes.ErrInvalidAddress, err.Error())
	}

	minter, err := k.mintKeeper.Minter.Get(ctx)
	if err != nil {
		return err
	}
	mintParams, err := k.mintKeeper.Params.Get(ctx)
	if err != nil {
		return err
	}

	minted := minter.BlockProvision(mintParams)
	if minted.Amount.IsZero() {
		return nil
	}

	bps := sdkmath.NewIntFromUint64(uint64(params.InflationTreasuryBps))
	amount := minted.Amount.Mul(bps).QuoRaw(ynxtypes.BPSDenominator)
	if amount.IsZero() {
		return nil
	}

	coins := sdk.NewCoins(sdk.NewCoin(minted.Denom, amount))
	return k.bankKeeper.SendCoinsFromModuleToAccount(ctx, authtypes.FeeCollectorName, treasuryAddr, coins)
}

