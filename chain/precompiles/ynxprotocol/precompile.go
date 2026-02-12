package ynxprotocol

import (
	"embed"
	"fmt"
	"math"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/vm"

	cmn "github.com/cosmos/evm/precompiles/common"

	storetypes "cosmossdk.io/store/types"

	sdk "github.com/cosmos/cosmos-sdk/types"

	ynxkeeper "github.com/JiahaoAlbus/YNX/chain/x/ynx/keeper"
	ynxtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"
)

var _ vm.PrecompiledContract = &Precompile{}

const (
	PrecompileAddress = "0x0000000000000000000000000000000000000810"

	GetParamsMethod          = "getParams"
	GetSystemContractsMethod = "getSystemContracts"
	UpdateParamsMethod       = "updateParams"
)

var (
	//go:embed abi.json
	f   embed.FS
	ABI abi.ABI
)

func init() {
	var err error
	ABI, err = cmn.LoadABI(f, "abi.json")
	if err != nil {
		panic(err)
	}
}

// Precompile exposes protocol parameter control to the EVM.
//
// Security model:
// - updateParams is restricted to the v0 timelock system contract (msg.sender).
// - reads are permissionless.
type Precompile struct {
	cmn.Precompile

	abi.ABI
	ynxKeeper ynxkeeper.Keeper
}

func NewPrecompile(ynxKeeper ynxkeeper.Keeper) *Precompile {
	return &Precompile{
		Precompile: cmn.Precompile{
			KvGasConfig:          storetypes.KVGasConfig(),
			TransientKVGasConfig: storetypes.TransientGasConfig(),
			ContractAddress:      common.HexToAddress(PrecompileAddress),
		},
		ABI:       ABI,
		ynxKeeper: ynxKeeper,
	}
}

func (p Precompile) RequiredGas(input []byte) uint64 {
	if len(input) < 4 {
		return 0
	}
	methodID := input[:4]

	method, err := p.MethodById(methodID)
	if err != nil {
		return 0
	}

	return p.Precompile.RequiredGas(input, p.IsTransaction(method))
}

func (p Precompile) Run(evm *vm.EVM, contract *vm.Contract, readonly bool) ([]byte, error) {
	return p.RunNativeAction(evm, contract, func(ctx sdk.Context) ([]byte, error) {
		return p.Execute(ctx, contract, readonly)
	})
}

func (p Precompile) Execute(ctx sdk.Context, contract *vm.Contract, readOnly bool) ([]byte, error) {
	method, args, err := cmn.SetupABI(p.ABI, contract, readOnly, p.IsTransaction)
	if err != nil {
		return nil, err
	}

	switch method.Name {
	case GetParamsMethod:
		return p.getParams(ctx, method)
	case GetSystemContractsMethod:
		return p.getSystemContracts(ctx, method)
	case UpdateParamsMethod:
		return p.updateParams(ctx, contract, method, args)
	default:
		return nil, fmt.Errorf(cmn.ErrUnknownMethod, method.Name)
	}
}

func (Precompile) IsTransaction(method *abi.Method) bool {
	switch method.Name {
	case UpdateParamsMethod:
		return true
	default:
		return false
	}
}

func (p Precompile) getParams(ctx sdk.Context, method *abi.Method) ([]byte, error) {
	params, err := p.ynxKeeper.Params.Get(ctx)
	if err != nil {
		return nil, err
	}

	founder := common.Address{}
	if params.FounderAddress != "" {
		acc, err := sdk.AccAddressFromBech32(params.FounderAddress)
		if err != nil {
			return nil, err
		}
		founder = common.BytesToAddress(acc.Bytes())
	}

	treasury := common.Address{}
	if params.TreasuryAddress != "" {
		acc, err := sdk.AccAddressFromBech32(params.TreasuryAddress)
		if err != nil {
			return nil, err
		}
		treasury = common.BytesToAddress(acc.Bytes())
	}

	return method.Outputs.Pack(
		founder,
		treasury,
		params.FeeBurnBps,
		params.FeeTreasuryBps,
		params.FeeFounderBps,
		params.InflationTreasuryBps,
	)
}

func (p Precompile) getSystemContracts(ctx sdk.Context, method *abi.Method) ([]byte, error) {
	contracts, err := p.ynxKeeper.SystemContracts.Get(ctx)
	if err != nil {
		return nil, err
	}

	return method.Outputs.Pack(
		hexToAddress(contracts.Nyxt),
		hexToAddress(contracts.Timelock),
		hexToAddress(contracts.Treasury),
		hexToAddress(contracts.Governor),
		hexToAddress(contracts.TeamVesting),
		hexToAddress(contracts.OrgRegistry),
		hexToAddress(contracts.SubjectRegistry),
		hexToAddress(contracts.Arbitration),
		hexToAddress(contracts.DomainInbox),
	)
}

func (p Precompile) updateParams(ctx sdk.Context, contract *vm.Contract, method *abi.Method, args []interface{}) ([]byte, error) {
	if len(args) != 6 {
		return nil, fmt.Errorf("invalid args length: got %d, expected 6", len(args))
	}

	founder, err := asAddress(args[0])
	if err != nil {
		return nil, err
	}
	treasury, err := asAddress(args[1])
	if err != nil {
		return nil, err
	}

	feeBurnBps, err := asUint32(args[2])
	if err != nil {
		return nil, err
	}
	feeTreasuryBps, err := asUint32(args[3])
	if err != nil {
		return nil, err
	}
	feeFounderBps, err := asUint32(args[4])
	if err != nil {
		return nil, err
	}
	inflationTreasuryBps, err := asUint32(args[5])
	if err != nil {
		return nil, err
	}

	systemContracts, err := p.ynxKeeper.SystemContracts.Get(ctx)
	if err != nil {
		return nil, err
	}

	timelock := hexToAddress(systemContracts.Timelock)
	if timelock == (common.Address{}) {
		return nil, fmt.Errorf("timelock is not configured")
	}

	caller := contract.Caller()
	if caller != timelock {
		return nil, fmt.Errorf("unauthorized caller %s (expected timelock %s)", caller.Hex(), timelock.Hex())
	}

	params := ynxtypes.Params{
		FounderAddress:       addressToBech32(founder),
		TreasuryAddress:      addressToBech32(treasury),
		FeeBurnBps:           feeBurnBps,
		FeeTreasuryBps:       feeTreasuryBps,
		FeeFounderBps:        feeFounderBps,
		InflationTreasuryBps: inflationTreasuryBps,
	}

	if err := params.Validate(); err != nil {
		return nil, err
	}

	if err := p.ynxKeeper.Params.Set(ctx, params); err != nil {
		return nil, err
	}

	return method.Outputs.Pack(true)
}

func hexToAddress(s string) common.Address {
	s = strings.TrimSpace(s)
	if !common.IsHexAddress(s) {
		return common.Address{}
	}
	return common.HexToAddress(s)
}

func addressToBech32(addr common.Address) string {
	if addr == (common.Address{}) {
		return ""
	}
	return sdk.AccAddress(addr.Bytes()).String()
}

func asAddress(v interface{}) (common.Address, error) {
	switch t := v.(type) {
	case common.Address:
		return t, nil
	case [20]byte:
		return common.Address(t), nil
	case []byte:
		if len(t) != common.AddressLength {
			return common.Address{}, fmt.Errorf("invalid address bytes length: %d", len(t))
		}
		return common.BytesToAddress(t), nil
	default:
		return common.Address{}, fmt.Errorf("unexpected address type: %T", v)
	}
}

func asUint32(v interface{}) (uint32, error) {
	switch t := v.(type) {
	case uint8:
		return uint32(t), nil
	case uint16:
		return uint32(t), nil
	case uint32:
		return t, nil
	case uint64:
		if t > math.MaxUint32 {
			return 0, fmt.Errorf("uint32 overflow: %d", t)
		}
		return uint32(t), nil
	case int:
		if t < 0 || t > math.MaxUint32 {
			return 0, fmt.Errorf("uint32 overflow: %d", t)
		}
		return uint32(t), nil
	case *big.Int:
		if t == nil {
			return 0, fmt.Errorf("nil big.Int")
		}
		if t.Sign() < 0 || t.BitLen() > 32 {
			return 0, fmt.Errorf("uint32 overflow: %s", t.String())
		}
		return uint32(t.Uint64()), nil
	default:
		return 0, fmt.Errorf("unexpected uint32 type: %T", v)
	}
}
