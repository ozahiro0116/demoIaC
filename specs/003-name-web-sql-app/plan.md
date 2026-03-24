# Implementation Plan: Web App + SQL Database on Azure (AVM)

**Branch**: `003-name-web-sql-app` | **Date**: 2026-03-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/003-name-web-sql-app/spec.md`

## Summary

App Service (B1/P1v3) + Azure SQL Database (Basic 5DTU/S1 20DTU) を Azure Verified Modules (AVM) Bicep で構築する。VNet Integration + Private Endpoint でネットワーク分離し、Managed Identity (Entra ID) によるパスワードレス認証を実現する。NSG で App Service → SQL (1433) トラフィックのみ許可。Log Analytics + Application Insights で全リソースの監視を構成。dev/prod パラメータファイル切替で環境分離。CAF 準拠命名規則 `{resourceType}-web-sql-{env}-{region}`。

## Technical Context

**Language/Version**: Bicep (Azure CLI 2.67+ / Bicep CLI 0.32+)
**Primary Dependencies**: Azure Verified Modules (AVM) — 9 モジュール（詳細は [research.md](research.md)）
**Storage**: Azure SQL Database (Basic 5DTU / S1 20DTU)
**Testing**: `az bicep lint` → `az deployment group validate` → `az deployment group what-if`
**Target Platform**: Azure Resource Manager (ARM) — eastus2 リージョン
**Project Type**: IaC infrastructure project（Bicep モジュール構成）
**Performance Goals**: デプロイ完了 < 20 分、全リソース「正常」状態、Web App HTTP 200 応答
**Constraints**: AVM モジュール使用率 90% 以上、Security by Default（NSG/Private Endpoint/Managed Identity/診断設定必須）
**Scale/Scope**: App Service Plan x1 + Web App x1 + SQL Server x1 + SQL Database x1 + VNet x1 (3 subnets)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| **I. AVM First** | ✅ PASS | 全 9 リソースタイプで AVM モジュールを使用（100%）。バージョンは MCR API で検証済み。research.md に全バージョン明記。 |
| **II. WAF Compliance** | ✅ PASS | Security: Private Endpoint + MI + NSG (FR-003,004,006,010)。Reliability: VNet 分離 + 診断設定。Operational Excellence: パラメータ分離 (FR-015)。Cost Optimization: 環境別 SKU (FR-001,005)。 |
| **III. Security by Default** | ✅ PASS | 全サブネット NSG (FR-010)、SQL パブリックアクセス無効 (FR-004)、Private Endpoint (FR-006)、Managed Identity (FR-002)、Entra ID Only 認証 (FR-004)、HTTPS Only、TLS 1.2、全リソース診断設定 (FR-013)。 |
| **IV. Parameterization** | ✅ PASS | environment パラメータ (FR-014)、.bicepparam ファイル分離 (FR-015)、CAF 命名規則に env トークン (FR-017)。SKU/DTU/保持期間/サンプリング率すべてパラメータ化。 |

**Gate Result**: ✅ ALL PASS — Phase 0 に進行可能。

**Post-Phase 1 Re-check**: ✅ ALL PASS — 設計完了後も全原則に準拠。

## Project Structure

### Documentation (this feature)

```text
specs/003-name-web-sql-app/
├── plan.md              # This file
├── research.md          # Phase 0: AVM module research & decisions
├── data-model.md        # Phase 1: Entity/resource model
├── quickstart.md        # Phase 1: Getting started guide
├── contracts/           # Phase 1: Bicep interface contracts
│   ├── main.md          # Orchestrator + module contracts
│   └── parameters.md    # Parameter file contracts (dev/prod)
├── checklists/
│   └── requirements.md  # Spec quality checklist (existing)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
infra/
├── main.bicep                      # Existing: 001 hub-spoke orchestrator
├── main-web-sql.bicep              # NEW: 003 web-sql orchestrator
├── modules/
│   ├── hub-network.bicep           # Existing (001)
│   ├── spoke-network.bicep         # Existing (001)
│   ├── firewall.bicep              # Existing (001)
│   ├── bastion.bicep               # Existing (001)
│   ├── peering.bicep               # Existing (001)
│   ├── monitoring.bicep            # Existing (001)
│   ├── flow-logs.bicep             # Existing (001)
│   ├── web-sql-monitoring.bicep    # NEW: Log Analytics + Application Insights
│   ├── web-sql-network.bicep       # NEW: VNet + 3 subnets + 3 NSGs
│   ├── app-service.bicep           # NEW: App Service Plan + Web App
│   └── sql-database.bicep          # NEW: SQL Server + DB + PE + Private DNS
├── parameters/
│   ├── dev.bicepparam              # Existing (001)
│   ├── prod.bicepparam             # Existing (001)
│   ├── web-sql-dev.bicepparam      # NEW: dev environment
│   └── web-sql-prod.bicepparam     # NEW: prod environment
└── bicepconfig.json                # Existing: AVM registry alias (shared)
```

**Structure Decision**: 001 (hub-spoke) と同一リポジトリ・同一 `infra/` ディレクトリに配置。オーケストレーターは `main-web-sql.bicep` として分離し、既存の 001 デプロイに影響を与えない。`modules/` フォルダ内に新モジュールを追加。`bicepconfig.json` の AVM public エイリアスは共有。

## AVM Module Versions (MCR 検証済み)

| Module | Registry Path | Version | MCR 検証日 |
|--------|--------------|---------|-----------|
| App Service Plan | `br/public:avm/res/web/serverfarm` | **0.7.0** | 2026-03-24 |
| Web App | `br/public:avm/res/web/site` | **0.22.0** | 2026-03-24 |
| SQL Server | `br/public:avm/res/sql/server` | **0.21.1** | 2026-03-24 |
| Virtual Network | `br/public:avm/res/network/virtual-network` | **0.7.2** | 2026-03-24 |
| NSG | `br/public:avm/res/network/network-security-group` | **0.5.3** | 2026-03-24 |
| Private Endpoint | `br/public:avm/res/network/private-endpoint` | **0.12.0** | 2026-03-24 |
| Private DNS Zone | `br/public:avm/res/network/private-dns-zone` | **0.8.1** | 2026-03-24 |
| Log Analytics | `br/public:avm/res/operational-insights/workspace` | **0.15.0** | 2026-03-24 |
| Application Insights | `br/public:avm/res/insights/component` | **0.7.1** | 2026-03-24 |

## Deploy Dependency Graph

```
Phase 1: web-sql-monitoring.bicep
           │ → Log Analytics Workspace
           │ → Application Insights
           ↓
Phase 2: web-sql-network.bicep
           │ → NSG x3 (appsvc, pe, default)
           │ → VNet + 3 subnets (with NSG references + AppSvc delegation)
           ↓
Phase 3: app-service.bicep          sql-database.bicep
           │ (← monitoring +          │ (← network + monitoring)
           │    network)               │ → SQL Server + Database
           │ → ASP + Web App          │ → Private Endpoint
           │   (VNet Integration)      │ → Private DNS Zone + VNet Link
           ↓                           ↓
         outputs:                    outputs:
         webAppName,                 sqlServerFqdn,
         webAppDefaultHostname,      privateEndpointIp
         managedIdentityPrincipalId
```

## Post-Deploy Manual Steps

1. **Managed Identity SQL 権限付与** (FR-008): Web App MI に `db_datareader`/`db_datawriter` を SQL コマンドで付与
2. **接続テスト**: Web App → SQL Database の接続確認

## Complexity Tracking

> 憲法違反なし — このセクションは空。
