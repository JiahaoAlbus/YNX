# YNX Open Testnet Next Steps

Status: Active  
Last updated: 2026-02-21  
Canonical language: English

## 1) Freeze Current Stable Baseline

```bash
cd ~/YNX/chain
./scripts/testnet_freeze_tag.sh
```

This writes a freeze report under `ops-logs/freeze/` and creates a timestamped git tag.

## 2) Open Validator Onboarding

Share these two docs publicly:

- `README.md` (Path B/C/D/G/H/I)
- `docs/en/VALIDATOR_ONBOARDING_PACKAGE.md`

Use safe onboarding for every new validator:

```bash
cd ~/YNX/chain
./scripts/validator_onboard_safe.sh
```

## 3) Keep Continuous Health Monitoring

Run watchdog on at least one operator machine:

```bash
cd ~/YNX/chain
./scripts/testnet_watchdog.sh
```

Optional webhook integration:

```bash
ALERT_WEBHOOK_URL="https://your-webhook-endpoint" ./scripts/testnet_watchdog.sh
```

## 4) Keep Public Access Layer Online

Maintain at least:

- 1 public RPC endpoint
- 1 public explorer endpoint
- 1 faucet endpoint

Verify quickly:

```bash
cd ~/YNX
./chain/scripts/public_testnet_verify.sh
```

## 5) Mainnet Readiness Gates

Before mainnet, require all items:

- Validator set is distributed (not single-operator controlled)
- Continuous stable block production window with no critical incidents
- Monitoring and incident response tested
- Public docs and onboarding process proven in open testnet
