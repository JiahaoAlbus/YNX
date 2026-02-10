package config

import (
	clienthelpers "cosmossdk.io/client/v2/helpers"
	"cosmossdk.io/math"

	"github.com/cosmos/evm/crypto/hd"

	sdk "github.com/cosmos/cosmos-sdk/types"
)

const (
	Bech32Prefix = "ynx"

	Bech32PrefixAccAddr  = Bech32Prefix
	Bech32PrefixAccPub   = Bech32Prefix + sdk.PrefixPublic
	Bech32PrefixValAddr  = Bech32Prefix + sdk.PrefixValidator + sdk.PrefixOperator
	Bech32PrefixValPub   = Bech32Prefix + sdk.PrefixValidator + sdk.PrefixOperator + sdk.PrefixPublic
	Bech32PrefixConsAddr = Bech32Prefix + sdk.PrefixValidator + sdk.PrefixConsensus
	Bech32PrefixConsPub  = Bech32Prefix + sdk.PrefixValidator + sdk.PrefixConsensus + sdk.PrefixPublic
)

const (
	DisplayDenom  = "nyxt"
	BaseDenom     = "anyxt"
	BaseDenomUnit = 18

	// DefaultEVMChainID is the default EIP-155 chain id for local devnets.
	// Mainnet values are expected to be defined at genesis.
	DefaultEVMChainID uint64 = 9001
)

func MustGetDefaultNodeHome() string {
	defaultNodeHome, err := clienthelpers.GetNodeHomeDirectory(".ynxd")
	if err != nil {
		panic(err)
	}
	return defaultNodeHome
}

func SetBech32Prefixes(config *sdk.Config) {
	config.SetBech32PrefixForAccount(Bech32PrefixAccAddr, Bech32PrefixAccPub)
	config.SetBech32PrefixForValidator(Bech32PrefixValAddr, Bech32PrefixValPub)
	config.SetBech32PrefixForConsensusNode(Bech32PrefixConsAddr, Bech32PrefixConsPub)
}

func SetBip44CoinType(config *sdk.Config) {
	config.SetCoinType(hd.Bip44CoinType)
	config.SetPurpose(sdk.Purpose)
	config.SetFullFundraiserPath(hd.BIP44HDPath) //nolint: staticcheck
}

func RegisterDenoms() {
	if err := sdk.RegisterDenom(DisplayDenom, math.LegacyOneDec()); err != nil {
		panic(err)
	}

	if err := sdk.RegisterDenom(BaseDenom, math.LegacyNewDecWithPrec(1, BaseDenomUnit)); err != nil {
		panic(err)
	}
}
