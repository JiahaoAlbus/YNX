# YNX 非托管商业与合规边界

状态：active business baseline
最后更新：2026-04-30
规范语言：中文

## 1. 产品边界

YNX 应定位为非托管 Web4 基础设施和协议公司。

默认边界：

- 不碰用户资产；
- 不做托管；
- 不做交易所或撮合引擎；
- 不发行稳定币，也不管理稳定币储备；
- 不把 KYC 做成主营业务；
- 不承诺 NYXT 升值。

用户和验证人自己保管私钥。应用可以接钱包、身份服务商、合规服务商、受监管金融伙伴，但基础协议公司不因此变成托管方或交易所。

## 2. 怎么赚钱

YNX 可以不碰用户资产也赚钱：

- 托管 RPC、REST、gRPC、EVM、indexer、explorer、status API；
- 企业 Web4 / AI agent 基础设施订阅；
- 付费 SLA、私有部署、技术支持合同；
- 验证人、节点、监控、灾备工具；
- SDK、API key、开发者后台、数据分析、按量计费；
- 安全审计、集成支持、生态项目认证；
- app、agent、domain、verified integration 的市场展示和认证费用，前提是合法；
- 治理批准且清楚披露的协议费用；
- grants、生态合作、基金会项目。

公司必须做到：即使代币市场收入为零，也能靠法币合同和基础设施收入活下去。

## 3. 如果 NYXT 不值钱怎么办

公司不能靠 NYXT 价格支付运营成本。

执行方案：

- 企业 SaaS、API、支持、私有部署合同用法币或受监管服务商处理的外部结算；
- NYXT 负责 gas、staking、governance、反垃圾、协议对齐，不作为唯一商业模式；
- 运营预算不能依赖 treasury token 的账面价格；
- 对外明确：NYXT 可能没有市场价值，不能宣传为投资收益承诺；
- 协议费只能作为额外 upside，不能作为公司生存前提。

如果 NYXT 归零，YNX 仍然可以通过托管基础设施、企业集成、技术支持、安全审计、私有 Web4 部署赚钱。

## 4. KYC 边界

基础协议不应该成为 KYC 业务。

实际规则：

- 读链、运行开源节点、自托管钱包、开发应用不需要 YNX 做 KYC；
- 协议公司不要直接做法币出入金身份流程，除非律师确认并拿到牌照；
- 如果受监管合作方需要 KYC，由合作方在自己的合规体系下完成；
- 企业合同可能需要 KYB、制裁筛查、合同尽调，这不等于 YNX 变成面向消费者的 KYC 服务商。

## 5. 公司开在哪里

这不是法律意见，最终必须让律师确认。

务实默认方案：

- 新加坡运营公司：负责亚洲和全球 Web3/Web4 基础设施、企业合同、腾讯云新加坡运维；
- 如需要代币治理、grants、公共物品治理，再考虑基金会或治理实体；
- 如果之后主要拿美国 VC、卖美国企业、雇美国团队，再考虑 Delaware C-Corp。

现在更建议优先考虑“新加坡 OpCo + 必要时另设治理/基金会实体”的结构，因为当前基础设施在新加坡，项目目标又是非托管、非交易所、非稳定币、非 KYC 主营。

任何交易所、稳定币、托管、法币出入金、面向特定国家居民的金融服务，都必须先让律师确认牌照问题。尤其是新加坡，MAS 在 2025 年明确了部分数字代币服务提供者的牌照要求；同时 MAS 也说明，仅涉及 utility token 或 governance token 的服务不受该新规影响。

## 6. 主网上线前商业门禁

主网上线前至少完成：

1. 律师 memo：确认非托管、非交易所、非稳定币、非消费者 KYC 的边界；
2. 对外 terms：解释测试网/主网风险、不承诺投资收益；
3. 安全审计和事故响应流程；
4. 公司主体、银行、会计、税务、合同模板；
5. API/SLA/企业服务价格表，收入不依赖 NYXT 价格；
6. 协议治理和公司收入运营分离。

## 7. 外部监管提醒

新加坡和其他司法辖区的数字代币规则会变化。只要 YNX 计划提供任何可能被认定为数字代币服务、支付服务、托管、交易或稳定币相关的产品，都必须重新核对 MAS 等监管机构的最新规则。

- MAS DTSP 澄清：`https://www.sgpc.gov.sg/api/file/getfile/MAS%20Media%20Release%20-%20Clarification%20Statement%20on%20DTSP%20Regulatory%20Regime.pdf?path=%2Fsgpcmedia%2Fmedia_releases%2Fmas%2Fpress_release%2FP-20250606-1%2Fattachment%2FMAS+Media+Release+-+Clarification+Statement+on+DTSP+Regulatory+Regime.pdf`
- ACRA 本地公司注册：`https://www.acra.gov.sg/register/business/registering-different-business-structures/local-company/registering-via-bizfile/`
