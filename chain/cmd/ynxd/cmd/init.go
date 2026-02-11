package cmd

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	cfg "github.com/cometbft/cometbft/config"
	cmttypes "github.com/cometbft/cometbft/types"
	"github.com/cosmos/go-bip39"
	"github.com/spf13/cobra"

	errorsmod "cosmossdk.io/errors"
	"cosmossdk.io/math/unsafe"

	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/client/flags"
	"github.com/cosmos/cosmos-sdk/client/input"
	"github.com/cosmos/cosmos-sdk/crypto/keys/ed25519"
	"github.com/cosmos/cosmos-sdk/server"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/version"
	"github.com/cosmos/cosmos-sdk/x/genutil"
	genutiltypes "github.com/cosmos/cosmos-sdk/x/genutil/types"

	ynx "github.com/JiahaoAlbus/YNX/chain"
)

const (
	flagOverwrite         = "overwrite"
	flagRecover           = "recover"
	flagDefaultBondDenom  = "default-denom"
	flagConsensusKeyAlgo  = "consensus-key-algo"
	flagChainID           = flags.FlagChainID
	flagInitHeight        = flags.FlagInitHeight
	flagHome              = flags.FlagHome
	defaultConsensusKey   = ed25519.KeyType
)

type initPrintInfo struct {
	Moniker    string          `json:"moniker" yaml:"moniker"`
	ChainID    string          `json:"chain_id" yaml:"chain_id"`
	NodeID     string          `json:"node_id" yaml:"node_id"`
	GenTxsDir  string          `json:"gentxs_dir" yaml:"gentxs_dir"`
	AppMessage json.RawMessage `json:"app_message" yaml:"app_message"`
}

func initDisplayInfo(moniker, chainID, nodeID, genTxsDir string, appMessage json.RawMessage) error {
	out, err := json.MarshalIndent(initPrintInfo{
		Moniker:    moniker,
		ChainID:    chainID,
		NodeID:     nodeID,
		GenTxsDir:  genTxsDir,
		AppMessage: appMessage,
	}, "", " ")
	if err != nil {
		return err
	}

	_, err = fmt.Fprintf(os.Stderr, "%s\n", out)
	return err
}

func initCmd(app *ynx.App, defaultNodeHome string) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "init [moniker]",
		Short: "Initialize private validator, p2p, genesis, and application configuration files",
		Long:  "Initialize validators's and node's configuration files.",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			clientCtx := client.GetClientContextFromCmd(cmd)

			serverCtx := server.GetServerContextFromCmd(cmd)
			config := serverCtx.Config
			config.SetRoot(clientCtx.HomeDir)

			chainID, _ := cmd.Flags().GetString(flagChainID)
			switch {
			case chainID != "":
			case clientCtx.ChainID != "":
				chainID = clientCtx.ChainID
			default:
				chainID = fmt.Sprintf("test-chain-%v", unsafe.Str(6))
			}

			// Get bip39 mnemonic
			var mnemonic string
			recover, _ := cmd.Flags().GetBool(flagRecover)
			if recover {
				inBuf := bufio.NewReader(cmd.InOrStdin())
				value, err := input.GetString("Enter your bip39 mnemonic", inBuf)
				if err != nil {
					return err
				}

				mnemonic = value
				if !bip39.IsMnemonicValid(mnemonic) {
					return errors.New("invalid mnemonic")
				}
			}

			// Get initial height
			initHeight, _ := cmd.Flags().GetInt64(flagInitHeight)
			if initHeight < 1 {
				initHeight = 1
			}

			nodeID, _, err := genutil.InitializeNodeValidatorFilesFromMnemonic(config, mnemonic)
			if err != nil {
				return err
			}

			config.Moniker = args[0]

			genFile := config.GenesisFile()
			overwrite, _ := cmd.Flags().GetBool(flagOverwrite)
			defaultDenom, _ := cmd.Flags().GetString(flagDefaultBondDenom)

			// use os.Stat to check if the file exists
			_, err = os.Stat(genFile)
			if !overwrite && !os.IsNotExist(err) {
				return fmt.Errorf("genesis.json file already exists: %v", genFile)
			}

			// Overwrites the SDK default denom for side-effects
			if defaultDenom != "" {
				sdk.DefaultBondDenom = defaultDenom
			}

			appGenState := app.DefaultGenesis()
			appState, err := json.MarshalIndent(appGenState, "", " ")
			if err != nil {
				return errorsmod.Wrap(err, "failed to marshal default genesis state")
			}

			appGenesis := &genutiltypes.AppGenesis{}
			if _, err := os.Stat(genFile); err != nil {
				if !os.IsNotExist(err) {
					return err
				}
			} else {
				appGenesis, err = genutiltypes.AppGenesisFromFile(genFile)
				if err != nil {
					return errorsmod.Wrap(err, "failed to read genesis doc from file")
				}
			}

			appGenesis.AppName = version.AppName
			appGenesis.AppVersion = version.Version
			appGenesis.ChainID = chainID
			appGenesis.AppState = appState
			appGenesis.InitialHeight = initHeight
			appGenesis.Consensus = &genutiltypes.ConsensusGenesis{
				Validators: nil,
				Params:     cmttypes.DefaultConsensusParams(),
			}

			consensusKey, err := cmd.Flags().GetString(flagConsensusKeyAlgo)
			if err != nil {
				return errorsmod.Wrap(err, "failed to get consensus key algo")
			}

			appGenesis.Consensus.Params.Validator.PubKeyTypes = []string{consensusKey}

			if err = genutil.ExportGenesisFile(appGenesis, genFile); err != nil {
				return errorsmod.Wrap(err, "failed to export genesis file")
			}

			cfg.WriteConfigFile(filepath.Join(config.RootDir, "config", "config.toml"), config)
			return initDisplayInfo(config.Moniker, chainID, nodeID, "", appState)
		},
	}

	cmd.Flags().String(flagHome, defaultNodeHome, "node's home directory")
	cmd.Flags().BoolP(flagOverwrite, "o", false, "overwrite the genesis.json file")
	cmd.Flags().Bool(flagRecover, false, "provide seed phrase to recover existing key instead of creating")
	cmd.Flags().String(flagChainID, "", "genesis file chain-id, if left blank will be randomly created")
	cmd.Flags().String(flagDefaultBondDenom, "", "genesis file default denomination, if left blank default value is 'stake'")
	cmd.Flags().Int64(flagInitHeight, 1, "specify the initial block height at genesis")
	cmd.Flags().String(flagConsensusKeyAlgo, defaultConsensusKey, "algorithm to use for the consensus key")

	return cmd
}

