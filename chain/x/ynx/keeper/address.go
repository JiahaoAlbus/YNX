package keeper

import (
	"fmt"
	"strings"

	"github.com/ethereum/go-ethereum/common"

	sdk "github.com/cosmos/cosmos-sdk/types"
)

func parseAnyAddress(_ sdk.Context, addr string) (sdk.AccAddress, error) {
	addr = strings.TrimSpace(addr)
	if addr == "" {
		return nil, fmt.Errorf("empty address")
	}

	// bech32 (cosmos-style)
	if strings.HasPrefix(addr, sdk.GetConfig().GetBech32AccountAddrPrefix()) {
		acc, err := sdk.AccAddressFromBech32(addr)
		if err != nil {
			return nil, err
		}
		return acc, nil
	}

	// 0x hex (EVM-style)
	if common.IsHexAddress(addr) {
		eth := common.HexToAddress(addr)
		return sdk.AccAddress(eth.Bytes()), nil
	}

	return nil, fmt.Errorf("unsupported address format: %q", addr)
}

