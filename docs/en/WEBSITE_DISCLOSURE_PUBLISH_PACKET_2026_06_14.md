# YNX Website Disclosure Publish Packet

Status: active publication packet  
Last updated: 2026-06-14  
Canonical language: English

## Current Observed Gap

Observed on June 14, 2026:

- `https://www.ynxweb4.com/privacy` returns the same application shell as the
  homepage, not a standalone published privacy disclosure page.
- `https://www.ynxweb4.com/terms` returns the same application shell as the
  homepage, not a standalone published terms page.

This is a diligence-visible blocker for investor and enterprise-facing outreach.

Important wording boundary:

- repository drafts are not the same thing as website publication;
- until these routes are independently reachable, investor-facing materials
  should describe legal publication as in progress, not completed.

## Required Public Routes

Before broad investor outreach, the website should expose distinct public pages:

- `/privacy`
- `/terms`
- `/risk`
- `/security`

## Source Documents Ready For Publication

- Privacy: `docs/en/PRIVACY_POLICY_DRAFT_2026_06_13.md`
- Terms: `docs/en/TERMS_OF_USE_DRAFT_2026_06_13.md`
- Risk: `docs/en/RISK_DISCLOSURES_DRAFT_2026_06_13.md`
- Security: `SECURITY.md` and `docs/en/SECURITY_RESPONSE_POLICY_2026_06_13.md`

## Publication Requirement

The pages above should render as independently reachable website disclosures,
not as SPA fallbacks to the homepage shell.
