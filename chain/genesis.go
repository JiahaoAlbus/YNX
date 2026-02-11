package ynx

import (
	"encoding/json"

	"cosmossdk.io/math"

	ynxconfig "github.com/JiahaoAlbus/YNX/chain/config"

	erc20types "github.com/cosmos/evm/x/erc20/types"
	feemarkettypes "github.com/cosmos/evm/x/feemarket/types"
	evmtypes "github.com/cosmos/evm/x/vm/types"

	minttypes "github.com/cosmos/cosmos-sdk/x/mint/types"
)

// GenesisState of the blockchain is represented here as a map of raw json
// messages key'd by an identifier string.
// The identifier is used to determine which module genesis information belongs
// to so it may be appropriately routed during init chain.
// Within this application default genesis information is retrieved from
// the ModuleBasicManager which populates json from each BasicModule
// object provided to it during init.
type GenesisState map[string]json.RawMessage

// NewEVMGenesisState returns the default genesis state for the EVM module.
//
// NOTE: for the example chain implementation we need to set the default EVM denomination,
// enable ALL precompiles, and include default preinstalls.
func NewEVMGenesisState() *evmtypes.GenesisState {
	evmGenState := evmtypes.DefaultGenesisState()
	evmGenState.Params.EvmDenom = ynxconfig.BaseDenom
	evmGenState.Params.ExtendedDenomOptions = &evmtypes.ExtendedDenomOptions{
		ExtendedDenom: ynxconfig.BaseDenom,
	}
	evmGenState.Params.ActiveStaticPrecompiles = evmtypes.AvailableStaticPrecompiles
	evmGenState.Preinstalls = evmtypes.DefaultPreinstalls

	return evmGenState
}

// NewErc20GenesisState returns the default genesis state for the ERC20 module.
func NewErc20GenesisState() *erc20types.GenesisState { return erc20types.DefaultGenesisState() }

// NewMintGenesisState returns the default genesis state for the mint module.
//
// NOTE: for the example chain implementation we are also adding a default minter.
func NewMintGenesisState() *minttypes.GenesisState {
	mintGenState := minttypes.DefaultGenesisState()
	mintGenState.Params.MintDenom = ynxconfig.BaseDenom
	mintGenState.Params.BlocksPerYear = 31_536_000 // 1s target blocks

	// v0 tokenomics: fixed 2% annual inflation.
	fixedInflation := math.LegacyNewDecWithPrec(2, 2)
	mintGenState.Minter.Inflation = fixedInflation
	mintGenState.Params.InflationRateChange = math.LegacyZeroDec()
	mintGenState.Params.InflationMin = fixedInflation
	mintGenState.Params.InflationMax = fixedInflation

	return mintGenState
}

// NewFeeMarketGenesisState returns the default genesis state for the feemarket module.
func NewFeeMarketGenesisState() *feemarkettypes.GenesisState {
	return feemarkettypes.DefaultGenesisState()
}
