# Accountability / Forensics Engine

YNX should treat the current V2 trace layer as the base of a broader
accountability and forensics engine rather than as the final architecture.

## Current decision

We adopt the following split:

- base layer in V2: `lot lineage + pro-rata taint tracking`
- protected operator/victim access: AI-assisted trace reports behind Web4
  policy/session
- future expansion: graph tracing, clustering, entity attribution, suspicious
  pattern detection, evidence chains, and case reports

This is better than stopping at a raw trace API because it gives YNX a path
from simple balance provenance toward evidence-backed accountability review.

## Why this strategy is better

The broader forensics engine strategy adds capabilities the current trace layer
alone does not yet cover:

- transaction flow graph traversal
- comparative taint models
- address clustering
- entity labeling
- suspicious-pattern detection
- evidence chains
- structured case reports

The current lot-lineage layer remains useful because it already provides:

- deterministic source-lot tracking
- proportional split inheritance
- balance composition analysis
- transaction-level lineage fragments

## Safety boundary

Tracing is observation and accountability only.

It does **not** grant:

- private transfer authority
- private seizure authority
- private freeze authority
- any right to self-help enforcement

Recommended enforcement flow:

1. user or operator requests a protected trace report
2. AI summarizes the trace in plain language
3. evidence is reviewed
4. any freeze/escalation action must pass a separate operator or compliance
   approval path

## Current protected access path

The AI gateway now supports:

- `ai.trace.report`

This action is designed to be called with:

- Web4 policy/session authorization
- optional internal trace-indexer token when the trace indexer is locked

Example:

```bash
POST /ai/actions/run
{
  "action": "ai.trace.report",
  "policy_id": "policy_xxx",
  "target": "ynx1...",
  "kind": "address"
}
```

The response returns:

- a human-readable summary
- the raw trace payload
- explicit guardrails showing this is observation-only

## Suggested next build steps

1. add a first-class case object and case repository
2. add evidence-chain generation for every claim
3. add multiple taint models: poison, FIFO, LIFO, specific-trace
4. add suspicious-pattern detectors
5. add risk scoring with explainable factors
6. add operator-only escalation actions as a separate path from tracing

## Limitation today

Today the system is strongest for:

- internal accountability review
- fraud tracing on tracked denoms
- victim-friendly explanation through AI

It is not yet a complete multi-chain forensic platform and should not be
described that way until the graph, attribution, pattern, and evidence layers
are fully implemented.
