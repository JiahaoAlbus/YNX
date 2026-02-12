package ynx

import (
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/rpc"

	evmmempool "github.com/cosmos/evm/mempool"
	cosmosevmrpc "github.com/cosmos/evm/rpc"
	"github.com/cosmos/evm/rpc/backend"
	"github.com/cosmos/evm/rpc/stream"
	servertypes "github.com/cosmos/evm/server/types"

	"github.com/cosmos/cosmos-sdk/client"
	sdkserver "github.com/cosmos/cosmos-sdk/server"
)

const namespace = "ynx"

func init() {
	_ = cosmosevmrpc.RegisterAPINamespace(namespace, createAPIs)
}

func createAPIs(
	ctx *sdkserver.Context,
	clientCtx client.Context,
	_ *stream.RPCStream,
	allowUnprotectedTxs bool,
	indexer servertypes.EVMTxIndexer,
	mempool *evmmempool.ExperimentalEVMMempool,
) []rpc.API {
	api := NewPublicAPI(ctx.Logger, backend.NewBackend(ctx, ctx.Logger, clientCtx, allowUnprotectedTxs, indexer, mempool))

	enabled := strings.EqualFold(os.Getenv("YNX_PRECONFIRM_ENABLED"), "true") || os.Getenv("YNX_PRECONFIRM_ENABLED") == "1"
	if enabled {
		if signers, threshold, err := LoadPreconfirmSignersFromEnv(); err == nil {
			if err := api.SetPreconfirmSigners(signers, threshold); err != nil {
				ctx.Logger.Error("failed to set preconfirm signers", "err", err)
			}
		} else {
			ctx.Logger.Error("failed to load preconfirm signers", "err", err)
		}
	}

	return []rpc.API{
		{
			Namespace: namespace,
			Version:   "1.0",
			Service:   api,
			Public:    true,
		},
	}
}
