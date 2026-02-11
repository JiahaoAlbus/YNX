package keeper

import (
	"context"

	errorsmod "cosmossdk.io/errors"
	sdkmath "cosmossdk.io/math"

	sdk "github.com/cosmos/cosmos-sdk/types"
	errortypes "github.com/cosmos/cosmos-sdk/types/errors"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"

	evmtypes "github.com/cosmos/evm/x/vm/types"

	ynxtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"
)

func (k Keeper) SplitTxFee(ctx context.Context, fee sdk.Coin) error {
	if fee.Amount.IsZero() {
		return nil
	}

	params, err := k.Params.Get(ctx)
	if err != nil {
		return err
	}

	burnBps := params.FeeBurnBps
	treasuryBps := params.FeeTreasuryBps
	founderBps := params.FeeFounderBps

	if uint64(burnBps)+uint64(treasuryBps)+uint64(founderBps) > ynxtypes.BPSDenominator {
		return errorsmod.Wrapf(errortypes.ErrInvalidRequest, "fee split bps exceeds %d", ynxtypes.BPSDenominator)
	}

	sdkCtx := sdk.UnwrapSDKContext(ctx)

	feeCollectorAddr := k.accountKeeper.GetModuleAddress(authtypes.FeeCollectorName)
	if feeCollectorAddr == nil {
		return errorsmod.Wrap(errortypes.ErrLogic, "fee collector module account not set")
	}

	amount := fee.Amount
	burn := amount.Mul(sdkmath.NewIntFromUint64(uint64(burnBps))).QuoRaw(ynxtypes.BPSDenominator)
	treasury := amount.Mul(sdkmath.NewIntFromUint64(uint64(treasuryBps))).QuoRaw(ynxtypes.BPSDenominator)
	founder := amount.Mul(sdkmath.NewIntFromUint64(uint64(founderBps))).QuoRaw(ynxtypes.BPSDenominator)

	// Burn.
	if !burn.IsZero() {
		coins := sdk.NewCoins(sdk.NewCoin(fee.Denom, burn))
		if err := k.bankKeeper.SendCoinsFromModuleToModule(sdkCtx, authtypes.FeeCollectorName, evmtypes.ModuleName, coins); err != nil {
			return err
		}
		if err := k.bankKeeper.BurnCoins(sdkCtx, evmtypes.ModuleName, coins); err != nil {
			return err
		}
	}

	// Treasury.
	if !treasury.IsZero() && params.TreasuryAddress != "" {
		addr, err := sdk.AccAddressFromBech32(params.TreasuryAddress)
		if err != nil {
			return errorsmod.Wrap(errortypes.ErrInvalidAddress, err.Error())
		}
		coins := sdk.NewCoins(sdk.NewCoin(fee.Denom, treasury))
		if err := k.bankKeeper.SendCoinsFromModuleToAccount(sdkCtx, authtypes.FeeCollectorName, addr, coins); err != nil {
			return err
		}
	}

	// Founder.
	if !founder.IsZero() && params.FounderAddress != "" {
		addr, err := sdk.AccAddressFromBech32(params.FounderAddress)
		if err != nil {
			return errorsmod.Wrap(errortypes.ErrInvalidAddress, err.Error())
		}
		coins := sdk.NewCoins(sdk.NewCoin(fee.Denom, founder))
		if err := k.bankKeeper.SendCoinsFromModuleToAccount(sdkCtx, authtypes.FeeCollectorName, addr, coins); err != nil {
			return err
		}
	}

	return nil
}
