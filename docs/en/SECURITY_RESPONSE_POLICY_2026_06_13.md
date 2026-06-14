# YNX Security Response Policy

Status: active working policy  
Last updated: 2026-06-14  
Canonical language: English

## Purpose

This document upgrades YNX security handling from an informal open-source
contact path into a repeatable operating policy. It does not pretend YNX
already has a 24/7 institutional security team. It defines the minimum process
needed to behave credibly while the project hardens from public testnet toward
commercial infrastructure.

## 1. Current Maturity Statement

True today:

- YNX has a working private disclosure path.
- YNX has public infrastructure that can be exercised and regression-tested.
- YNX can patch code, update runbooks, and ship operator-facing remediation.

Not true yet:

- no formal bug bounty program;
- no published third-party audit opinion covering the full stack;
- no promise of round-the-clock staffed incident response;
- no claim that public-testnet bridge routes equal production custody controls.

Any investor, partner, or reviewer should treat this as an honest testnet-era
security operating policy, not as evidence that the entire stack is already
institution-grade.

## 2. Intake Channels

Primary private intake:

- GitHub Security Advisory for this repository

Fallback intake:

- a private contact request through the official website asking for a
  security-reporting channel

Current maturity caveat:

- GitHub Advisory is the only explicitly documented dedicated intake path today;
- a company-managed security alias remains a readiness task, not a completed
  control.

Reporters should include:

- affected component;
- impact summary;
- reproduction steps or proof of concept;
- whether the issue is public or already exploited;
- preferred contact method for follow-up.

## 3. Severity Bands

### Critical

Examples:

- unauthorized mint, release, settlement, or policy bypass;
- remote code execution on public infrastructure;
- bridge or signer abuse enabling unapproved asset movement;
- authorization bypass in AI/Web4 protected actions.

Target handling:

- immediate acknowledgement if seen;
- same-day triage when maintainers are available;
- best-effort mitigation before broad disclosure.

### High

Examples:

- persistent privilege escalation;
- exploitable data exposure tied to public services;
- replay, forged result, or session misuse with material impact.

Target handling:

- acknowledgement within 3 business days;
- remediation plan within 7 business days where reproducible.

### Medium / Low

Examples:

- denial-of-service hardening gaps;
- non-default misconfiguration hazards;
- weak documentation that could lead operators into unsafe deployment.

Target handling:

- patch in normal release flow;
- add test or doc hardening where practical.

## 4. Response Workflow

1. Confirm receipt privately.
2. Reproduce and classify severity.
3. Decide whether immediate operator mitigation is needed.
4. Patch code and add regression coverage where possible.
5. Update docs, runbooks, and deployment guidance if behavior changes.
6. Publish an advisory or changelog note once disclosure is safe.

## 5. Public-Testnet Specific Rules

- Testnet-only assets must never be described as production funds.
- Bridge route evidence must remain explicitly testnet-scoped.
- If a vulnerability affects safety claims, public wording must be downgraded
  immediately rather than left ambiguous.
- If a service is degraded, YNX should prefer honest status pages and operator
  notes over silent partial failure.

## 6. Minimum Operational Evidence

YNX should keep the following current:

- `SECURITY.md`
- regression tests for known auth and transport hardening fixes
- public readiness and security-gate probe outputs
- incident-impact notes when operator behavior must change

## 7. Gaps Still To Close

Before claiming institution-grade security readiness, YNX still needs:

- external audit coverage for chain-critical and bridge-critical paths;
- formal key-management policy with hardware-backed signer expectations;
- named on-call ownership beyond a single founder path;
- production-grade incident drill records;
- public security contact that is organizational, not personal.

## 8. Standard External Sentence

Use this exact level-setting sentence when needed:

`YNX has a functioning private disclosure path and active regression hardening,
but it is still a public-testnet infrastructure stack and should not be
described as fully institution-grade security operations yet.`
