package ynx

import (
	"errors"

	abci "github.com/cometbft/cometbft/v2/abci/types"

	"github.com/cosmos/cosmos-sdk/baseapp"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/types/mempool"
)

type EVMProposalHandler struct {
	mempool          mempool.Mempool
	txVerifier       baseapp.ProposalTxVerifier
	txSelector       baseapp.TxSelector
	signerExtAdapter mempool.SignerExtractionAdapter
}

func NewEVMProposalHandler(
	mp mempool.Mempool,
	txVerifier baseapp.ProposalTxVerifier,
	signerExtAdapter mempool.SignerExtractionAdapter,
) *EVMProposalHandler {
	if signerExtAdapter == nil {
		signerExtAdapter = mempool.NewDefaultSignerExtractionAdapter()
	}

	return &EVMProposalHandler{
		mempool:          mp,
		txVerifier:       txVerifier,
		txSelector:       baseapp.NewDefaultTxSelector(),
		signerExtAdapter: signerExtAdapter,
	}
}

func (h *EVMProposalHandler) PrepareProposalHandler() sdk.PrepareProposalHandler {
	return func(ctx sdk.Context, req *abci.PrepareProposalRequest) (*abci.PrepareProposalResponse, error) {
		var maxBlockGas uint64
		if b := ctx.ConsensusParams().Block; b != nil {
			maxBlockGas = uint64(b.MaxGas)
		}

		defer h.txSelector.Clear()

		_, isNoOp := h.mempool.(mempool.NoOpMempool)
		if h.mempool == nil || isNoOp {
			for _, txBz := range req.Txs {
				tx, err := h.txVerifier.TxDecode(txBz)
				if err != nil {
					return nil, err
				}

				stop := h.txSelector.SelectTxForProposal(ctx, uint64(req.MaxTxBytes), maxBlockGas, tx, txBz)
				if stop {
					break
				}
			}

			return &abci.PrepareProposalResponse{Txs: h.txSelector.SelectedTxs(ctx)}, nil
		}

		selectedTxsSignersSeqs := make(map[string]uint64)
		var (
			resError        error
			selectedTxsNums int
			invalidTxs      []sdk.Tx
		)

		mempool.SelectBy(ctx, h.mempool, req.Txs, func(memTx sdk.Tx) bool {
			unorderedTx, ok := memTx.(sdk.TxWithUnordered)
			isUnordered := ok && unorderedTx.GetUnordered()
			txSignersSeqs := make(map[string]uint64)

			if !isUnordered {
				signerData, err := h.signerExtAdapter.GetSigners(memTx)
				if err != nil {
					resError = err
					return false
				}

				shouldAdd := true
				for _, signer := range signerData {
					seq, ok := selectedTxsSignersSeqs[signer.Signer.String()]
					if !ok {
						txSignersSeqs[signer.Signer.String()] = signer.Sequence
						continue
					}

					if seq+1 != signer.Sequence {
						shouldAdd = false
						break
					}
					txSignersSeqs[signer.Signer.String()] = signer.Sequence
				}

				if !shouldAdd {
					return true
				}
			}

			txBz, err := h.txVerifier.PrepareProposalVerifyTx(memTx)
			if err != nil {
				invalidTxs = append(invalidTxs, memTx)
			} else {
				stop := h.txSelector.SelectTxForProposal(ctx, uint64(req.MaxTxBytes), maxBlockGas, memTx, txBz)
				if stop {
					return false
				}

				txsLen := len(h.txSelector.SelectedTxs(ctx))
				if !isUnordered {
					for sender, seq := range txSignersSeqs {
						if txsLen != selectedTxsNums {
							selectedTxsSignersSeqs[sender] = seq
						} else if _, ok := selectedTxsSignersSeqs[sender]; !ok {
							selectedTxsSignersSeqs[sender] = seq - 1
						}
					}
				}
				selectedTxsNums = txsLen
			}

			return true
		})

		if resError != nil {
			return nil, resError
		}

		for _, tx := range invalidTxs {
			err := h.mempool.Remove(tx)
			if err != nil && !errors.Is(err, mempool.ErrTxNotFound) {
				return nil, err
			}
		}

		return &abci.PrepareProposalResponse{Txs: h.txSelector.SelectedTxs(ctx)}, nil
	}
}
