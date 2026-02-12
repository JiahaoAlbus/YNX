package keeper

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/crypto"

	errorsmod "cosmossdk.io/errors"

	sdk "github.com/cosmos/cosmos-sdk/types"
	errortypes "github.com/cosmos/cosmos-sdk/types/errors"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"

	"github.com/cosmos/evm/x/vm/statedb"

	ynxtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"
)

const genesisDeployGasLimit = uint64(30_000_000)

type evmGenesisDeployer struct {
	k      Keeper
	ctx    sdk.Context
	from   common.Address
	nonce  uint64
	evmCfg *statedb.EVMConfig
}

func newEVMGenesisDeployer(k Keeper, ctx sdk.Context, from common.Address, nonce uint64) (*evmGenesisDeployer, error) {
	evmParams := k.evmKeeper.GetParams(ctx)
	feemarketParams := k.feeMarketKeeper.GetParams(ctx)

	baseFee := k.evmKeeper.GetBaseFee(ctx)
	if baseFee == nil {
		baseFee = big.NewInt(0)
	}

	return &evmGenesisDeployer{
		k:     k,
		ctx:   ctx,
		from:  from,
		nonce: nonce,
		evmCfg: &statedb.EVMConfig{
			Params:          evmParams,
			FeeMarketParams: feemarketParams,
			CoinBase:        common.Address{},
			BaseFee:         baseFee,
		},
	}, nil
}

func (d *evmGenesisDeployer) apply(msg core.Message) ([]byte, error) {
	txCfg := statedb.NewEmptyTxConfig()
	res, err := d.k.evmKeeper.ApplyMessageWithConfig(d.ctx, msg, nil, true, d.evmCfg, txCfg, true, nil)
	if err != nil {
		return nil, err
	}
	if res.VmError != "" {
		return nil, errorsmod.Wrapf(errortypes.ErrLogic, "evm vm_error: %s", res.VmError)
	}
	return res.Ret, nil
}

func (d *evmGenesisDeployer) create(initCode []byte) (common.Address, []byte, error) {
	created := crypto.CreateAddress(d.from, d.nonce)
	_, err := d.apply(core.Message{
		From:      d.from,
		To:        nil,
		Nonce:     d.nonce,
		Value:     big.NewInt(0),
		GasLimit:  genesisDeployGasLimit,
		GasPrice:  big.NewInt(0),
		GasFeeCap: big.NewInt(0),
		GasTipCap: big.NewInt(0),
		Data:      initCode,
	})
	if err != nil {
		return common.Address{}, nil, err
	}
	d.nonce++
	return created, nil, nil
}

func (d *evmGenesisDeployer) call(to common.Address, data []byte) ([]byte, error) {
	ret, err := d.apply(core.Message{
		From:      d.from,
		To:        &to,
		Nonce:     d.nonce,
		Value:     big.NewInt(0),
		GasLimit:  genesisDeployGasLimit,
		GasPrice:  big.NewInt(0),
		GasFeeCap: big.NewInt(0),
		GasTipCap: big.NewInt(0),
		Data:      data,
	})
	if err != nil {
		return nil, err
	}

	// ApplyMessageWithConfig does not manage nonces for top-level calls. Maintain
	// Ethereum semantics by incrementing the deployer nonce after each call.
	if err := d.bumpNonce(); err != nil {
		return nil, err
	}
	return ret, nil
}

func (d *evmGenesisDeployer) bumpNonce() error {
	cosmosAddr := sdk.AccAddress(d.from.Bytes())
	acc := d.k.accountKeeper.GetAccount(d.ctx, cosmosAddr)
	if acc == nil {
		return errorsmod.Wrapf(errortypes.ErrUnknownAddress, "deployer account missing: %s", cosmosAddr.String())
	}
	if err := acc.SetSequence(d.nonce + 1); err != nil {
		return err
	}
	d.k.accountKeeper.SetAccount(d.ctx, acc)
	d.nonce++
	return nil
}

func (k Keeper) deploySystemContracts(ctx sdk.Context, cfg ynxtypes.SystemConfig) (ynxtypes.SystemContracts, error) {
	deployerAcc, err := parseAnyAddress(ctx, cfg.DeployerAddress)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	from := common.BytesToAddress(deployerAcc.Bytes())

	// Ensure deployer account exists.
	if acc := k.accountKeeper.GetAccount(ctx, deployerAcc); acc == nil {
		acc = k.accountKeeper.NewAccountWithAddress(ctx, deployerAcc)
		k.accountKeeper.SetAccount(ctx, acc)
	}

	startNonce := k.accountKeeper.GetAccount(ctx, deployerAcc).GetSequence()

	var community common.Address
	if cfg.CommunityRecipientAddress != "" {
		communityAcc, err := parseAnyAddress(ctx, cfg.CommunityRecipientAddress)
		if err != nil {
			return ynxtypes.SystemContracts{}, err
		}
		community = common.BytesToAddress(communityAcc.Bytes())
	} else {
		community = from
	}
	if community == (common.Address{}) {
		return ynxtypes.SystemContracts{}, fmt.Errorf("invalid community_recipient_address: zero address")
	}

	teamAcc, err := parseAnyAddress(ctx, cfg.TeamBeneficiaryAddress)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	teamBeneficiary := common.BytesToAddress(teamAcc.Bytes())

	supply, ok := new(big.Int).SetString(cfg.GenesisSupply, 10)
	if !ok {
		return ynxtypes.SystemContracts{}, fmt.Errorf("invalid genesis_supply")
	}
	proposalThreshold, ok := new(big.Int).SetString(cfg.ProposalThreshold, 10)
	if !ok {
		return ynxtypes.SystemContracts{}, fmt.Errorf("invalid proposal_threshold")
	}
	proposalDeposit, ok := new(big.Int).SetString(cfg.ProposalDeposit, 10)
	if !ok {
		return ynxtypes.SystemContracts{}, fmt.Errorf("invalid proposal_deposit")
	}

	// Predicted addresses for dependency injection into constructors.
	timelockPredicted := crypto.CreateAddress(from, startNonce+1)
	governorPredicted := crypto.CreateAddress(from, startNonce+3)

	d, err := newEVMGenesisDeployer(k, ctx, from, startNonce)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	nyxtABI, nyxtBytecode, err := loadHardhatArtifact("NYXT")
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	timelockABI, timelockBytecode, err := loadHardhatArtifact("YNXTimelock")
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	treasuryABI, treasuryBytecode, err := loadHardhatArtifact("YNXTreasury")
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	governorABI, governorBytecode, err := loadHardhatArtifact("YNXGovernor")
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	orgABI, orgBytecode, err := loadHardhatArtifact("YNXOrgRegistry")
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	subjectABI, subjectBytecode, err := loadHardhatArtifact("YNXSubjectRegistry")
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	arbitrationABI, arbitrationBytecode, err := loadHardhatArtifact("YNXArbitration")
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	domainInboxABI, domainInboxBytecode, err := loadHardhatArtifact("YNXDomainInbox")
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	vestingABI, vestingBytecode, err := loadHardhatArtifact("NYXTTeamVesting")
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	nyxtInit, err := abiPackInitCode(nyxtABI, nyxtBytecode, timelockPredicted, from, supply)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	nyxtAddr, _, err := d.create(nyxtInit)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	timelockInit, err := abiPackInitCode(
		timelockABI,
		timelockBytecode,
		new(big.Int).SetUint64(cfg.TimelockDelaySeconds),
		[]common.Address{governorPredicted},
		[]common.Address{common.Address{}},
		timelockPredicted,
	)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	timelockAddr, _, err := d.create(timelockInit)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	treasuryInit, err := abiPackInitCode(treasuryABI, treasuryBytecode, timelockAddr)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	treasuryAddr, _, err := d.create(treasuryInit)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	governorInit, err := abiPackInitCode(
		governorABI,
		governorBytecode,
		nyxtAddr,
		nyxtAddr,
		timelockAddr,
		treasuryAddr,
		new(big.Int).SetUint64(cfg.VotingDelayBlocks),
		uint32(cfg.VotingPeriodBlocks),
		proposalThreshold,
		proposalDeposit,
		new(big.Int).SetUint64(cfg.QuorumPercent),
	)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	governorAddr, _, err := d.create(governorInit)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	orgInit, err := abiPackInitCode(orgABI, orgBytecode)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	orgAddr, _, err := d.create(orgInit)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	subjectInit, err := abiPackInitCode(subjectABI, subjectBytecode, orgAddr)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	subjectAddr, _, err := d.create(subjectInit)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	arbitrationInit, err := abiPackInitCode(arbitrationABI, arbitrationBytecode, orgAddr)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	arbitrationAddr, _, err := d.create(arbitrationInit)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	domainInboxInit, err := abiPackInitCode(domainInboxABI, domainInboxBytecode)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	domainInboxAddr, _, err := d.create(domainInboxInit)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	startUnix := ctx.BlockTime().Unix()
	if startUnix < 0 {
		startUnix = 0
	}
	startTimestamp := uint64(startUnix) + cfg.VestingCliffSeconds

	vestingInit, err := abiPackInitCode(
		vestingABI,
		vestingBytecode,
		teamBeneficiary,
		startTimestamp,
		cfg.VestingDurationSeconds,
	)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	teamVestingAddr, _, err := d.create(vestingInit)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	teamAllocation, treasuryAllocation, communityAllocation, err := calcAllocations(supply, cfg.TeamPercent, cfg.TreasuryPercent, cfg.CommunityPercent)
	if err != nil {
		return ynxtypes.SystemContracts{}, err
	}

	if _, err := d.call(nyxtAddr, mustAbiPack(nyxtABI, "transfer", treasuryAddr, treasuryAllocation)); err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	if _, err := d.call(nyxtAddr, mustAbiPack(nyxtABI, "transfer", teamVestingAddr, teamAllocation)); err != nil {
		return ynxtypes.SystemContracts{}, err
	}
	if community != from {
		if _, err := d.call(nyxtAddr, mustAbiPack(nyxtABI, "transfer", community, communityAllocation)); err != nil {
			return ynxtypes.SystemContracts{}, err
		}
	}

	// Ensure module account exists (sanity) and reserve the system contract addresses.
	_ = authtypes.NewModuleAddress(ynxtypes.ModuleName)

	return ynxtypes.SystemContracts{
		Nyxt:            nyxtAddr.Hex(),
		Timelock:        timelockAddr.Hex(),
		Treasury:        treasuryAddr.Hex(),
		Governor:        governorAddr.Hex(),
		TeamVesting:     teamVestingAddr.Hex(),
		OrgRegistry:     orgAddr.Hex(),
		SubjectRegistry: subjectAddr.Hex(),
		Arbitration:     arbitrationAddr.Hex(),
		DomainInbox:     domainInboxAddr.Hex(),
	}, nil
}

func abiPackInitCode(contractABI abi.ABI, bytecode []byte, args ...interface{}) ([]byte, error) {
	encodedArgs, err := contractABI.Pack("", args...)
	if err != nil {
		return nil, err
	}
	initCode := make([]byte, 0, len(bytecode)+len(encodedArgs))
	initCode = append(initCode, bytecode...)
	initCode = append(initCode, encodedArgs...)
	return initCode, nil
}

func mustAbiPack(contractABI abi.ABI, method string, args ...interface{}) []byte {
	bz, err := contractABI.Pack(method, args...)
	if err != nil {
		panic(err)
	}
	return bz
}

func calcAllocations(
	supply *big.Int,
	teamPercent, treasuryPercent, communityPercent uint32,
) (team, treasury, community *big.Int, err error) {
	if supply == nil || supply.Sign() <= 0 {
		return nil, nil, nil, fmt.Errorf("invalid supply")
	}
	if uint64(teamPercent)+uint64(treasuryPercent)+uint64(communityPercent) != 100 {
		return nil, nil, nil, fmt.Errorf("allocation percents must sum to 100")
	}

	hundred := big.NewInt(100)
	team = new(big.Int).Mul(supply, big.NewInt(int64(teamPercent)))
	team.Quo(team, hundred)

	treasury = new(big.Int).Mul(supply, big.NewInt(int64(treasuryPercent)))
	treasury.Quo(treasury, hundred)

	community = new(big.Int).Mul(supply, big.NewInt(int64(communityPercent)))
	community.Quo(community, hundred)

	sum := new(big.Int).Add(team, treasury)
	sum.Add(sum, community)
	if sum.Cmp(supply) != 0 {
		return nil, nil, nil, fmt.Errorf("allocation mismatch: got %s expected %s", sum.String(), supply.String())
	}

	return team, treasury, community, nil
}
