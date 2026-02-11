package types

import (
	"fmt"
	"math/big"
)

const (
	DefaultGenesisSupply        = "100000000000000000000000000000" // 100B * 1e18
	DefaultProposalThreshold    = "1000000000000000000000000"      // 1,000,000 * 1e18
	DefaultProposalDeposit      = "100000000000000000000000"       // 100,000 * 1e18
	DefaultVotingDelayBlocks    = uint64(1)
	DefaultVotingPeriodBlocks   = uint64(7 * 24 * 60 * 60) // 7d @ 1s blocks
	DefaultQuorumPercent        = uint64(10)
	DefaultTimelockDelaySeconds = uint64(7 * 24 * 60 * 60)
	DefaultVestingCliffSeconds  = uint64(365 * 24 * 60 * 60)
	DefaultVestingDuration      = uint64(4 * 365 * 24 * 60 * 60)
)

func DefaultSystemConfig() SystemConfig {
	return SystemConfig{
		Enabled:                 false,
		DeployerAddress:         "",
		TeamBeneficiaryAddress:  "",
		CommunityRecipientAddress: "",
		GenesisSupply:           DefaultGenesisSupply,
		TeamPercent:             15,
		TreasuryPercent:         40,
		CommunityPercent:        45,
		VotingDelayBlocks:       DefaultVotingDelayBlocks,
		VotingPeriodBlocks:      DefaultVotingPeriodBlocks,
		ProposalThreshold:       DefaultProposalThreshold,
		ProposalDeposit:         DefaultProposalDeposit,
		QuorumPercent:           DefaultQuorumPercent,
		TimelockDelaySeconds:    DefaultTimelockDelaySeconds,
		VestingCliffSeconds:     DefaultVestingCliffSeconds,
		VestingDurationSeconds:  DefaultVestingDuration,
	}
}

func DefaultGenesis() *GenesisState {
	return &GenesisState{
		Params:          DefaultParams(),
		System:          DefaultSystemConfig(),
		SystemContracts: SystemContracts{},
	}
}

func (g GenesisState) Validate() error {
	if err := g.Params.Validate(); err != nil {
		return err
	}
	if err := g.System.Validate(); err != nil {
		return err
	}
	return nil
}

func (cfg SystemConfig) Validate() error {
	if !cfg.Enabled {
		return nil
	}

	if cfg.DeployerAddress == "" {
		return fmt.Errorf("system.deployer_address is required when enabled")
	}
	if cfg.TeamBeneficiaryAddress == "" {
		return fmt.Errorf("system.team_beneficiary_address is required when enabled")
	}
	if cfg.CommunityRecipientAddress == "" {
		return fmt.Errorf("system.community_recipient_address is required when enabled")
	}

	if sum := uint64(cfg.TeamPercent) + uint64(cfg.TreasuryPercent) + uint64(cfg.CommunityPercent); sum != 100 {
		return fmt.Errorf("allocation percentages must sum to 100, got %d", sum)
	}

	if _, ok := new(big.Int).SetString(cfg.GenesisSupply, 10); !ok {
		return fmt.Errorf("invalid system.genesis_supply (base-10 uint256 string)")
	}
	if _, ok := new(big.Int).SetString(cfg.ProposalThreshold, 10); !ok {
		return fmt.Errorf("invalid system.proposal_threshold (base-10 uint256 string)")
	}
	if _, ok := new(big.Int).SetString(cfg.ProposalDeposit, 10); !ok {
		return fmt.Errorf("invalid system.proposal_deposit (base-10 uint256 string)")
	}

	return nil
}

