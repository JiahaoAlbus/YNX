# YNX iOS Feature Manual

Status: testnet active  
Last updated: 2026-05-10

## 1. Scope

This manual covers the current YNX iOS client (`YNX`) and maps every shipped testnet capability to a concrete app entry point.

The app is a public-testnet client. Tokens are testnet-only and have no mainnet value.

## 2. Feature Entry Map

### Home

- `Home -> Wallet`: create/import wallet, refresh balance, manage permissions.
- `Home -> Faucet`: open faucet flow and request testnet tokens.
- `Home -> Transfer`: prepare transfer draft.
- `Home -> Browser`: open YNX in-app browser and dApp connect flow.
- `Home -> AI Agent Session`: issue policy/session for machine actions.
- `Home -> Third-party API Test`: policy-bounded authorization for arbitrary APIs.
- `Home -> Cross-chain Bridge`: bridge gateway method and cross-chain flow entry.
- `Home -> AI Settlement`: live AI gateway stats and settlement lane.
- `Home -> Docs & Manual`: open docs hub and operation manuals.
- `Home -> Live Network Monitor`: endpoint health checks.

### Wallet

- Local testnet wallet create/import/remove.
- Balance refresh from `rest.ynxweb4.com`.
- dApp permission list and revoke.
- Security center toggles and runtime boundary hints.

### Flow

- `Transfer`: transfer draft with fee/risk preview.
- `Broadcast`: submit signed `tx_bytes` to testnet REST.
- `Faucet`: token request with rate-limit handling.
- `Bridge`: open universal bridge method, EVM RPC, and explorer.
- `Message`: encrypted message envelope generation.
- `Session`: issue live Web4 policy + session key.
- `Third-party`: authorize and test arbitrary API actions under policy limits.

### AI

- Live AI Gateway stats panel.
- Settlement sequence visualization and runtime status.

### Browser

- In-app browsing for portal/explorer/faucet/AI/Web4.
- Permissioned dApp connect prompt and origin scopes.
- HTTPS preference mode for navigations.

### Network

- Live health probes for RPC/REST/EVM/Faucet/Indexer/Explorer/AI/Web4.
- Canonical network facts (chain IDs, denom, testnet flags).
- Validator view (bonded validator snapshots).

### Docs

- Public testnet onboarding docs.
- AI/Web4 official demo docs.
- Universal bridge method docs.
- API references (Web4 + AI settlement).
- Operational scripts (third-party authorize demo and launch-grade monitor).

## 3. Cross-chain Status (Current)

Completed in repository and integrated as app entry:

- Universal bridge gateway contract path.
- Asset onboarding manifest/script path.
- Bridge method documentation and explorer/RPC entry links.

Still required for full TRON-level product readiness:

- Production relay/guardian operations.
- Liquidity routing and market-making layer.
- Public multi-asset UX with slippage/quote lifecycle.

## 4. Validation Checklist

Before each release candidate:

1. Build `YNX` iOS app (simulator and device targets).
2. Verify wallet creation/import and balance refresh.
3. Verify faucet request and rate-limit behavior.
4. Verify transfer draft + broadcast path.
5. Verify Web4 session and third-party authorization flow.
6. Verify bridge docs/RPC/explorer entries from app.
7. Verify network monitor endpoint statuses.
8. Verify docs links and script references are reachable.
