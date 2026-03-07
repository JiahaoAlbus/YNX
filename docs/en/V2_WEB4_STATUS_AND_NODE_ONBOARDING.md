# YNX v2 Web4 Status, Positioning, and Node Onboarding

Status: Active  
Last updated: 2026-03-07  
Canonical language: English

## 1. What YNX v2 Web4 is

YNX v2 is positioned as an **AI-native Web4 execution chain**:

- EVM-first developer experience for wallets, contracts, tooling, and RPC integrations
- autonomous agent workflows as first-class product targets
- machine-payment and settlement primitives exposed as platform APIs
- Web3 sovereignty preserved above Web4 autonomy

The control model is explicit:

- **owner** is the root authority
- **policy** defines machine-readable limits
- **session key** is a temporary execution capability

In short, YNX v2 does **not** treat AI as an unbounded actor.  
It treats AI as a constrained execution participant inside a user-owned policy boundary.

## 2. What is already built in the current v2 track

The current repository already contains a working v2 Web4 stack with:

- chain bootstrap and local-complete run flow
- public-testnet deploy / verify / smoke scripts
- AI settlement gateway
- Web4 hub for identity, policy, session, agent, and intent lifecycle
- local multi-validator simulation
- company-ready packaging and handoff assets
- OpenAPI contracts for the AI and Web4 surfaces
- operator release bundle with binary, descriptor, bootstrap scripts, and role profiles

Operationally, the current state is:

- local full-stack v2 development path exists
- one-command local end-to-end verification path exists
- primary public-testnet server deployment path exists and has been verified
- generic node bootstrap now accepts release bundle, descriptor, or direct RPC
- indexer exposes a machine-readable network descriptor for operator automation

## 3. Main selling points

Users should choose YNX when they need:

### 3.1 AI-native execution

YNX is not only “a fast EVM chain with an AI app on top”.  
It exposes AI job settlement, vault funding, policy-limited automation, and audit trails as first-class system behavior.

### 3.2 Web3 sovereignty with Web4 autonomy

YNX keeps the user or operator above the agent:

- owner pause / resume / revoke
- policy-enforced spend and action ceilings
- short-lived execution sessions
- audit-first lifecycle records

This is the core difference from unconstrained agent execution.

### 3.3 Familiar developer surface

YNX keeps onboarding close to Ethereum-style workflows:

- EVM RPC
- contract-friendly environment
- API-based Web4 integration
- simple local bootstrap and smoke-testing paths

### 3.4 Operator-focused testnet ergonomics

YNX already includes:

- bootstrap scripts
- smoke tests
- watchdog scripts
- local multi-validator simulation
- release packaging paths

That makes it easier to iterate quickly before mainnet hardening.

## 4. How AI is integrated

AI is integrated through two service planes.

### 4.1 AI Settlement Gateway

Implemented in `infra/ai-gateway/server.js`.

This service provides:

- AI job lifecycle APIs (`/ai/jobs`)
- vault creation, deposit, status, and spend accounting (`/ai/vaults*`)
- programmable machine-payment charging (`/ai/payments/charge`)
- x402-style payment-gated resource flow (`/x402/resource`)
- settlement audit logs (`/ai/audit`)

The AI gateway is the economic plane for machine work.

### 4.2 Web4 Hub

Implemented in `infra/web4-hub/server.js`.

This service provides:

- wallet bootstrap and verification (`/web4/wallet/*`)
- owner-scoped policy creation and lifecycle (`/web4/policies*`)
- session issuance under policy constraints
- identity, agent, and intent lifecycle APIs
- controlled self-update and replication
- complete Web4 audit log (`/web4/audit`)

The Web4 hub is the control plane for autonomous execution.

### 4.3 Combined model

Together, the two services create this pattern:

1. bootstrap identity  
2. create owner policy  
3. issue bounded session  
4. create agent / intent  
5. settle machine work through vault-backed payments  
6. record the full trail for review, challenge, and finalization

This is the practical YNX interpretation of Web4.

## 5. Why node onboarding has felt harder than it should

The difficult part has not been “how blockchains work” in general.  
The difficult part has been the current maturity level of the v2 operator packaging.

The main reasons are:

### 5.1 Mixed generations during migration

The environment had both older v1 services and newer v2 services, with different ports and runtime assumptions.  
That created avoidable operator friction.

### 5.2 Bootstrap dependency on live RPC quality

The current bootstrap path relies on a live RPC source for status, trust data, and sometimes genesis retrieval.  
If the public RPC or `/genesis` path is inconsistent, onboarding becomes fragile.

### 5.3 Exact binary / genesis / app determinism matters

Validators must run the exact compatible binary and the exact compatible genesis.  
If not, state sync or block replay can fail with app-hash mismatches.

### 5.4 Public networking was not yet standardized enough

Some onboarding attempts depended on temporary tunnels and server-local workarounds.  
That is acceptable for debugging, but not acceptable as the public operator standard.

## 6. Can onboarding be made generic

Yes. It should be made generic, and the target design is straightforward.

Generic onboarding means a new operator should only need:

- one supported binary version
- one signed genesis file
- one chain-id
- one public seed / peer list
- one public RPC
- one bootstrap command

The public operator should **not** need private tunnels, manual genesis copying, or ad hoc port translation.

## 7. What the generic operator package should look like

YNX v2 should converge on this standard package:

### 7.1 Release bundle

A release archive with:

- `ynxd`
- `genesis.json`
- checksums
- chain-id
- seed / peer registry
- port map
- minimum gas price
- exact startup examples

### 7.2 One public bootstrap script

The bootstrap script should:

- accept a release bundle or stable metadata endpoint
- initialize node home
- install canonical config
- configure state sync only when healthy
- fall back to block sync safely
- print validator creation commands

### 7.3 Role-based profiles

Operators should choose one of three modes:

- validator
- full node
- public RPC

Each role should have a fixed, documented config profile.

### 7.4 Stable public metadata

YNX should publish a stable machine-readable network descriptor containing:

- chain-id
- binary version
- genesis checksum
- public RPC endpoints
- public seed / persistent peer list
- recommended ports
- minimum gas price

## 8. Is this level of onboarding difficulty unusual

No.  
Most early-stage chains have operator onboarding friction.

What mature chains do better is not that onboarding is magically simple.  
They package the complexity better:

- signed releases
- fixed docs
- deterministic binary matrix
- public snapshots / state-sync endpoints
- stable seeds and peers
- role-based install guides

So the answer is:

- **yes**, validator onboarding can be made much more generic
- **yes**, other chains also deal with the same underlying complexity
- **no**, they do not usually expose as much of that complexity to the operator once they are operationally mature

## 9. Current requirement for YNX v2

To reach public-operator quality, YNX v2 still needs:

- a single canonical public bootstrap profile
- stable public networking rules
- signed release bundle distribution
- deterministic validator onboarding verification
- removal of migration-era compatibility hacks from the operator path

That is an operator-packaging problem, not a product-definition problem.
