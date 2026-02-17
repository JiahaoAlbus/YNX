# YNX Validator Signup and Review Template

Status: Active  
Last updated: 2026-02-17  
Canonical language: English

## 1. Intake Fields (Required)

- Application ID
- Submission time (UTC)
- Operator name
- Moniker
- Validator account (`ynx1...`)
- Validator operator (`ynxvaloper1...`)
- Node ID
- P2P endpoint (`node_id@ip:26656`)
- Server region
- Hosting provider
- CPU / RAM / SSD
- Security contact email
- Uptime target
- Public dashboard URL (optional)
- Explorer profile URL (optional)

## 2. Eligibility Rules

- `node_id@ip:26656` must be reachable from external network.
- Region/provider concentration should be controlled; avoid single-provider majority.
- Security contact must be valid and responsive.
- Operator must run independent infrastructure (no shared key custody).

## 3. Review Status Values

- `pending`
- `network_check_failed`
- `security_check_failed`
- `approved`
- `rejected`
- `onboarded`

## 4. Reviewer Checklist

- Node endpoint reachable and stable for 24h.
- Validator keypair format valid (`ynx1...`, `ynxvaloper1...`).
- No duplicate IP / duplicate node ID in active set.
- Region/provider diversity improves current set.
- Contact channel verified.

## 5. Coordinator Commands

Check connectivity:

```bash
nc -vz <validator-ip> 26656
```

Check node reachable on P2P and ID consistency:

```bash
curl -s http://<validator-ip>:26657/status
```

List active validators:

```bash
cd chain
./ynxd query staking validators --node http://38.98.191.10:26657
```

## 6. CSV Template

Use this header in your tracker sheet:

```csv
application_id,submitted_at_utc,operator_name,moniker,account_address,valoper_address,node_id,p2p_endpoint,region,provider,cpu,ram_gb,ssd_gb,security_email,uptime_target,status,reviewer,notes
```
