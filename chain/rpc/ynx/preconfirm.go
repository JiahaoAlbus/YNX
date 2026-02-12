package ynx

import (
	"crypto/ecdsa"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/cosmos/evm/rpc/backend"

	cmtrpcclient "github.com/cometbft/cometbft/rpc/client"

	evmtypes "github.com/cosmos/evm/x/vm/types"

	"cosmossdk.io/log"
)

const txConfirmDigestPrefix = "YNX_TXCONFIRM_V0"

type PreconfirmReceipt struct {
	Status     string         `json:"status"`
	ChainID    string         `json:"chainId"`
	EVMChainID *hexutil.Big   `json:"evmChainId"`
	TxHash     common.Hash    `json:"txHash"`
	TargetBlock hexutil.Uint64 `json:"targetBlock"`
	IssuedAt   hexutil.Uint64 `json:"issuedAt"`
	Signer     common.Address `json:"signer"`
	Digest     common.Hash    `json:"digest"`
	Signature  hexutil.Bytes  `json:"signature"`
}

type PreconfirmSigner struct {
	privKey *ecdsa.PrivateKey
	address common.Address
}

func LoadPreconfirmSignerFromEnv() (*PreconfirmSigner, error) {
	if hexKey := strings.TrimSpace(os.Getenv("YNX_PRECONFIRM_PRIVKEY_HEX")); hexKey != "" {
		return LoadPreconfirmSignerFromHex(hexKey)
	}
	if keyPath := strings.TrimSpace(os.Getenv("YNX_PRECONFIRM_KEY_PATH")); keyPath != "" {
		return LoadPreconfirmSignerFromFile(keyPath)
	}
	return nil, fmt.Errorf("missing YNX_PRECONFIRM_PRIVKEY_HEX or YNX_PRECONFIRM_KEY_PATH")
}

func LoadPreconfirmSignerFromFile(path string) (*PreconfirmSigner, error) {
	path = strings.TrimSpace(path)
	if path == "" {
		return nil, fmt.Errorf("empty key path")
	}
	bz, err := os.ReadFile(filepath.Clean(path))
	if err != nil {
		return nil, err
	}
	return LoadPreconfirmSignerFromHex(string(bz))
}

func LoadPreconfirmSignerFromHex(hexKey string) (*PreconfirmSigner, error) {
	hexKey = strings.TrimSpace(hexKey)
	hexKey = strings.TrimPrefix(hexKey, "0x")
	bz, err := hex.DecodeString(hexKey)
	if err != nil {
		return nil, fmt.Errorf("invalid privkey hex: %w", err)
	}
	if len(bz) != 32 {
		return nil, fmt.Errorf("invalid privkey length: got %d, expected 32", len(bz))
	}
	key, err := crypto.ToECDSA(bz)
	if err != nil {
		return nil, err
	}
	return &PreconfirmSigner{
		privKey: key,
		address: crypto.PubkeyToAddress(key.PublicKey),
	}, nil
}

func (s *PreconfirmSigner) Address() common.Address { return s.address }

func (s *PreconfirmSigner) SignDigest(digest common.Hash) ([]byte, error) {
	return crypto.Sign(digest.Bytes(), s.privKey)
}

type PublicAPI struct {
	logger log.Logger
	backend *backend.Backend
	signer  *PreconfirmSigner
}

func NewPublicAPI(logger log.Logger, backend *backend.Backend) *PublicAPI {
	return &PublicAPI{
		logger:  logger.With(log.ModuleKey, "rpc.ynx"),
		backend: backend,
	}
}

func (api *PublicAPI) SetPreconfirmSigner(signer *PreconfirmSigner) {
	api.signer = signer
}

func (api *PublicAPI) PreconfirmTx(txHash common.Hash) (*PreconfirmReceipt, error) {
	if api.signer == nil {
		return nil, fmt.Errorf("preconfirm is disabled")
	}
	if api.backend == nil {
		return nil, fmt.Errorf("backend is not available")
	}

	head, err := api.backend.BlockNumber()
	if err != nil {
		return nil, err
	}
	issuedAt := uint64(time.Now().Unix())

	status := "pending"
	targetBlock := uint64(head) + 1

	if res, err := api.backend.GetTxByEthHash(txHash); err == nil && res != nil {
		status = "included"
		targetBlock = uint64(res.Height) // #nosec G115 -- chain height won't exceed uint64
	} else {
		pending, err := api.isPendingEthereumTx(txHash)
		if err != nil {
			return nil, err
		}
		if !pending {
			return nil, fmt.Errorf("tx not found (not pending, not included): %s", txHash.Hex())
		}
	}

	evmChainIDHex := (*hexutil.Big)(new(big.Int).Set(api.backend.EvmChainID))
	digest := txConfirmDigest(api.backend.ClientCtx.ChainID, api.backend.EvmChainID, txHash, status, targetBlock, issuedAt)
	sig, err := api.signer.SignDigest(digest)
	if err != nil {
		return nil, err
	}

	return &PreconfirmReceipt{
		Status:      status,
		ChainID:     api.backend.ClientCtx.ChainID,
		EVMChainID:  evmChainIDHex,
		TxHash:      txHash,
		TargetBlock: hexutil.Uint64(targetBlock),
		IssuedAt:    hexutil.Uint64(issuedAt),
		Signer:      api.signer.Address(),
		Digest:      digest,
		Signature:   sig,
	}, nil
}

func (api *PublicAPI) isPendingEthereumTx(txHash common.Hash) (bool, error) {
	if api.backend == nil || api.backend.ClientCtx.Client == nil {
		return false, fmt.Errorf("rpc client is not available")
	}

	mc, ok := api.backend.ClientCtx.Client.(cmtrpcclient.MempoolClient)
	if !ok {
		return false, fmt.Errorf("rpc client does not support mempool queries")
	}

	limit := 2000
	if v := strings.TrimSpace(os.Getenv("YNX_PRECONFIRM_MEMPOOL_SCAN_LIMIT")); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	res, err := mc.UnconfirmedTxs(api.backend.Ctx, &limit)
	if err != nil {
		return false, err
	}

	for _, txBz := range res.Txs {
		tx, err := api.backend.ClientCtx.TxConfig.TxDecoder()(txBz)
		if err != nil {
			continue
		}
		msg, err := evmtypes.UnwrapEthereumMsg(&tx, txHash)
		if err != nil {
			continue
		}
		if msg.Hash() == txHash {
			return true, nil
		}
	}

	return false, nil
}

func txConfirmDigest(chainID string, evmChainID *big.Int, txHash common.Hash, status string, targetBlock, issuedAt uint64) common.Hash {
	chainID = strings.TrimSpace(chainID)
	if chainID == "" {
		chainID = "unknown"
	}

	mode := byte(0)
	if strings.EqualFold(status, "included") {
		mode = 1
	}

	chainIDBz := []byte(chainID)
	if len(chainIDBz) > 65535 {
		chainIDBz = chainIDBz[:65535]
	}

	var evmID uint64
	if evmChainID != nil {
		evmID = evmChainID.Uint64()
	}

	buf := make([]byte, 0, len(txConfirmDigestPrefix)+1+2+len(chainIDBz)+8+32+8+8)
	buf = append(buf, []byte(txConfirmDigestPrefix)...)
	buf = append(buf, mode)

	var lenBz [2]byte
	binary.BigEndian.PutUint16(lenBz[:], uint16(len(chainIDBz)))
	buf = append(buf, lenBz[:]...)
	buf = append(buf, chainIDBz...)

	var u64 [8]byte
	binary.BigEndian.PutUint64(u64[:], evmID)
	buf = append(buf, u64[:]...)
	buf = append(buf, txHash.Bytes()...)
	binary.BigEndian.PutUint64(u64[:], targetBlock)
	buf = append(buf, u64[:]...)
	binary.BigEndian.PutUint64(u64[:], issuedAt)
	buf = append(buf, u64[:]...)

	return crypto.Keccak256Hash(buf)
}

func WritePreconfirmKeyFile(path string, privKeyHex string, overwrite bool) error {
	path = strings.TrimSpace(path)
	if path == "" {
		return fmt.Errorf("empty output path")
	}

	path = filepath.Clean(path)
	if !overwrite {
		if _, err := os.Stat(path); err == nil {
			return fmt.Errorf("file already exists: %s", path)
		}
	}

	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	privKeyHex = strings.TrimSpace(privKeyHex)
	privKeyHex = strings.TrimPrefix(privKeyHex, "0x")
	if _, err := hex.DecodeString(privKeyHex); err != nil {
		return fmt.Errorf("invalid privkey hex: %w", err)
	}

	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	defer f.Close()

	if _, err := f.WriteString(privKeyHex + "\n"); err != nil {
		return err
	}
	return nil
}
