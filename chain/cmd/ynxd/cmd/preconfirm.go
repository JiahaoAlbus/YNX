package cmd

import (
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"

	"github.com/ethereum/go-ethereum/crypto"
	"github.com/spf13/cobra"

	"github.com/cosmos/cosmos-sdk/client/flags"
)

const (
	flagPreconfirmOut   = "out"
	flagPreconfirmForce = "force"
)

func preconfirmCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "preconfirm",
		Short: "Preconfirmation utilities (node operator)",
	}
	cmd.AddCommand(preconfirmKeygenCmd())
	return cmd
}

func preconfirmKeygenCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "keygen",
		Short: "Generate a secp256k1 key for ynx_preconfirmTx signing",
		RunE: func(cmd *cobra.Command, _ []string) error {
			home, err := cmd.Flags().GetString(flags.FlagHome)
			if err != nil {
				return err
			}
			if home == "" {
				return fmt.Errorf("--%s is required", flags.FlagHome)
			}

			out, err := cmd.Flags().GetString(flagPreconfirmOut)
			if err != nil {
				return err
			}
			if out == "" {
				out = filepath.Join(home, "config", "ynx_preconfirm.key")
			}

			force, err := cmd.Flags().GetBool(flagPreconfirmForce)
			if err != nil {
				return err
			}
			if !force {
				if _, err := os.Stat(out); err == nil {
					return fmt.Errorf("output already exists (use --%s): %s", flagPreconfirmForce, out)
				}
			}

			if err := os.MkdirAll(filepath.Dir(out), 0o755); err != nil {
				return err
			}

			key, err := crypto.GenerateKey()
			if err != nil {
				return err
			}
			privHex := hex.EncodeToString(crypto.FromECDSA(key))

			if err := os.WriteFile(out, []byte(privHex+"\n"), 0o600); err != nil {
				return err
			}

			_, _ = fmt.Fprintf(cmd.ErrOrStderr(), "Wrote %s\n", out)
			return nil
		},
	}

	cmd.Flags().String(flags.FlagHome, "", "node's home directory")
	cmd.Flags().String(flagPreconfirmOut, "", "output file path (default: <home>/config/ynx_preconfirm.key)")
	cmd.Flags().Bool(flagPreconfirmForce, false, "overwrite existing output file")

	return cmd
}

