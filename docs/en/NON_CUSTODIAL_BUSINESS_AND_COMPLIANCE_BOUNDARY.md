# YNX Non-Custodial Business and Compliance Boundary

Status: Active business baseline
Last updated: 2026-04-30
Canonical language: English

## 1. Product Boundary

YNX should operate as a non-custodial Web4 infrastructure and protocol company.

Default boundaries:

- YNX does not custody user assets.
- YNX does not run an exchange or matching engine.
- YNX does not issue a stablecoin or manage stablecoin reserves.
- YNX does not run KYC as its core business.
- YNX does not promise NYXT price appreciation.

Users and validators keep their own keys. Applications may integrate wallets, identity providers, compliance vendors, or regulated financial partners, but that does not make the base protocol a custodian or exchange.

## 2. What YNX Can Sell

YNX can earn revenue without touching user assets:

- hosted RPC, REST, gRPC, EVM, indexer, explorer, and status APIs;
- enterprise Web4 / AI-agent infrastructure subscriptions;
- paid SLA endpoints, private deployments, and support contracts;
- validator, node, monitoring, and disaster-recovery tooling;
- SDKs, API keys, developer dashboards, analytics, and usage-based billing;
- security audits, integration support, and certification for ecosystem projects;
- marketplace listing fees for apps, agents, domains, and verified integrations where legally appropriate;
- protocol fees if approved by governance and clearly disclosed;
- grants, ecosystem partnerships, and foundation programs.

The company should be able to survive even if token-market revenue is zero.

## 3. If NYXT Becomes Worthless

The company must not depend on NYXT price to pay operating expenses.

Plan:

- price enterprise SaaS, API, support, and deployment contracts in fiat or stable external settlement rails handled by regulated providers;
- keep NYXT useful for gas, staking, governance, spam control, and protocol alignment, not as the only business model;
- maintain a runway budget independent of treasury token mark-to-market value;
- publish token-risk language: NYXT may have no market value and should not be marketed as an investment promise;
- use protocol fees only as upside, not as the base survival assumption.

If NYXT trades at zero, YNX can still earn from hosted infrastructure, enterprise integrations, support, audits, and private Web4 deployments.

## 4. KYC Boundary

The base protocol should not become a KYC business.

Practical rule:

- no KYC for reading the chain, building apps, running open-source software, or self-custody;
- no direct handling of fiat on/off-ramp identity workflows by the protocol company unless counsel approves and licenses are in place;
- if a regulated partner needs KYC, the partner performs it under its own compliance program;
- enterprise contracts may require business due diligence, sanctions screening, or KYB, which is different from turning YNX into a consumer KYC provider.

## 5. Jurisdiction Strategy

This is not legal advice. Final structure must be reviewed by counsel.

Pragmatic default:

- Singapore operating company for Asia-facing Web3/Web4 infrastructure, enterprise contracts, and Tencent Cloud Singapore operations.
- Optional foundation or governance entity only if token governance, grants, or public-goods stewardship require it.
- Optional Delaware C-Corp only if U.S. venture financing, U.S. enterprise sales, or U.S. hiring becomes a primary requirement.

Singapore is a strong default because the current public infrastructure is in Singapore and the project wants an infrastructure/protocol posture rather than custody, exchange, stablecoin issuance, or consumer KYC.

The project should avoid launching regulated services until counsel confirms whether licensing is needed in the target market. This is especially important in Singapore because MAS clarified in 2025 that certain digital-token service providers need licensing, while services only involving utility or governance tokens are not impacted by that specific new regime.

## 6. Mainnet Go/No-Go Business Gates

Before mainnet:

1. legal memo confirming non-custodial, non-exchange, non-stablecoin, and no-consumer-KYC scope;
2. public terms explaining testnet/mainnet risk and no investment promise;
3. security audit and incident-response process;
4. entity and accounting setup for fiat revenue;
5. commercial API/SLA pricing independent of NYXT market price;
6. ecosystem governance rules that separate protocol stewardship from company revenue operations.

## 7. External Regulatory Reference

Singapore regulatory treatment can change. Re-check Monetary Authority of Singapore guidance before offering any digital-token service from Singapore or to Singapore users.

- MAS DTSP clarification: `https://www.sgpc.gov.sg/api/file/getfile/MAS%20Media%20Release%20-%20Clarification%20Statement%20on%20DTSP%20Regulatory%20Regime.pdf?path=%2Fsgpcmedia%2Fmedia_releases%2Fmas%2Fpress_release%2FP-20250606-1%2Fattachment%2FMAS+Media+Release+-+Clarification+Statement+on+DTSP+Regulatory+Regime.pdf`
- ACRA local company registration: `https://www.acra.gov.sg/register/business/registering-different-business-structures/local-company/registering-via-bizfile/`
