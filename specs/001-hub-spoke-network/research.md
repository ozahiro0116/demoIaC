# Research: Hub-Spoke Network Infrastructure

**Feature**: 001-hub-spoke-network | **Date**: 2026-03-24

## 1. AVM Module Selection

### Decision: 全 10 リソースタイプで AVM Bicep モジュールを使用する

| Resource Type | AVM Registry Path | Version | diagnosticSettings | Notes |
|---|---|---|---|---|
| Virtual Network | `br/public:avm/res/network/virtual-network` | 0.7.2 | ✅ | サブネットはインラインで定義。NSG/UDR は `networkSecurityGroupResourceId` / `routeTableResourceId` で関連付け |
| Azure Firewall | `br/public:avm/res/network/azure-firewall` | 0.12.0 | ✅ | Firewall Policy を参照する形式。SKU は Standard/Premium 切替可能 |
| Azure Bastion | `br/public:avm/res/network/bastion-host` | 0.8.2 | ✅ | Standard SKU で IP-based connection をサポート |
| NSG | `br/public:avm/res/network/network-security-group` | 0.5.2 | ✅ | セキュリティルールはインラインで定義 |
| Route Table | `br/public:avm/res/network/route-table` | 0.5.0 | ❌ | diagnosticSettings サポートなし（Route Table 自体に診断ログなし） |
| VNet Peering | `br/public:avm/res/network/virtual-network` submodule | - | ❌ | VNet モジュールの `peerings` パラメータまたは別途 submodule で定義 |
| Public IP | `br/public:avm/res/network/public-ip-address` | 0.12.0 | ✅ | Firewall/Bastion それぞれに 1 つずつ |
| Log Analytics | `br/public:avm/res/operational-insights/workspace` | 0.14.0 | ✅ | retention は `retentionInDays` パラメータで設定 |
| NSG Flow Log | Network Watcher submodule | - | ✅ | `br/public:avm/res/network/network-watcher` の flow-log submodule |
| Firewall Policy | `br/public:avm/res/network/firewall-policy` | 1.0.0 | ✅ | deny-all + allow HTTP/HTTPS ルールを Rule Collection Group で定義 |

**Rationale**: 全リソースに AVM モジュールが存在するため、カスタムモジュールは不要。Constitution Principle I (AVM First) に完全準拠。

**Alternatives considered**:
- ARM テンプレート直接記述 → 却下: AVM の型安全性・WAF 準拠を失う
- Terraform AzureRM → 却下: Constitution で Bicep を指定済み

## 2. Hub-Spoke トポロジパターン

### Decision: VNet Peering + UDR 手動ルーティング

**Rationale**: AVM 学習目的でルーティング制御を明示的に構成する。Virtual WAN は自動ルーティングのため UDR/Route Table の学習機会が失われる。

**Alternatives considered**:
- Virtual WAN → 却下: UDR 学習機会の喪失、コスト高（VWAN Hub 課金）
- 両方サポート → 却下: スコープ過大、学習目的では 1 パターンに集中すべき

## 3. Azure Firewall ルール構成

### Decision: deny-all ベースライン + HTTP/HTTPS outbound allow

**実装方針**:
- Firewall Policy を作成し Azure Firewall に関連付け
- Network Rule Collection Group に deny-all ルール（優先度: 65000）
- Application Rule Collection Group に allow HTTP/HTTPS outbound ルール（優先度: 100）
- ルールは Firewall Policy AVM モジュールの `ruleCollectionGroups` パラメータで定義

**Rationale**: SC-003（100% FW 経由ルーティング）の検証に最低限の allow ルールが必要。deny-all を先に設定することで Security by Default を担保。

**Alternatives considered**:
- ルールなし（スコープ外） → 却下: SC-003 検証不可
- フル DNAT/SNAT ルール → 却下: スコープ過大

## 4. Bastion SKU 選定

### Decision: dev/prod ともに Standard SKU

**Rationale**: Azure Bastion で Spoke VNet 内 VM に接続するには Standard SKU + IP-based connection が必須。Basic SKU では同一 VNet 内の VM のみ接続可能で SC-006 が dev 環境で検証不可。

**Alternatives considered**:
- dev: Basic / prod: Standard → 却下: SC-006 が dev で検証不可
- dev: Bastion なし → 却下: Hub-Spoke の E2E 検証が不完全

## 5. Log Analytics Workspace 保持期間

### Decision: dev: 30 日、prod: 90 日

**Rationale**: dev は無料枠内（30 日以下は課金なし）。prod はインシデント調査に必要な過去データ期間として 90 日が業界標準。

## 6. リソース命名規則

### Decision: `{resourceType}-hub-spoke-{env}-{region}` (CAF 準拠)

**命名マッピング**:

| Resource | dev 名 | prod 名 |
|----------|--------|---------|
| Hub VNet | `vnet-hub-hub-spoke-dev-eus2` | `vnet-hub-hub-spoke-prod-eus2` |
| Spoke VNet | `vnet-spoke-hub-spoke-dev-eus2` | `vnet-spoke-hub-spoke-prod-eus2` |
| Firewall | `fw-hub-spoke-dev-eus2` | `fw-hub-spoke-prod-eus2` |
| Firewall Policy | `fwp-hub-spoke-dev-eus2` | `fwp-hub-spoke-prod-eus2` |
| Bastion | `bas-hub-spoke-dev-eus2` | `bas-hub-spoke-prod-eus2` |
| NSG (Hub mgmt) | `nsg-hub-mgmt-hub-spoke-dev-eus2` | `nsg-hub-mgmt-hub-spoke-prod-eus2` |
| NSG (Spoke wl) | `nsg-spoke-wl-hub-spoke-dev-eus2` | `nsg-spoke-wl-hub-spoke-prod-eus2` |
| Route Table | `rt-spoke-hub-spoke-dev-eus2` | `rt-spoke-hub-spoke-prod-eus2` |
| Public IP (FW) | `pip-fw-hub-spoke-dev-eus2` | `pip-fw-hub-spoke-prod-eus2` |
| Public IP (Bas) | `pip-bas-hub-spoke-dev-eus2` | `pip-bas-hub-spoke-prod-eus2` |
| Log Analytics | `log-hub-spoke-dev-eus2` | `log-hub-spoke-prod-eus2` |
| Resource Group | `rg-hub-spoke-dev-eus2` | `rg-hub-spoke-prod-eus2` |

**Rationale**: Azure CAF 推奨略称（vnet, fw, bas, nsg, rt, pip, log, rg）を使用。環境トークン + リージョン略称で名前衝突を防止。

## 7. デプロイ順序（依存関係グラフ）

```
Phase 1: Log Analytics Workspace
    ↓
Phase 2: NSGs (Hub mgmt + Spoke workload) + Route Table + Public IPs (FW + Bastion)
    ↓
Phase 3: Hub VNet (subnets reference NSGs) + Spoke VNet (subnets reference NSG + RT)
    ↓
Phase 4: Firewall Policy → Azure Firewall + Azure Bastion
    ↓
Phase 5: VNet Peering (Hub↔Spoke bidirectional)
    ↓
Phase 6: Diagnostic Settings (all resources → Log Analytics) + NSG Flow Logs
```

**Rationale**: ARM 依存関係に基づく。Log Analytics が最初（診断設定の送信先）。VNet は NSG/RT に依存。Firewall/Bastion は VNet サブネットに依存。Peering は両 VNet の存在が前提。
