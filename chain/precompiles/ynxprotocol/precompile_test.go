package ynxprotocol_test

import (
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/vm"
	"github.com/holiman/uint256"
	"github.com/stretchr/testify/require"

	cmtproto "github.com/cometbft/cometbft/proto/tendermint/types"
	dbm "github.com/cosmos/cosmos-db"

	"cosmossdk.io/log"

	simtestutil "github.com/cosmos/cosmos-sdk/testutil/sims"
	sdk "github.com/cosmos/cosmos-sdk/types"

	ynx "github.com/JiahaoAlbus/YNX/chain"
	ynxconfig "github.com/JiahaoAlbus/YNX/chain/config"
	"github.com/JiahaoAlbus/YNX/chain/precompiles/ynxprotocol"
	ynxtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"

	evmtypes "github.com/cosmos/evm/x/vm/types"
)

func init() {
	cfg := sdk.GetConfig()
	ynxconfig.SetBech32Prefixes(cfg)
	ynxconfig.SetBip44CoinType(cfg)
	ynxconfig.RegisterDenoms()
	cfg.Seal()
}

func TestPrecompileRegisteredInApp(t *testing.T) {
	app := ynx.NewApp(
		log.NewNopLogger(),
		dbm.NewMemDB(),
		nil,
		true,
		simtestutil.EmptyAppOptions{},
	)

	params := evmtypes.DefaultParams()
	params.ActiveStaticPrecompiles = append(params.ActiveStaticPrecompiles, ynxprotocol.PrecompileAddress)

	pc, ok, err := app.EVMKeeper.GetStaticPrecompileInstance(&params, common.HexToAddress(ynxprotocol.PrecompileAddress))
	require.NoError(t, err)
	require.True(t, ok)
	_, is := pc.(*ynxprotocol.Precompile)
	require.True(t, is)
}

func TestUpdateParams_AuthorizedByTimelock(t *testing.T) {
	app := ynx.NewApp(
		log.NewNopLogger(),
		dbm.NewMemDB(),
		nil,
		true,
		simtestutil.EmptyAppOptions{},
	)

	ctx := app.BaseApp.NewUncachedContext(false, cmtproto.Header{
		ChainID: "ynx_test-1",
		Height:  1,
		Time:    time.Unix(1, 0).UTC(),
	})

	timelock := common.HexToAddress("0x00000000000000000000000000000000000000AA")
	require.NoError(t, app.YNXKeeper.SystemContracts.Set(ctx, ynxtypes.SystemContracts{
		Timelock: timelock.Hex(),
	}))
	require.NoError(t, app.YNXKeeper.Params.Set(ctx, ynxtypes.DefaultParams()))

	pc := ynxprotocol.NewPrecompile(app.YNXKeeper)

	founder := common.HexToAddress("0x1111111111111111111111111111111111111111")
	treasury := common.HexToAddress("0x2222222222222222222222222222222222222222")

	input, err := ynxprotocol.ABI.Pack(ynxprotocol.UpdateParamsMethod, founder, treasury, uint32(100), uint32(200), uint32(300), uint32(400))
	require.NoError(t, err)

	contract := vm.NewContract(timelock, common.HexToAddress(ynxprotocol.PrecompileAddress), uint256.NewInt(0), 10_000_000, nil)
	contract.Input = input

	out, err := pc.Execute(ctx, contract, false)
	require.NoError(t, err)

	method := ynxprotocol.ABI.Methods[ynxprotocol.UpdateParamsMethod]
	decoded, err := method.Outputs.Unpack(out)
	require.NoError(t, err)
	require.Len(t, decoded, 1)
	require.Equal(t, true, decoded[0])

	updated, err := app.YNXKeeper.Params.Get(ctx)
	require.NoError(t, err)
	require.Equal(t, sdk.AccAddress(founder.Bytes()).String(), updated.FounderAddress)
	require.Equal(t, sdk.AccAddress(treasury.Bytes()).String(), updated.TreasuryAddress)
	require.Equal(t, uint32(100), updated.FeeBurnBps)
	require.Equal(t, uint32(200), updated.FeeTreasuryBps)
	require.Equal(t, uint32(300), updated.FeeFounderBps)
	require.Equal(t, uint32(400), updated.InflationTreasuryBps)
}

func TestUpdateParams_UnauthorizedCaller(t *testing.T) {
	app := ynx.NewApp(
		log.NewNopLogger(),
		dbm.NewMemDB(),
		nil,
		true,
		simtestutil.EmptyAppOptions{},
	)

	ctx := app.BaseApp.NewUncachedContext(false, cmtproto.Header{
		ChainID: "ynx_test-1",
		Height:  1,
		Time:    time.Unix(1, 0).UTC(),
	})

	timelock := common.HexToAddress("0x00000000000000000000000000000000000000AA")
	require.NoError(t, app.YNXKeeper.SystemContracts.Set(ctx, ynxtypes.SystemContracts{
		Timelock: timelock.Hex(),
	}))
	require.NoError(t, app.YNXKeeper.Params.Set(ctx, ynxtypes.DefaultParams()))

	pc := ynxprotocol.NewPrecompile(app.YNXKeeper)

	input, err := ynxprotocol.ABI.Pack(ynxprotocol.UpdateParamsMethod, common.Address{}, common.Address{}, uint32(0), uint32(0), uint32(0), uint32(0))
	require.NoError(t, err)

	attacker := common.HexToAddress("0x00000000000000000000000000000000000000BB")
	contract := vm.NewContract(attacker, common.HexToAddress(ynxprotocol.PrecompileAddress), uint256.NewInt(0), 10_000_000, nil)
	contract.Input = input

	_, err = pc.Execute(ctx, contract, false)
	require.Error(t, err)
}

func TestUpdateParams_ReadOnlyProtection(t *testing.T) {
	app := ynx.NewApp(
		log.NewNopLogger(),
		dbm.NewMemDB(),
		nil,
		true,
		simtestutil.EmptyAppOptions{},
	)

	ctx := app.BaseApp.NewUncachedContext(false, cmtproto.Header{
		ChainID: "ynx_test-1",
		Height:  1,
		Time:    time.Unix(1, 0).UTC(),
	})

	timelock := common.HexToAddress("0x00000000000000000000000000000000000000AA")
	require.NoError(t, app.YNXKeeper.SystemContracts.Set(ctx, ynxtypes.SystemContracts{
		Timelock: timelock.Hex(),
	}))
	require.NoError(t, app.YNXKeeper.Params.Set(ctx, ynxtypes.DefaultParams()))

	pc := ynxprotocol.NewPrecompile(app.YNXKeeper)

	input, err := ynxprotocol.ABI.Pack(ynxprotocol.UpdateParamsMethod, common.Address{}, common.Address{}, uint32(0), uint32(0), uint32(0), uint32(0))
	require.NoError(t, err)

	contract := vm.NewContract(timelock, common.HexToAddress(ynxprotocol.PrecompileAddress), uint256.NewInt(0), 10_000_000, nil)
	contract.Input = input

	_, err = pc.Execute(ctx, contract, true)
	require.Error(t, err)
}

func TestGetParams_Roundtrip(t *testing.T) {
	app := ynx.NewApp(
		log.NewNopLogger(),
		dbm.NewMemDB(),
		nil,
		true,
		simtestutil.EmptyAppOptions{},
	)

	ctx := app.BaseApp.NewUncachedContext(false, cmtproto.Header{
		ChainID: "ynx_test-1",
		Height:  1,
		Time:    time.Unix(1, 0).UTC(),
	})

	founder := common.HexToAddress("0x1111111111111111111111111111111111111111")
	treasury := common.HexToAddress("0x2222222222222222222222222222222222222222")

	require.NoError(t, app.YNXKeeper.Params.Set(ctx, ynxtypes.Params{
		FounderAddress:       sdk.AccAddress(founder.Bytes()).String(),
		TreasuryAddress:      sdk.AccAddress(treasury.Bytes()).String(),
		FeeBurnBps:           1,
		FeeTreasuryBps:       2,
		FeeFounderBps:        3,
		InflationTreasuryBps: 4,
	}))

	pc := ynxprotocol.NewPrecompile(app.YNXKeeper)

	input, err := ynxprotocol.ABI.Pack(ynxprotocol.GetParamsMethod)
	require.NoError(t, err)

	contract := vm.NewContract(common.Address{}, common.HexToAddress(ynxprotocol.PrecompileAddress), uint256.NewInt(0), 10_000_000, nil)
	contract.Input = input

	out, err := pc.Execute(ctx, contract, true)
	require.NoError(t, err)

	method := ynxprotocol.ABI.Methods[ynxprotocol.GetParamsMethod]
	decoded, err := method.Outputs.Unpack(out)
	require.NoError(t, err)
	require.Len(t, decoded, 6)

	require.Equal(t, founder, decoded[0])
	require.Equal(t, treasury, decoded[1])
	require.Equal(t, uint32(1), decoded[2])
	require.Equal(t, uint32(2), decoded[3])
	require.Equal(t, uint32(3), decoded[4])
	require.Equal(t, uint32(4), decoded[5])
}
