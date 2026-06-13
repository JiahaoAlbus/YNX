package ynx

import (
	"math/big"
	"path/filepath"
	"testing"

	"github.com/ethereum/go-ethereum/common"
)

func TestLoadPreconfirmSignerFromHex(t *testing.T) {
	t.Parallel()

	signer, err := LoadPreconfirmSignerFromHex("4c0883a6910395b37d6231471b5dbb6204fe5129617082790f5b0f1b2f6b0f62")
	if err != nil {
		t.Fatalf("expected signer to load, got error: %v", err)
	}
	if signer == nil {
		t.Fatal("expected signer, got nil")
	}
	if signer.Address() == (common.Address{}) {
		t.Fatal("expected non-zero signer address")
	}
}

func TestLoadPreconfirmSignersFromEnvThresholdValidation(t *testing.T) {
	t.Setenv("YNX_PRECONFIRM_PRIVKEY_HEXES", stringsJoin(
		"4c0883a6910395b37d6231471b5dbb6204fe5129617082790f5b0f1b2f6b0f62",
		"8f2a5594909a1f9d4b3e7c3dbf949015135c8db05d4953ea05559cc49aa3be53",
	))
	t.Setenv("YNX_PRECONFIRM_THRESHOLD", "2")

	signers, threshold, err := LoadPreconfirmSignersFromEnv()
	if err != nil {
		t.Fatalf("expected env signer load to succeed, got error: %v", err)
	}
	if len(signers) != 2 {
		t.Fatalf("expected 2 signers, got %d", len(signers))
	}
	if threshold != 2 {
		t.Fatalf("expected threshold 2, got %d", threshold)
	}

	t.Setenv("YNX_PRECONFIRM_THRESHOLD", "3")
	if _, _, err := LoadPreconfirmSignersFromEnv(); err == nil {
		t.Fatal("expected threshold validation error")
	}
}

func TestLoadPreconfirmSignerFromFile(t *testing.T) {
	dir := t.TempDir()
	keyPath := filepath.Join(dir, "preconfirm.key")
	if err := WritePreconfirmKeyFile(keyPath, "4c0883a6910395b37d6231471b5dbb6204fe5129617082790f5b0f1b2f6b0f62", false); err != nil {
		t.Fatalf("failed to write key file: %v", err)
	}

	signer, err := LoadPreconfirmSignerFromFile(keyPath)
	if err != nil {
		t.Fatalf("expected signer to load from file, got error: %v", err)
	}
	if signer == nil || signer.Address() == (common.Address{}) {
		t.Fatal("expected valid signer from file")
	}
}

func TestTxConfirmDigestDeterministicAndStatusSensitive(t *testing.T) {
	t.Parallel()

	txHash := common.HexToHash("0x1234")
	pendingA := txConfirmDigest("ynx_9102-1", bigIntFromUint64(9102), txHash, "pending", 100, 200)
	pendingB := txConfirmDigest("ynx_9102-1", bigIntFromUint64(9102), txHash, "pending", 100, 200)
	included := txConfirmDigest("ynx_9102-1", bigIntFromUint64(9102), txHash, "included", 100, 200)

	if pendingA != pendingB {
		t.Fatal("expected digest to be deterministic")
	}
	if pendingA == included {
		t.Fatal("expected status to affect digest")
	}
}

func TestWritePreconfirmKeyFileNoOverwrite(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	keyPath := filepath.Join(dir, "preconfirm.key")
	if err := WritePreconfirmKeyFile(keyPath, "4c0883a6910395b37d6231471b5dbb6204fe5129617082790f5b0f1b2f6b0f62", false); err != nil {
		t.Fatalf("failed to write initial key file: %v", err)
	}
	if err := WritePreconfirmKeyFile(keyPath, "4c0883a6910395b37d6231471b5dbb6204fe5129617082790f5b0f1b2f6b0f62", false); err == nil {
		t.Fatal("expected overwrite protection error")
	}
}

func stringsJoin(values ...string) string {
	return values[0] + "," + values[1]
}

func bigIntFromUint64(v uint64) *big.Int {
	return new(big.Int).SetUint64(v)
}
