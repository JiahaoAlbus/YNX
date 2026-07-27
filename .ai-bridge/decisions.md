# YNX 30 Decisions

Updated: 2026-07-27T14:32:45Z

1. Treat repository and remote evidence as authoritative over archived chat summaries.
2. Keep the product ACTIVE because both current GitHub workflows are red and external release states remain false.
3. Preserve the nine release states independently; a current local test pass does not change installation, integration, staging, public, hosting, signing or store states.
4. Do not mutate a cluster or contact a production provider while CI and current-source artifact evidence are incomplete.
5. Build new artifacts only from a clean Git archive and keep any local signature classified as test/ephemeral.
6. Do not rewrite historical artifact records. Add a current-source record and select it only after its verification passes.
7. Record GitHub TLS failures as an evidence-access blocker, not as a CI explanation; continue local reproduction until exact logs are available.
8. Maintain all external inputs as references/metadata only. Never request secret values, private keys, PEM material or production credentials in chat.
