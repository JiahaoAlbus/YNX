# YNX Validator Signup Google Form Template

Status: Active  
Last updated: 2026-02-17  
Canonical language: English

## 1. Form Metadata

- Form title: `YNX Public Testnet Validator Signup`
- Form description:
  `Apply to join the YNX public testnet validator set. Submit accurate endpoint and security contact information.`

## 2. Questions (Copy to Google Form)

1. Operator name  
Type: Short answer  
Required: Yes

2. Moniker  
Type: Short answer  
Required: Yes

3. Validator account address (`ynx1...`)  
Type: Short answer  
Required: Yes

4. Validator operator address (`ynxvaloper1...`)  
Type: Short answer  
Required: Yes

5. Node ID  
Type: Short answer  
Required: Yes

6. P2P endpoint (`node_id@public_ip:26656`)  
Type: Short answer  
Required: Yes

7. Server region  
Type: Dropdown  
Options: `US-East`, `US-West`, `EU`, `APAC`, `Other`  
Required: Yes

8. Hosting provider  
Type: Dropdown  
Options: `AWS`, `GCP`, `Azure`, `Hetzner`, `OVH`, `Bare Metal`, `Other`  
Required: Yes

9. Server specification  
Type: Paragraph  
Placeholder: `CPU / RAM / SSD / Bandwidth`  
Required: Yes

10. Security contact email  
Type: Short answer  
Required: Yes

11. Uptime commitment  
Type: Multiple choice  
Options: `>=99.9%`, `99%-99.9%`, `<99%`  
Required: Yes

12. Monitoring/dashboard URL  
Type: Short answer  
Required: No

13. Additional notes  
Type: Paragraph  
Required: No

## 3. Confirmation Message

Set form confirmation message to:

`Thanks for applying. The YNX coordinator will review your endpoint reachability and contact you via email if approved.`

## 4. Auto-Review Pipeline

After collecting submissions:

1. Export responses to CSV.
2. Extract `p2p_endpoint` column into a text file.
3. Run:

```bash
cd chain
./scripts/testnet_candidate_audit.sh --input /path/to/p2p_endpoints.txt
```

4. Move `approved` rows into onboarding queue.
