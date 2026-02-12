package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/client/flags"
	"github.com/cosmos/cosmos-sdk/x/genutil"
	genutiltypes "github.com/cosmos/cosmos-sdk/x/genutil/types"

	ynxmodtypes "github.com/JiahaoAlbus/YNX/chain/x/ynx/types"
)

const (
	flagYNXSystemEnabled                = "ynx.system.enabled"
	flagYNXSystemDeployer               = "ynx.system.deployer"
	flagYNXSystemTeamBeneficiary        = "ynx.system.team-beneficiary"
	flagYNXSystemCommunityRecipient     = "ynx.system.community-recipient"
	flagYNXSystemGenesisSupply          = "ynx.system.genesis-supply"
	flagYNXSystemTeamPercent            = "ynx.system.team-percent"
	flagYNXSystemTreasuryPercent        = "ynx.system.treasury-percent"
	flagYNXSystemCommunityPercent       = "ynx.system.community-percent"
	flagYNXSystemVotingDelayBlocks      = "ynx.system.voting-delay-blocks"
	flagYNXSystemVotingPeriodBlocks     = "ynx.system.voting-period-blocks"
	flagYNXSystemProposalThreshold      = "ynx.system.proposal-threshold"
	flagYNXSystemProposalDeposit        = "ynx.system.proposal-deposit"
	flagYNXSystemQuorumPercent          = "ynx.system.quorum-percent"
	flagYNXSystemTimelockDelaySeconds   = "ynx.system.timelock-delay-seconds"
	flagYNXSystemVestingCliffSeconds    = "ynx.system.vesting-cliff-seconds"
	flagYNXSystemVestingDurationSeconds = "ynx.system.vesting-duration-seconds"

	flagYNXParamsFounder              = "ynx.params.founder"
	flagYNXParamsTreasury             = "ynx.params.treasury"
	flagYNXParamsFeeBurnBps           = "ynx.params.fee-burn-bps"
	flagYNXParamsFeeTreasuryBps       = "ynx.params.fee-treasury-bps"
	flagYNXParamsFeeFounderBps        = "ynx.params.fee-founder-bps"
	flagYNXParamsInflationTreasuryBps = "ynx.params.inflation-treasury-bps"
)

func ynxGenesisCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "ynx",
		Short: "YNX genesis helpers",
	}

	cmd.AddCommand(ynxGenesisSetCmd())
	return cmd
}

func ynxGenesisSetCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "set",
		Short: "Set x/ynx genesis values in genesis.json",
		RunE: func(cmd *cobra.Command, _ []string) error {
			clientCtx := client.GetClientContextFromCmd(cmd)
			home, err := cmd.Flags().GetString(flags.FlagHome)
			if err != nil {
				return err
			}
			if home == "" {
				home = clientCtx.HomeDir
			}
			if home == "" {
				return fmt.Errorf("home directory is required")
			}

			genFile := filepath.Join(home, "config", "genesis.json")

			appGenesis, err := genutiltypes.AppGenesisFromFile(genFile)
			if err != nil {
				return err
			}

			var appState map[string]json.RawMessage
			if err := json.Unmarshal(appGenesis.AppState, &appState); err != nil {
				return fmt.Errorf("failed to unmarshal app state: %w", err)
			}

			gs := ynxmodtypes.DefaultGenesis()
			if bz, ok := appState[ynxmodtypes.ModuleName]; ok && len(bz) > 0 {
				clientCtx.Codec.MustUnmarshalJSON(bz, gs)
			}

			// system config
			if cmd.Flags().Changed(flagYNXSystemEnabled) {
				enabled, _ := cmd.Flags().GetBool(flagYNXSystemEnabled)
				gs.System.Enabled = enabled
			}
			if cmd.Flags().Changed(flagYNXSystemDeployer) {
				v, _ := cmd.Flags().GetString(flagYNXSystemDeployer)
				gs.System.DeployerAddress = v
			}
			if cmd.Flags().Changed(flagYNXSystemTeamBeneficiary) {
				v, _ := cmd.Flags().GetString(flagYNXSystemTeamBeneficiary)
				gs.System.TeamBeneficiaryAddress = v
			}
			if cmd.Flags().Changed(flagYNXSystemCommunityRecipient) {
				v, _ := cmd.Flags().GetString(flagYNXSystemCommunityRecipient)
				gs.System.CommunityRecipientAddress = v
			}
			if cmd.Flags().Changed(flagYNXSystemGenesisSupply) {
				v, _ := cmd.Flags().GetString(flagYNXSystemGenesisSupply)
				gs.System.GenesisSupply = v
			}
			if cmd.Flags().Changed(flagYNXSystemTeamPercent) {
				v, _ := cmd.Flags().GetUint32(flagYNXSystemTeamPercent)
				gs.System.TeamPercent = v
			}
			if cmd.Flags().Changed(flagYNXSystemTreasuryPercent) {
				v, _ := cmd.Flags().GetUint32(flagYNXSystemTreasuryPercent)
				gs.System.TreasuryPercent = v
			}
			if cmd.Flags().Changed(flagYNXSystemCommunityPercent) {
				v, _ := cmd.Flags().GetUint32(flagYNXSystemCommunityPercent)
				gs.System.CommunityPercent = v
			}
			if cmd.Flags().Changed(flagYNXSystemVotingDelayBlocks) {
				v, _ := cmd.Flags().GetUint64(flagYNXSystemVotingDelayBlocks)
				gs.System.VotingDelayBlocks = v
			}
			if cmd.Flags().Changed(flagYNXSystemVotingPeriodBlocks) {
				v, _ := cmd.Flags().GetUint64(flagYNXSystemVotingPeriodBlocks)
				gs.System.VotingPeriodBlocks = v
			}
			if cmd.Flags().Changed(flagYNXSystemProposalThreshold) {
				v, _ := cmd.Flags().GetString(flagYNXSystemProposalThreshold)
				gs.System.ProposalThreshold = v
			}
			if cmd.Flags().Changed(flagYNXSystemProposalDeposit) {
				v, _ := cmd.Flags().GetString(flagYNXSystemProposalDeposit)
				gs.System.ProposalDeposit = v
			}
			if cmd.Flags().Changed(flagYNXSystemQuorumPercent) {
				v, _ := cmd.Flags().GetUint64(flagYNXSystemQuorumPercent)
				gs.System.QuorumPercent = v
			}
			if cmd.Flags().Changed(flagYNXSystemTimelockDelaySeconds) {
				v, _ := cmd.Flags().GetUint64(flagYNXSystemTimelockDelaySeconds)
				gs.System.TimelockDelaySeconds = v
			}
			if cmd.Flags().Changed(flagYNXSystemVestingCliffSeconds) {
				v, _ := cmd.Flags().GetUint64(flagYNXSystemVestingCliffSeconds)
				gs.System.VestingCliffSeconds = v
			}
			if cmd.Flags().Changed(flagYNXSystemVestingDurationSeconds) {
				v, _ := cmd.Flags().GetUint64(flagYNXSystemVestingDurationSeconds)
				gs.System.VestingDurationSeconds = v
			}

			// params
			if cmd.Flags().Changed(flagYNXParamsFounder) {
				v, _ := cmd.Flags().GetString(flagYNXParamsFounder)
				gs.Params.FounderAddress = v
			}
			if cmd.Flags().Changed(flagYNXParamsTreasury) {
				v, _ := cmd.Flags().GetString(flagYNXParamsTreasury)
				gs.Params.TreasuryAddress = v
			}
			if cmd.Flags().Changed(flagYNXParamsFeeBurnBps) {
				v, _ := cmd.Flags().GetUint32(flagYNXParamsFeeBurnBps)
				gs.Params.FeeBurnBps = v
			}
			if cmd.Flags().Changed(flagYNXParamsFeeTreasuryBps) {
				v, _ := cmd.Flags().GetUint32(flagYNXParamsFeeTreasuryBps)
				gs.Params.FeeTreasuryBps = v
			}
			if cmd.Flags().Changed(flagYNXParamsFeeFounderBps) {
				v, _ := cmd.Flags().GetUint32(flagYNXParamsFeeFounderBps)
				gs.Params.FeeFounderBps = v
			}
			if cmd.Flags().Changed(flagYNXParamsInflationTreasuryBps) {
				v, _ := cmd.Flags().GetUint32(flagYNXParamsInflationTreasuryBps)
				gs.Params.InflationTreasuryBps = v
			}

			// Clear previously exported addresses if system deploy is enabled.
			if gs.System.Enabled {
				gs.SystemContracts = ynxmodtypes.SystemContracts{}
			}

			if err := gs.Validate(); err != nil {
				return err
			}

			appState[ynxmodtypes.ModuleName] = clientCtx.Codec.MustMarshalJSON(gs)
			appGenesis.AppState, err = json.MarshalIndent(appState, "", " ")
			if err != nil {
				return err
			}

			if err := genutil.ExportGenesisFile(appGenesis, genFile); err != nil {
				return err
			}

			_, _ = fmt.Fprintf(os.Stderr, "Updated %s\n", genFile)
			return nil
		},
	}

	cmd.Flags().String(flags.FlagHome, "", "node's home directory")

	cmd.Flags().Bool(flagYNXSystemEnabled, false, "enable deterministic system contract deployment during InitGenesis")
	cmd.Flags().String(flagYNXSystemDeployer, "", "system contracts deployer address (0x... or bech32)")
	cmd.Flags().String(flagYNXSystemTeamBeneficiary, "", "team vesting beneficiary address (0x... or bech32)")
	cmd.Flags().String(flagYNXSystemCommunityRecipient, "", "community allocation recipient address (0x... or bech32; optional, defaults to deployed treasury contract)")
	cmd.Flags().String(flagYNXSystemGenesisSupply, "", "NYXT ERC20 genesis supply (base-10 uint256 string)")
	cmd.Flags().Uint32(flagYNXSystemTeamPercent, 0, "team allocation percent (0-100)")
	cmd.Flags().Uint32(flagYNXSystemTreasuryPercent, 0, "treasury allocation percent (0-100)")
	cmd.Flags().Uint32(flagYNXSystemCommunityPercent, 0, "community allocation percent (0-100)")
	cmd.Flags().Uint64(flagYNXSystemVotingDelayBlocks, 0, "governor voting delay (in blocks)")
	cmd.Flags().Uint64(flagYNXSystemVotingPeriodBlocks, 0, "governor voting period (in blocks)")
	cmd.Flags().String(flagYNXSystemProposalThreshold, "", "governor proposal threshold votes (base-10 uint256 string)")
	cmd.Flags().String(flagYNXSystemProposalDeposit, "", "governor proposal deposit (base-10 uint256 string)")
	cmd.Flags().Uint64(flagYNXSystemQuorumPercent, 0, "governor quorum percent (0-100)")
	cmd.Flags().Uint64(flagYNXSystemTimelockDelaySeconds, 0, "timelock delay (in seconds)")
	cmd.Flags().Uint64(flagYNXSystemVestingCliffSeconds, 0, "team vesting cliff (in seconds)")
	cmd.Flags().Uint64(flagYNXSystemVestingDurationSeconds, 0, "team vesting duration (in seconds)")

	cmd.Flags().String(flagYNXParamsFounder, "", "founder fee recipient (bech32)")
	cmd.Flags().String(flagYNXParamsTreasury, "", "treasury recipient (bech32; optional, defaults to deployed treasury contract)")
	cmd.Flags().Uint32(flagYNXParamsFeeBurnBps, 0, "fee burn basis points (0-10000)")
	cmd.Flags().Uint32(flagYNXParamsFeeTreasuryBps, 0, "fee treasury basis points (0-10000)")
	cmd.Flags().Uint32(flagYNXParamsFeeFounderBps, 0, "fee founder basis points (0-10000)")
	cmd.Flags().Uint32(flagYNXParamsInflationTreasuryBps, 0, "inflation treasury basis points (0-10000)")

	return cmd
}
