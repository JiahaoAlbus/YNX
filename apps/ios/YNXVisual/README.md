# YNX Visual iOS

Native SwiftUI prototype for the YNX Web4 public testnet.

Design baseline:

- Apple Human Interface Guidelines: materials, layout, typography, motion, accessibility.
- White and Klein blue visual system.
- Glass panels with depth, restrained shadows, tactile spring motion, and high legibility.
- No custodial wallet or private-key handling in this prototype.

Core screens:

- Dashboard: chain identity, live health, AI/Web4 settlement flow.
- Network: endpoint monitor for RPC, REST, EVM, Faucet, Indexer, Explorer, AI Gateway, Web4 Hub.
- Validators: bonded validator overview and onboarding call-to-action.
- AI/Web4: policy, session key, vault, job, settlement visualization.
- Docs: canonical links into the existing YNX docs website.

Run options:

1. Open this folder in Xcode as a Swift Package and run the `YNXVisualApp` executable for local UI iteration.
2. If `xcodegen` is installed, run `xcodegen generate` in this folder to generate a native iOS `.xcodeproj`.

The app talks only to public testnet endpoints:

- RPC: `https://rpc.ynxweb4.com`
- REST: `https://rest.ynxweb4.com`
- EVM RPC: `https://evm.ynxweb4.com`
- Faucet: `https://faucet.ynxweb4.com`
- Indexer: `https://indexer.ynxweb4.com`
- Explorer: `https://explorer.ynxweb4.com`
- AI Gateway: `https://ai.ynxweb4.com`
- Web4 Hub: `https://web4.ynxweb4.com`
