# YNX iOS App Store Readiness

Status: native YNX Web4 public-testnet entry app prototype, App Store submission package scaffolded.

## Current App Identity

- App name: YNX
- Bundle ID: `com.ynxweb4.ynx`
- Version: `1.0.0`
- Build: `1`
- iPhone only, portrait orientation
- Public testnet only. Testnet tokens have no mainnet value. Mainnet is not live.

## Included For Submission

- Native SwiftUI iOS app shell
- App icon asset catalog generated from the YNX blue/white mark
- Launch screen with YNX mark
- Privacy manifest declaring no tracking and no collected data
- Wallet, transfer preparation, encrypted messaging, Web4 session, YNX Browser, network monitor, validators, AI/Web4 settlement, and docs surfaces
- Live endpoint checks with fallback copy that avoids implying mainnet value
- Local testnet identity material stored in Keychain
- DApp permission sheet with account/signature/message/session scopes and revocation UI
- Transaction review sheet with fee, total, risk, and testnet acknowledgement
- Security center toggles for biometric signing gate, hidden balances, simulation requirement, and developer testnet mode
- Brave-style mobile browser layout with compact top trust state, large web content area, bottom address bar, back/forward/reload, connect shield, and quick-open tray
- YNX Browser HTTPS-only encrypted route mode: typed URLs and navigations are upgraded from HTTP to HTTPS when enabled

## Required Before Real App Store Submission

- Replace generated logo assets with the final source PNG or vector master.
- Replace testnet identity derivation with audited secp256k1 + bech32 wallet generation and signing.
- Add transaction simulation, fee estimation, broadcast, receipt, and failure states against YNX RPC/REST.
- Add biometric unlock, seed backup verification, import validation, and wallet recovery education.
- Add dApp permission prompts for accounts, signatures, sessions, and encrypted messages.
- Complete a real privacy policy and support page on `ynxweb4.com`.
- Complete crypto/export compliance answers in App Store Connect.
- Avoid swap/exchange/ICO/securities-like flows unless licensed and legally reviewed.
- Run IPv6/NAT64, poor-network, cold-start, memory, and accessibility testing.
- For encrypted access to HTTP-only sites, build and audit a real YNX Encrypted Relay/proxy; an app alone cannot make an HTTP-only origin end-to-end encrypted.
- Add App Store screenshots for 6.9-inch and 6.5-inch iPhone sizes.
- Add a production privacy policy URL on `ynxweb4.com`.
- Create App Store Connect metadata: subtitle, description, keywords, support URL, marketing URL.
- Confirm export compliance for cryptography and answer App Store Connect encryption questions.
- Add Apple Developer team signing in Xcode.
- Run on a physical iPhone and validate poor-network behavior.
- Prepare review notes explaining that YNX is a public testnet monitor and AI/Web4 settlement explainer; testnet tokens have no mainnet value.
