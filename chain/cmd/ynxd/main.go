package main

import (
	"fmt"
	"os"

	svrcmd "github.com/cosmos/cosmos-sdk/server/cmd"
	sdk "github.com/cosmos/cosmos-sdk/types"

	_ "github.com/JiahaoAlbus/YNX/chain/rpc/ynx"

	"github.com/JiahaoAlbus/YNX/chain/cmd/ynxd/cmd"
	ynxconfig "github.com/JiahaoAlbus/YNX/chain/config"
)

func main() {
	setupSDKConfig()

	rootCmd := cmd.NewRootCmd()
	if err := svrcmd.Execute(rootCmd, "ynxd", ynxconfig.MustGetDefaultNodeHome()); err != nil {
		fmt.Fprintln(rootCmd.OutOrStderr(), err)
		os.Exit(1)
	}
}

func setupSDKConfig() {
	cfg := sdk.GetConfig()
	ynxconfig.SetBech32Prefixes(cfg)
	ynxconfig.SetBip44CoinType(cfg)
	ynxconfig.RegisterDenoms()
	cfg.Seal()
}
