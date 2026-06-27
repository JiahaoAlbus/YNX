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

In practical terms:

- keep exact lineage where the system really has exact lineage
- keep proportional lineage where balances have merged or split
- expose multiple taint interpretations side by side instead of pretending a
  single irreversible interpretation is always correct

So the answer is: yes, this strategy is better, but specifically because it is
more honest about fungible-asset reality than a universal serial-number model.

## Explicit product recommendation

If the question is "should YNX switch to a per-coin permanent serial-number
model like physical cash notes?", the answer is no.

If the question is "should YNX strengthen accountability by adding stable
origin identifiers, richer lineage, more taint models, better case reports, and
broader detector/provider layers?", the answer is yes.

Recommended product line:

- keep `lot lineage + pro-rata taint tracking` as the canonical V2 truth layer
- keep immutable `issuance_id` and optional `deposit_batch_id` anchors at lot
  creation for stronger mint/deposit provenance
- preserve exact lineage only where exact lineage really exists
- preserve proportional ancestry after merges and splits
- make any stronger enforcement or freeze action a separate reviewed path

This gives YNX the accountability benefits of stable provenance references
without claiming that every smallest post-merge fungible fragment still has one
exact lifelong identity.

## V2 versus V3

This belongs in V2 as a strengthening of the current architecture, not as a
marketing-only V3 reset.

Use the following distinction:

- `V2 trace`: current deterministic lot-lineage evidence layer
- `V2 accountability`: protected case, review, escalation, evidence, and risk
  workflows on top of that evidence
- potential future `V3`: a broader multi-network forensic fabric only if YNX
  later normalizes multiple ledger models, cross-network provenance proofs, and
  independent forensic storage/indexing

So the right near-term decision is:

- do not replace the current V2 lineage model
- do not describe the system as permanent per-unit coin serial tracking
- continue deepening the current V2 trace/accountability stack

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
- `ai.forensics.case.read`

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
- `cluster_summary`
- `provenance_anchors`
- `case_dossier`
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

Protected read boundary:

- case list/detail reads should stay policy-scoped behind Web4 sessions
- cross-policy case fetch or mutation should be denied
- public explorer/search may show redacted evidence previews, but operator case
  records are not a public feed

The trace indexer now also exposes a graph endpoint:

- `GET /trace/graph?kind=address&target=ynx1...&direction=both&max_depth=4`

That endpoint is intended to stay protected. Public search and public explorer
surfaces should only expose a redacted graph preview.

This graph view returns:

- address nodes
- lot nodes
- tx nodes
- lineage edges with `source_lot_id`, `child_lot_id`, amount, taint, and depth
- path-level traversals that summarize upstream/downstream routes across those
  edges

The public preview version intentionally omits:

- lot-level transfer ids
- tainted-amount fields
- the full lot-node graph payload needed for exact reconstruction

This keeps public accountability evidence useful while preserving the protected
detail surface for operator, victim-support, and compliance review flows.

So the case layer can now include actual traced paths instead of only a flat
balance or transaction snapshot.

Entity attribution is now split into provider layers:

- configured static labels from `AI_ENTITY_LABELS_JSON` or `AI_ENTITY_LABELS_FILE`
- inferred fallback labels from current live trace/context rules

This means YNX can keep the current self-contained behavior while gaining a
clean path to richer local datasets or future external label sources without
rewriting case logic.

Suspicious pattern detection is now split across:

- direct trace-state detectors such as mixed exposure and root concentration
- graph-driven detectors such as rapid multi-hop transfers, amount-preserving
  hops, bridge-hop exposure, pass-through wallet behavior, time-correlated
  routing, and dormant-wallet reactivation

That makes the case layer materially better at explaining suspicious routing
instead of only flagging end-state balances.

Cluster output is now also more than a single shared-root heuristic. It can
combine:

- shared root origins
- linked counterparties from the traced graph
- bridge-route exposure
- multi-asset path hints
- fragmented lot-owner distribution

So the case object can summarize not just that addresses are related, but why
they are grouped and which heuristic families contributed.

The case object now also includes a dossier layer so operators do not have to
manually stitch together risk, evidence, clusters, and next steps. The dossier
contains:

- `primary_disposition`
- `operational_state`
- `subject_profile`
- `key_findings`
- `evidence_index`
- `action_queue`

The trace layer now also preserves stable provenance anchors on traced lots and
graph edges:

- `issuance_id`
- `deposit_batch_id`

Those anchors are meant for source-lot or deposit-batch continuity, not as a
claim that every final fungible fragment has a lifelong unique per-unit
identity.

This makes the protected case surface closer to a real operator work item
instead of a loose bundle of raw analysis fields.

## Suggested next build steps

1. add broader transaction-graph traversal beyond current trace targets
2. add more attribution providers and detector families
3. keep the enforcement boundary separate from evidence generation

## Limitation today

Today the system is strongest for:

- internal accountability review
- fraud tracing on tracked denoms
- victim-friendly explanation through AI

It is not yet a complete multi-chain forensic platform and should not be
described that way until the graph, attribution-provider, and broader
cross-network evidence layers are fully implemented.
