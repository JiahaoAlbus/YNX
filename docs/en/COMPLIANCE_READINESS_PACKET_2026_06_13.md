# YNX Compliance Readiness Packet

Status: working compliance packet  
Last updated: 2026-06-14  
Canonical language: English

## Purpose

This document is a practical compliance and company-readiness packet for YNX.
It is not legal advice. It is designed to help founders, counsel, investors,
and grant reviewers understand the operating boundary and the remaining legal
work before commercial scale-up.

## 1. Operating Position

Current recommended posture:

- non-custodial infrastructure company;
- no direct user asset custody;
- no centralized exchange or matching-engine claim;
- no stablecoin issuance or reserve-management claim;
- no consumer KYC business as a default product line;
- no investment-promise language around NYXT.

This posture is already aligned with
`docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md` and should remain
the baseline until counsel approves any expansion.

## 2. Jurisdiction-First Working Plan

Recommended default structure:

- Singapore operating company as the primary infrastructure and contracting
  entity;
- optional separate foundation or governance entity only if protocol
  stewardship, grants, or governance separation requires it later;
- optional Delaware C-Corp only if U.S. fundraising, enterprise sales, or
  hiring becomes a first-order need.

Rationale:

- current infra and operational narrative already point to Singapore;
- the product is easier to position as infrastructure than as a regulated
  financial service;
- Singapore offers a practical operating base, but digital-token rules still
  need active counsel review.

## 3. Official References To Re-Check With Counsel

The following official materials are directly relevant and should be part of
every legal review packet:

- MAS clarification on digital token service providers, published June 6, 2025:
  [MAS Clarifies Regulatory Regime for Digital Token Service Providers](https://www.mas.gov.sg/news/media-releases/2025/mas-clarifies-regulatory-regime-for-digital-token-service-providers)
- MAS AML/CFT notice for DTSPs:
  [FSM-N27 AML/CFT - DTSPs](https://www.mas.gov.sg/regulation/notices/fsm-n27-amlcft---dtsps)
- ACRA local company registration guide, last updated May 16, 2026:
  [Registering a local company via Bizfile](https://www.acra.gov.sg/register/business/registering-different-business-structures/local-company/registering-via-bizfile/)
- PDPC DPO onboarding guide, published April 14, 2026:
  [Kickstart Your Data Protection Journey](https://www.pdpc.gov.sg/organisations/resources/getting-started-as-a-data-protection-officer-dpo)
- PDPC PDPA overview:
  [PDPA Overview](https://www.pdpc.gov.sg/about/the-legislation/pdpa-overview)

Interpretation note:

- MAS clarified in June 2025 that certain digital-token service providers
  operating from Singapore may require licensing even when serving only
  customers outside Singapore.
- That means YNX should not casually expand from infrastructure tooling into
  custody, exchange, dealing, or token-service operations without fresh legal
  review.

## 4. Immediate Company Readiness Actions

These are the minimum commercial-compliance actions that should be completed:

1. Form the operating entity and appoint responsible owners.
2. Reserve company name and complete ACRA registration flow.
3. Set up accounting, tax, bookkeeping, and contract ownership.
4. Appoint and register a Data Protection Officer workflow internally.
5. Publish privacy policy, terms of use, risk disclosures, and security contact.
6. Maintain incident response and vulnerability disclosure process.
7. Keep a sanctions / KYB process for enterprise counterparties if needed.
8. Keep consumer-facing KYC out of protocol scope unless counsel approves it.

These are still represented in the repository as action items, not completed
facts. Investor-facing material should preserve that distinction.

## 5. Product Claims Allowed / Disallowed

Allowed:

- live public testnet;
- hosted infrastructure;
- AI settlement testing infrastructure;
- policy-bounded agent execution;
- EVM-compatible builder surfaces;
- testnet bridge evidence;
- limited public-testnet wrapped-asset and swap testing where documentation and
  route evidence exist.

Disallowed unless counsel and production controls say otherwise:

- custody;
- exchange;
- broker/dealer language;
- redeemable stablecoin language;
- production external asset redemption claims;
- "regulated in every jurisdiction" style claims;
- token appreciation or investment-return language.

## 6. Data Protection Baseline

YNX should assume PDPA-style obligations apply to any personal data it touches,
including:

- account emails;
- application logs tied to identifiable users;
- enterprise customer contacts;
- support tickets;
- analytics tied to user accounts or wallet-linked profiles.

Baseline actions:

- name a DPO owner;
- create internal retention and deletion rules;
- limit log retention and access;
- document third-party processors and cloud vendors;
- publish an external privacy notice;
- define breach escalation and notification workflow.

## 7. Token And Treasury Disclosures

Before fundraising or launch-scale outreach, YNX should consistently state:

- NYXT is a utility and governance asset, not a promised investment return;
- YUSD.test is a non-redeemable synthetic test asset;
- public-testnet wrapped assets are test representations, not claims of licensed
  production custody or redemption;
- treasury value is not the basis of business viability.

## 8. Required Website / Data Room Artifacts

The following should exist before broad investor or ecosystem outreach:

- company / project overview;
- architecture and live-status overview;
- risk disclosure page;
- terms of use draft;
- privacy policy draft;
- non-custodial boundary statement;
- security disclosure process;
- investor memo;
- diligence index;
- compliance readiness packet.

## 9. Remaining Red Flags To Resolve

- no final legal memo from external counsel is included yet;
- no production audit opinion is included yet;
- as of June 14, 2026, `https://www.ynxweb4.com/privacy` and `/terms` still
  return the website shell rather than standalone legal disclosure pages;
- `SECURITY.md` currently documents GitHub Advisory reporting, but a dedicated
  company-managed security alias still remains a readiness task;
- bridge narratives must remain carefully testnet-scoped;
- BSC/BNB route work should not drive regulatory or fundraising positioning.

## 10. Standard Disclaimer

Use this sentence consistently:

`YNX is currently a public-testnet infrastructure project. It should be
described as non-custodial software and hosted infrastructure unless and until
licensed, audited, and legally approved product lines are launched separately.`
