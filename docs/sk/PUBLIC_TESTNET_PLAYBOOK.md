# YNX Public Testnet Kompletný Návod (SK)

Stav: active  
Posledná aktualizácia: 2026-02-17

## Rýchla navigácia (klikni podľa potreby)

- Chcem len skontrolovať sieť → [Cesta 0](#cesta-0-bez-inštalácie-kontrola-siete)
- Potrebujem wallet adresu → [Cesta 1](#cesta-1-vytvor-wallet-len-keď-je-potrebný)
- Potrebujem test tokeny z faucet-u → [Cesta 2](#cesta-2-získaj-test-tokeny-z-faucetu)
- Chcem spustiť full node → [Cesta 3](#cesta-3-spusť-full-node)
- Chcem sa prihlásiť ako validator → [Cesta 4](#cesta-4-údaje-pre-validator-prihlášku)
- Prevádzkujem produkčný server → [Cesta 5](#cesta-5-operator-health-a-správa-služieb)
- Niečo zlyhalo → [Riešenie problémov](#riešenie-problémov)

## Konštanty siete

- Chain ID: `ynx_9002-1`
- EVM chain id (hex): `0x232a`
- Denom: `anyxt`
- Verejné RPC: `http://43.134.23.58:26657`
- Verejné EVM RPC: `http://43.134.23.58:8545`
- Verejné REST: `http://43.134.23.58:1317`
- Verejný Faucet: `http://43.134.23.58:8080`
- Verejný Explorer: `http://43.134.23.58:8082`
- Seed / peer bootstrap: `e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656`

## Cesta 0: Bez inštalácie, kontrola siete

```bash
curl -s http://43.134.23.58:26657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
curl -s http://43.134.23.58:8545 -H 'content-type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
curl -s http://43.134.23.58:8080/health
curl -s http://43.134.23.58:8081/ynx/overview | jq
```

Sledovanie blokov v reálnom čase:

```bash
while true; do h=$(curl -s http://43.134.23.58:26657/status | jq -r .result.sync_info.latest_block_height); echo "$(date '+%F %T') height=$h"; sleep 1; done
```

## Cesta 1: Vytvor wallet len keď je potrebný

Potrebné iba pre faucet, transakcie alebo validator operácie.

```bash
cd ~/YNX/chain
./ynxd keys add wallet --keyring-backend os --key-type eth_secp256k1
./ynxd keys show wallet --keyring-backend os --bech acc -a
./ynxd debug addr $(./ynxd keys show wallet --keyring-backend os --bech acc -a)
```

## Cesta 2: Získaj test tokeny z faucet-u

```bash
ADDR="<tvoja_ynx1_adresa>"
curl -s "http://43.134.23.58:8080/faucet?address=${ADDR}"
```

Kontrola zostatku:

```bash
cd ~/YNX/chain
./ynxd query bank balances "$ADDR" --node http://43.134.23.58:26657 --output json
```

## Cesta 3: Spusť full node

### 3.1 Nainštaluj závislosti (Ubuntu 22.04+)

```bash
sudo apt update
sudo apt install -y git curl jq build-essential
```

### 3.2 Nainštaluj Go (ak chýba)

```bash
if ! command -v go >/dev/null 2>&1; then
  curl -fsSL https://go.dev/dl/go1.23.6.linux-amd64.tar.gz -o /tmp/go.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc
  export PATH=/usr/local/go/bin:$PATH
fi
go version
```

### 3.3 Build binárky

```bash
cd ~
git clone https://github.com/JiahaoAlbus/YNX.git
cd ~/YNX/chain
CGO_ENABLED=0 go build -o ynxd ./cmd/ynxd
```

### 3.4 Stiahni najnovší testnet bundle

```bash
REL_API="https://api.github.com/repos/JiahaoAlbus/YNX/releases/latest"
BUNDLE_URL="$(curl -fsSL "$REL_API" | jq -r '.assets[] | select(.name|endswith(".tar.gz")) | .browser_download_url' | head -n1)"
SHA_URL="$(curl -fsSL "$REL_API" | jq -r '.assets[] | select(.name|endswith(".sha256")) | .browser_download_url' | head -n1)"

mkdir -p ~/.ynx-testnet/config /tmp/ynx_bundle
curl -fL "$BUNDLE_URL" -o /tmp/ynx_bundle.tar.gz
curl -fL "$SHA_URL" -o /tmp/ynx_bundle.sha256
(cd /tmp && shasum -a 256 -c ynx_bundle.sha256)
tar -xzf /tmp/ynx_bundle.tar.gz -C /tmp/ynx_bundle
cp /tmp/ynx_bundle/genesis.json ~/.ynx-testnet/config/genesis.json
cp /tmp/ynx_bundle/config.toml ~/.ynx-testnet/config/config.toml
cp /tmp/ynx_bundle/app.toml ~/.ynx-testnet/config/app.toml
```

### 3.5 Nastav peer a spusti node

```bash
PEER='e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656'
sed -i -E "s#^seeds = .*#seeds = \"$PEER\"#" ~/.ynx-testnet/config/config.toml
sed -i -E "s#^persistent_peers = .*#persistent_peers = \"$PEER\"#" ~/.ynx-testnet/config/config.toml

cd ~/YNX/chain
./ynxd start --home ~/.ynx-testnet --chain-id ynx_9002-1 --minimum-gas-prices 0anyxt
```

### 3.6 Over synchronizáciu

```bash
curl -s http://127.0.0.1:26657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
```

## Cesta 4: Údaje pre validator prihlášku

Najprv spusti node, potom:

```bash
cd ~/YNX/chain
./ynxd keys add validator --keyring-backend os --key-type eth_secp256k1
./ynxd keys show validator --keyring-backend os --bech acc -a
./ynxd keys show validator --keyring-backend os --bech val -a
./ynxd comet show-node-id --home ~/.ynx-testnet
./ynxd comet show-validator --home ~/.ynx-testnet
```

Pošli koordinátorovi:

- `node_id@public_ip:26656`
- `ynxvaloper...`
- `ynx1...`
- región/provider/kontakt

## Cesta 5: Operator health a správa služieb

Kompletný health-check:

```bash
cd ~/YNX
./chain/scripts/public_testnet_verify.sh
```

Lokálny health-check na serveri:

```bash
YNX_PUBLIC_HOST=127.0.0.1 ./chain/scripts/public_testnet_verify.sh
```

Systemd status:

```bash
sudo systemctl status ynx-node ynx-faucet ynx-indexer ynx-explorer --no-pager
```

Live log:

```bash
sudo journalctl -u ynx-node -f
```

Kontrolovaný upgrade (predvolene bez auto-update z Git):

```bash
cd ~/YNX
./chain/scripts/server_upgrade_apply.sh ubuntu@43.134.23.58 /Users/huangjiahao/Downloads/Huang.pem
```

## Riešenie problémov

- `go: command not found` → znova nainštaluj Go a nastav `PATH`.
- `gas prices too low` → zvýš gas price (napr. `0.000001anyxt`).
- `account not found` → najprv faucet/transfer, potom tx.
- `connection refused/timeout` zvonku → skontroluj firewall/security group.
- `faucet ip_rate_limited` → počkaj na rate-limit okno alebo zmeň IP.

## Súvisiace dokumenty

- `docs/en/PUBLIC_TESTNET_LAUNCHKIT.md`
- `docs/en/VALIDATOR_ONBOARDING_PACKAGE.md`
