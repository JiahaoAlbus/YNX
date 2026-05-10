# YNX iOS 功能手册

状态：测试网可用  
最后更新：2026-05-10

## 1. 手册范围

本手册对应当前 iOS 客户端 `YNX`，用于说明每个已上线测试网功能在 App 内的入口位置。

说明：本 App 面向公开测试网，代币仅用于测试，无主网价值。

## 2. 功能入口总览

### Home

- `Home -> Wallet`：创建/导入钱包、刷新余额、管理 dApp 权限。
- `Home -> Faucet`：领取测试代币。
- `Home -> Transfer`：发起转账草拟流程。
- `Home -> Browser`：打开内置浏览器和 dApp 连接。
- `Home -> AI Agent Session`：签发策略与会话令牌。
- `Home -> Third-party API Test`：在策略约束下测试任意第三方 API。
- `Home -> Cross-chain Bridge`：跨链桥方法和入口。
- `Home -> AI Settlement`：查看 AI 结算链路和实时状态。
- `Home -> Docs & Manual`：打开文档与操作手册。
- `Home -> Live Network Monitor`：查看网络实时健康状态。

### Wallet

- 本地测试网钱包创建/导入/移除。
- 从 `rest.ynxweb4.com` 拉取余额。
- 查看和撤销 dApp 权限。
- 安全中心开关与安全边界提示。

### Flow

- `Transfer`：转账草拟（含费用/风险预览）。
- `Broadcast`：将签名后的 `tx_bytes` 广播到测试网 REST。
- `Faucet`：水龙头领币（含限流提示）。
- `Bridge`：打开通用跨链桥方法文档、EVM RPC、浏览器。
- `Message`：生成加密消息封装。
- `Session`：签发 Web4 策略与会话令牌。
- `Third-party`：对第三方 API 做策略授权并验证调用。

### AI

- 查看 AI Gateway 实时指标。
- 查看结算流程状态。

### Browser

- 内置访问 portal/explorer/faucet/AI/Web4。
- dApp 权限弹窗授权。
- HTTPS 优先导航策略。

### Network

- 实时探测 RPC/REST/EVM/Faucet/Indexer/Explorer/AI/Web4。
- 展示链 ID、币种等网络基础信息。
- 验证人状态视图。

### Docs

- 公开测试网加入文档。
- AI/Web4 官方演示文档。
- 通用跨链桥方法文档。
- Web4 API、AI 结算 API 文档。
- 第三方授权脚本、测试网门禁监控脚本文档入口。

## 3. 跨链能力当前状态

已完成（代码与入口）：

- 通用跨链网关路径。
- 资产映射与批量接入脚本路径。
- App 内桥接入口（文档/RPC/浏览器）。

仍需主网前补齐：

- 生产中继与托管签名运维。
- 流动性路由和做市层。
- 多资产交易完整 UX（报价、滑点、失败回滚）。

## 4. 每次发版前检查

1. 构建 `YNX` iOS 安装包（模拟器/真机）。
2. 验证钱包创建、导入、余额刷新。
3. 验证水龙头和限流提示。
4. 验证转账草拟和广播。
5. 验证 Web4 会话与第三方授权。
6. 验证跨链入口（文档/RPC/浏览器）。
7. 验证网络探测页状态。
8. 验证文档入口与脚本链接有效。
