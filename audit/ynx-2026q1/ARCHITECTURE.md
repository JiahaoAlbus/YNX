# YNX Architecture Brief for Auditors

Status: draft
Owner: Huangjiahao
Last Updated: 2026-03-27

## System Summary

YNX is an AI-native Web4 execution chain with dual Cosmos/EVM developer surface.
Current network track: public testnet (`ynx_9102-1`).

## Core Components

- Chain node (`ynxd`) and consensus layer
- EVM compatibility layer
- Indexer / explorer data path
- AI gateway (`/ai/*`)
- Web4 hub (`/web4/*`)

## Security-Critical Boundaries

1. Authorization hierarchy and delegation chain
2. Value-transfer and staking state transitions
3. EVM/Cosmos execution consistency assumptions
4. API surfaces that can trigger stateful execution and settlement

## Intended Trust Model

- Human owner authority at root
- Policy-constrained sessions for delegated execution
- No unauthorized privilege escalation across session boundaries

## Runtime References

- RPC: `https://rpc.ynxweb4.com`
- EVM RPC: `https://evm.ynxweb4.com`
- Indexer: `https://indexer.ynxweb4.com/ynx/overview`
- Explorer: `https://explorer.ynxweb4.com`
