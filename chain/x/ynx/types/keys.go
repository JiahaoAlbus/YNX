package types

import "cosmossdk.io/collections"

var (
	ParamsKey          = collections.NewPrefix(0)
	SystemConfigKey    = collections.NewPrefix(1)
	SystemContractsKey = collections.NewPrefix(2)
)

const (
	ModuleName = "ynx"
	StoreKey   = ModuleName
)

