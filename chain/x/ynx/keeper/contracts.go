package keeper

import (
	"embed"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common/hexutil"
)

//go:embed contracts/*.json
var contractsFS embed.FS

type hardhatArtifact struct {
	ABI      json.RawMessage `json:"abi"`
	Bytecode string          `json:"bytecode"`
}

func loadHardhatArtifact(contractName string) (abi.ABI, []byte, error) {
	path := fmt.Sprintf("contracts/%s.json", contractName)
	bz, err := contractsFS.ReadFile(path)
	if err != nil {
		return abi.ABI{}, nil, err
	}

	var art hardhatArtifact
	if err := json.Unmarshal(bz, &art); err != nil {
		return abi.ABI{}, nil, err
	}

	parsed, err := abi.JSON(strings.NewReader(string(art.ABI)))
	if err != nil {
		return abi.ABI{}, nil, err
	}

	bytecode, err := hexutil.Decode(art.Bytecode)
	if err != nil {
		return abi.ABI{}, nil, err
	}

	if len(bytecode) == 0 {
		return abi.ABI{}, nil, fmt.Errorf("empty bytecode for %s", contractName)
	}

	return parsed, bytecode, nil
}
