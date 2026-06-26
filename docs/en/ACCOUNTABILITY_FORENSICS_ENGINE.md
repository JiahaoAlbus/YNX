# Accountability / Forensics Engine

YNX should treat the current V2 trace layer as the base of a broader
accountability and forensics engine rather than as the final architecture.

## Current decision

We adopt the following split:

- base layer in V2: `lot lineage + pro-rata taint tracking`
- protected operator/victim access: AI-assisted trace reports behind Web4
  policy/session
- accountability layer on top of V2: structured case reports, review logs, and
  operator escalation state
- future expansion: broader graph tracing and pluggable label providers

This means the strategy should be implemented as a strengthening of V2 rather
than as a disconnected V3. The lot-lineage layer remains the deterministic
source-of-truth, while the forensics layer explains, scores, clusters, and
escalates around that evidence.

This is better than stopping at a raw trace API or trying to assign a rigid
"serial number" to every post-merge coin fragment, because YNX needs to handle
splits, merges, and mixed balances without pretending that exact one-note
identity always survives. Lot lineage plus comparative taint models preserves
truth better than a fake exact-coin story.

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
- `ai.forensics.case.create`
- `ai.forensics.case.review`

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

The first structured case flow returns:

- `case_id`
- `subject`
- `trace`
- `traced_paths`
- `flow_graph`
- `taint_models`
- `risk`
- `evidence_chain`
- `suspicious_patterns`
- `entity_attribution`
- `address_clusters`
- `recommended_next_actions`
- `review_status`
- `review_logs`
- `escalation_status`
- `guardrails`

Current comparative taint output includes:

- `poison`
- `proRata`
- `fifo`
- `lifo`
- `specificTrace`

The case review flow now allows operators to:

- fetch a single case by id
- append manual review notes
- move a case through `open`, `under_review`, `escalated`,
  `freeze_requested`, `closed_no_action`, or `closed_confirmed`
- record escalation state without granting direct transfer/freeze authority

The trace indexer now also exposes a graph endpoint:

- `GET /trace/graph?kind=address&target=ynx1...&direction=both&max_depth=4`

This graph view returns:

- address nodes
- lot nodes
- tx nodes
- lineage edges with `source_lot_id`, `child_lot_id`, amount, taint, and depth

So the case layer can now include actual traced paths instead of only a flat
balance or transaction snapshot.

## Suggested next build steps

1. add broader transaction-graph traversal beyond current trace targets
2. expand clustering heuristics beyond shared lot/root-lineage signals
3. add pluggable entity label providers instead of first-pass inferred labels
4. add more suspicious detectors such as bridge hopping and time correlation
5. keep the enforcement boundary separate from evidence generation

## Limitation today

Today the system is strongest for:

- internal accountability review
- fraud tracing on tracked denoms
- victim-friendly explanation through AI

It is not yet a complete multi-chain forensic platform and should not be
described that way until the graph, attribution-provider, and broader
cross-network evidence layers are fully implemented.
