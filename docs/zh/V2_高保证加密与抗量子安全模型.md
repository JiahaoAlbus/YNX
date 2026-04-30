# YNX v2 高保证加密与抗量子安全模型

状态：active design baseline
最后更新：2026-04-30
规范语言：英文文档优先，本文为中文执行版

## 1. 安全承诺边界

YNX 不承诺“任何政府黑客或量子计算都永远无法破解”。这种绝对说法在密码学和安全工程上不成立。

YNX 的可防守目标是：

- 用分层密钥、权限隔离、短会话、监控、轮换和事故响应抵抗高强度攻击；
- 保持当前 EVM/Cosmos/CometBFT 生态兼容；
- 在 Web4、治理、金库、升级、AI agent 等高价值动作上引入“经典密码 + 后量子密码”的混合验证；
- 只使用公开标准、可审计、被密码学社区分析过的密码原语；
- 把所有高权限动作、委托、恢复和变更路径都写清楚、可审计、可回滚。

本文补充 `docs/en/V2_SECURITY_MODEL.md`。

## 2. 标准基线

YNX 高保证密码体系必须跟随以下公开标准：

- NIST FIPS 203：`ML-KEM`，标准化的后量子密钥封装机制；
- NIST FIPS 204：`ML-DSA`，标准化的后量子数字签名算法；
- NIST FIPS 205：`SLH-DSA`，标准化的无状态哈希签名算法；
- Apple PQ3 思路：混合后量子会话建立、密码敏捷性、持续重协商密钥；
- 交易所级运营安全：硬件密钥、阈值审批、最小权限、发布验签、不可篡改日志、应急响应、独立审计。

YNX 不自创新的哈希函数、签名算法、KEM、加密算法或随机数算法。YNX 自己创造的是协议组合方式：`YNX ARES`，见 `docs/zh/YNX_ARES_混合抗量子加密协议.md`。

## 3. 兼容分层

### Layer 0：当前链兼容层

当前公测网保持：

- EVM 账户：`eth_secp256k1` / Ethereum 兼容签名；
- CometBFT 共识验证人密钥：沿用栈要求的 Ed25519；
- 公共服务入口使用 TLS；
- 运维 SSH 私钥、助记词、服务密钥全部在 Git 仓库之外。

不能在当前活网直接替换共识签名算法，否则可能破坏验证人兼容性和出块能力。

### Layer 1：高保证运维层

主网候选前必须做到：

- 发布产物可复现或可独立重建；
- 验证人密钥、部署密钥尽量使用硬件保护；
- SSH 仅允许密钥登录，禁止密码登录，最小化 sudo 面；
- 高权限操作需要双人复核或阈值审批；
- 生产密钥不得出现在仓库、CI 日志、公开文档中；
- RPC、REST、EVM、faucet、indexer、explorer、AI、gateway 都有健康检查、日志、重启策略、告警；
- 发布包有校验和和签名来源证明。

### Layer 2：Web4 混合签名层

高价值 Web4 动作应使用混合信封：

- 经典签名：`secp256k1` 或 Ed25519；
- 后量子签名：默认 `ML-DSA-65`；
- 长期 root / emergency 恢复：可使用 `SLH-DSA`；
- 摘要必须包含 chain ID、app ID、policy ID、session ID、nonce、过期时间、能力集合、payload hash；
- 高价值动作在启用后必须“双签都通过”，否则 fail closed。

Layer 2 可以先在应用层、治理层、Web4 层上线，不破坏当前 EVM 账户兼容性。

### Layer 3：后量子账户迁移层

主网阶段需要：

- PQ credential registry：为账户、策略、验证人、部署者、AI agent 绑定后量子公钥；
- 治理、金库、升级、桥、root policy 使用混合验证；
- 老账户先添加 PQ credential，再进入强制执行；
- 经典密钥被量子威胁或泄露时有紧急轮换路径；
- 所有强制切换都先在公测网演练，再由治理确定时间表。

## 4. 威胁模型

YNX 明确防范：

- RPC、REST、EVM、faucet、indexer、explorer、AI、gateway 远程攻击；
- 云服务器、SSH 私钥、助记词泄露；
- 恶意验证人、停签、双签和共识异常；
- 依赖、构建系统、部署脚本、发布包供应链攻击；
- 未来量子计算对经典公钥密码的长期风险；
- 针对部署者、治理成员、验证人运营者的社工攻击。

YNX 不假设：

- 单一密钥或单一服务器永远安全；
- 硬件密钥在物理夺取后绝对安全；
- 一个安全控制就能保护资产、治理和用户信任。

## 5. 主网密码学门禁

公测网进入主网候选前必须完成：

1. 链逻辑、部署脚本、公共服务、特权合约外部审计；
2. `YNX ARES` 混合信封协议独立评审；
3. 可复现发布流程、签名校验和、回滚方案；
4. 验证人密钥仪式和恢复流程；
5. 治理、金库、升级、policy root 由多签或阈值审批保护；
6. 生产配置中没有占位密钥、测试私钥、默认密码；
7. 漏洞披露渠道或 bug bounty；
8. 至少一次事故响应桌面演练。

## 6. 非托管边界

安全等级高不等于要托管用户资产。

YNX 项目边界：

- 不碰用户资产；
- 不做托管；
- 不做交易所撮合；
- 不发行或管理稳定币；
- 不把 KYC 做成协议公司主营业务；
- 不把 NYXT 涨价作为商业模式承诺。

商业和合规边界见 `docs/zh/YNX_非托管商业与合规边界.md`。

## 7. 实施优先级

1. 先保护运维密钥和发布流程；
2. 再给 Web4 policy / session / agent envelope 加混合签名验证；
3. 增加 PQ credential registry 和 SDK；
4. 在公测网观察模式演练；
5. 审计通过后再对高价值动作强制混合验证。

当前 SDK 锚点：`packages/sdk/src/ares.ts` 已实现 ARES 信封构造与验证，并支持可插拔 PQ verifier。它适合公测网 observe mode 和审计评审；主网 strict mode 仍必须接入经过审计的 `ML-DSA` / `SLH-DSA` provider。

## 8. 参考

- NIST FIPS 203：`https://csrc.nist.gov/pubs/fips/203/final`
- NIST FIPS 204：`https://csrc.nist.gov/pubs/fips/204/final`
- NIST FIPS 205：`https://csrc.nist.gov/pubs/fips/205/final`
- Apple PQ3：`https://security.apple.com/blog/imessage-pq3/`
