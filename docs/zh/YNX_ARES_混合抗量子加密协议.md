# YNX ARES 混合抗量子加密协议

状态：active design baseline
最后更新：2026-04-30
规范语言：英文文档优先，本文为中文执行版

## 1. 名称

`YNX ARES` 全称是 `YNX Aegis Recursive Envelope Suite`。

这是 YNX 自己设计的高保证 Web4 动作保护协议。它不是新的签名算法、哈希函数、KEM、加密算法或随机数算法。安全的创新点是组合方式：经典密码 + 后量子密码 + 严格域隔离 + 递归信封 + 短会话 + fail-closed 策略验证。

## 2. 设计目标

ARES 用于抵抗：

- 经典私钥泄露和远程入侵；
- 未来量子计算对经典签名和密钥交换的威胁；
- 跨链、跨应用、跨策略、跨会话重放；
- AI agent 未授权委托；
- 静默 policy 篡改和权限扩大；
- 长期密钥暴露。

ARES 保持底层链兼容当前 EVM/Cosmos 工具，把更强验证放在 Web4 协议层、治理层、金库层和高权限动作层。

## 3. 密码原语

默认 profile：

- Hash：`SHA3-256` 或 `BLAKE3`，必须有显式域隔离；
- 经典账户签名：EVM 账户使用 `secp256k1`；
- 当前共识/服务兼容签名：按现有栈使用 Ed25519；
- 后量子签名：`ML-DSA-65`；
- 长期 emergency anchor：可选 `SLH-DSA`；
- 密钥协商：经典 ECDH/X25519 + `ML-KEM-768`；
- 对称加密：审计库中的 `AES-256-GCM` 或 `XChaCha20-Poly1305`；
- KDF：`HKDF-SHA3-256`，带 chain/app/policy/session 标签。

ARES v1 禁止使用自创密码原语。

## 4. ARES 信封

每个受保护动作都包装为：

```text
ARES_Envelope {
  version
  chain_id
  app_id
  account
  policy_id
  session_id
  capability_set
  nonce
  issued_at
  expires_at
  previous_envelope_hash
  payload_hash
  classical_pubkey_ref
  pq_pubkey_ref
  classical_signature
  pq_signature
}
```

签名摘要：

```text
digest = H(
  "YNX-ARES-v1" ||
  chain_id ||
  app_id ||
  account ||
  policy_id ||
  session_id ||
  capability_set ||
  nonce ||
  issued_at ||
  expires_at ||
  previous_envelope_hash ||
  payload_hash ||
  classical_pubkey_ref ||
  pq_pubkey_ref
)
```

信封哈希：

```text
envelope_hash = H("YNX-ARES-envelope-hash-v1" || canonical_envelope_without_signatures || classical_signature || pq_signature)
```

## 5. 验证规则

高价值动作必须严格验证：

```text
verify_ares(envelope, payload, policy):
  require envelope.version is supported
  require envelope.chain_id matches local chain
  require envelope.app_id matches local app
  require now <= envelope.expires_at
  require nonce has not been used for account + policy + session
  require H(payload) == envelope.payload_hash
  require policy authorizes envelope.capability_set
  require previous_envelope_hash matches policy/session chain when required
  require VerifyClassical(envelope.classical_pubkey_ref, digest, classical_signature)
  require VerifyPQ(envelope.pq_pubkey_ref, digest, pq_signature)
  accept only if all checks pass
```

兼容迁移期可以先进入 observe mode：

- 经典签名仍然强制；
- PQ 签名先记录、监控、审计；
- 钱包、SDK、验证库、审计完成前不强制全网启用。

## 6. 递归安全

ARES 是递归的，因为每个高权限动作都可以绑定上一层信封哈希：

- root owner 创建 policy envelope；
- policy 创建 session envelope；
- session 创建 agent-action envelope；
- 子信封引用父信封或前一个授权信封；
- 一旦 root/policy 撤销，依赖它的 session 和 agent action 全部失效。

这不替代区块链共识，而是在动作进入链之前保护授权链路。

## 7. 抗量子定位

ARES 处理两类量子风险：

- Shor 类风险：经典公钥密码可能被破坏，所以加入 `ML-DSA` 签名和 `ML-KEM` 密钥封装；
- Grover 类风险：对称密钥安全边际降低，所以高保证 profile 使用 256-bit 对称安全。

ARES 不承诺能防实现漏洞、终端失陷、内鬼、侧信道、供应链投毒或库本身漏洞。这些必须靠审计、密钥隔离、最小权限、日志、监控和事故响应处理。

## 8. 上线计划

1. 固化协议和威胁模型；
2. 在 SDK 中加入信封生成和验证；
3. 加 PQ credential registry；
4. 公测网 observe mode；
5. 审计 ARES 库和 registry；
6. 对治理、金库、升级、桥、root policy 强制双签；
7. 扩展到高价值 Web4 agent 动作。

当前实现锚点：

- `packages/sdk/src/ares.ts` 已提供 canonical payload hash、ARES digest、envelope hash、EVM 经典签名/恢复、strict mode、observe mode、nonce replay hook、policy check、可插拔后量子验证回调。
- `packages/sdk/test/ares.test.ts` 已覆盖 strict hybrid、observe mode、payload 篡改拒绝、nonce 重放拒绝、canonical JSON hash。
- 真正的 `ML-DSA` / `SLH-DSA` provider 必须在主网 strict enforcement 前接入经过审计的库。

## 9. 非目标

ARES v1 不做：

- 不替换当前活跃公测网的 CometBFT 共识签名；
- 不创建私有黑盒密码算法；
- 不托管用户资产；
- 不把 YNX 变成交易所、银行、稳定币发行方或 KYC 公司；
- 不承诺 NYXT 价格或投资收益。
