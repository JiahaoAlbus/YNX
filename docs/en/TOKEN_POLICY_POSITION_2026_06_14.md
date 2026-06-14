# YNX Token Policy Position

Status: active financing policy note  
Last updated: 2026-06-14  
Canonical language: English

## Purpose

This document separates current financing posture from older v0 tokenomics
drafts and testnet-oriented economics notes.

## What Investors Should Assume Today

- YNX is not being financed on a token-price-appreciation story.
- NYXT should be presented as a utility and coordination asset, not an
  investment promise.
- historical tokenomics drafts in this repository are not the same thing as a
  finalized mainnet or financing term sheet.

## Current Financing-Safe Position

Until a formal governance, legal, and disclosure process is complete:

- no founder fee should be assumed as a default production policy;
- future default fee policy should keep `fee_founder_bps = 0` unless changed by
  a separately justified governance process;
- team, treasury, and community allocations should be treated as unfinalized
  design space unless explicitly restated in an approved financing document;
- investor outreach should emphasize infrastructure revenue, not token rent.

Important live-state caveat:

- as of June 14, 2026, the public indexer overview still exposes a testnet
  runtime parameter set that includes `fee_founder_bps = 1000`;
- that live testnet parameter should be described as current runtime state, not
  as the financing policy investors are being asked to underwrite;
- if runtime parameters and financing language diverge, YNX should explain the
  difference explicitly rather than hoping diligence readers will infer it.

## Historical Documents

These older documents remain useful as implementation history, but should not be
treated as canonical financing terms:

- `docs/en/NYXT_Tokenomics_v0.md`
- `docs/en/Parameters_v0.md`
- `docs/en/X_YNX_Module.md`

## Recommended External Sentence

`YNX has historical tokenomics drafts in the repository, but current financing
materials do not ask investors to underwrite a founder-fee or token-speculation
story.`
