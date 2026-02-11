package types

import (
	"fmt"

	sdk "github.com/cosmos/cosmos-sdk/types"
)

const (
	BPSDenominator = 10_000
)

func DefaultParams() Params {
	return Params{
		FounderAddress:        "",
		TreasuryAddress:       "",
		FeeBurnBps:            4_000,
		FeeTreasuryBps:        1_000,
		FeeFounderBps:         1_000,
		InflationTreasuryBps:  3_000,
	}
}

func (p Params) Validate() error {
	if p.FounderAddress != "" {
		if _, err := sdk.AccAddressFromBech32(p.FounderAddress); err != nil {
			return fmt.Errorf("invalid founder_address: %w", err)
		}
	}

	if p.TreasuryAddress != "" {
		if _, err := sdk.AccAddressFromBech32(p.TreasuryAddress); err != nil {
			return fmt.Errorf("invalid treasury_address: %w", err)
		}
	}

	if p.FeeBurnBps > BPSDenominator {
		return fmt.Errorf("fee_burn_bps out of range: %d", p.FeeBurnBps)
	}
	if p.FeeTreasuryBps > BPSDenominator {
		return fmt.Errorf("fee_treasury_bps out of range: %d", p.FeeTreasuryBps)
	}
	if p.FeeFounderBps > BPSDenominator {
		return fmt.Errorf("fee_founder_bps out of range: %d", p.FeeFounderBps)
	}
	if sum := uint64(p.FeeBurnBps) + uint64(p.FeeTreasuryBps) + uint64(p.FeeFounderBps); sum > BPSDenominator {
		return fmt.Errorf("fee split bps must be <= %d, got %d", BPSDenominator, sum)
	}

	if p.InflationTreasuryBps > BPSDenominator {
		return fmt.Errorf("inflation_treasury_bps out of range: %d", p.InflationTreasuryBps)
	}

	return nil
}

