# Research: Web App + SQL Database on Azure (AVM)

**Feature**: 003-name-web-sql-app | **Date**: 2026-03-24

## 1. AVM Module Selection

### Decision: 全 9 リソースタイプで AVM Bicep モジュールを使用する

バージョンはすべて MCR API (`https://mcr.microsoft.com/v2/bicep/avm/res/{provider}/{resource}/tags/list`) で実在を検証済み。

| Resource Type | AVM Registry Path | Version | diagnosticSettings | MCR 検証 | Notes |
|---|---|---|---|---|---|
| App Service Plan | `br/public:avm/res/web/serverfarm` | 0.7.0 | ✅ | ✅ | SKU は `name` + `tier` で指定。B1/P1v3 を環境で切替 |
| Web App | `br/public:avm/res/web/site` | 0.22.0 | ✅ | ✅ | `kind: 'app'`、`managedIdentities.systemAssigned: true`、`virtualNetworkSubnetId` で VNet Integration |
| SQL Server | `br/public:avm/res/sql/server` | 0.21.1 | ✅ | ✅ | `administrators` で Entra ID 管理者設定。`databases` パラメータで DB をインライン作成。`publicNetworkAccess: 'Disabled'` |
| Virtual Network | `br/public:avm/res/network/virtual-network` | 0.7.2 | ✅ | ✅ | 001 と同一モジュール。サブネット定義はインライン。delegation 設定可能 |
| NSG | `br/public:avm/res/network/network-security-group` | 0.5.3 | ✅ | ✅ | 001 では 0.5.2 を使用 → 0.5.3 に更新 |
| Private Endpoint | `br/public:avm/res/network/private-endpoint` | 0.12.0 | ❌ | ✅ | `privateLinkServiceConnections` で SQL Server を指定。`groupIds: ['sqlServer']` |
| Private DNS Zone | `br/public:avm/res/network/private-dns-zone` | 0.8.1 | ❌ | ✅ | `virtualNetworkLinks` で VNet にリンク。ゾーン名: `privatelink.database.windows.net` |
| Log Analytics | `br/public:avm/res/operational-insights/workspace` | 0.15.0 | ✅ | ✅ | 001 では 0.14.0 → 0.15.0 に更新 |
| Application Insights | `br/public:avm/res/insights/component` | 0.7.1 | ❌ | ✅ | `workspaceResourceId` で Log Analytics に接続。`applicationType: 'web'` |

**AVM 使用率**: 9/9 = 100%（FR-016: 90% 以上を達成）

**Rationale**: 全リソースに AVM モジュールが存在するため、カスタムモジュールは不要。Constitution Principle I (AVM First) に完全準拠。

**Alternatives considered**:
- ARM テンプレート直接記述 → 却下: AVM の型安全性・WAF 準拠を失う
- Terraform AzureRM → 却下: プロジェクトで Bicep を採用済み
- SQL Database を standalone AVM モジュールで作成 → 却下: `avm/res/sql/server` の `databases` パラメータでインライン作成が AVM ベストプラクティス

## 2. App Service VNet Integration パターン

### Decision: Regional VNet Integration（`virtualNetworkSubnetId` プロパティ）

**実装方針**:
- App Service Plan は B1 以上の SKU が必要（Free/Shared は VNet Integration 非対応）
- Web App の `virtualNetworkSubnetId` に AppServiceSubnet のリソース ID を設定
- AppServiceSubnet には `Microsoft.Web/serverFarms` の delegation が必要
- サブネットサイズは /24（最小 /28 だが余裕を持たせる）

**Rationale**: Regional VNet Integration はサービスエンドポイント/Private Endpoint との組合せで最も一般的なパターン。App Gateway 不要。

**Alternatives considered**:
- App Service Environment (ASE) → 却下: コスト過大、スコープ外
- VNet Integration なし → 却下: FR-003 違反、SQL Private Endpoint への通信不可

## 3. SQL Database 接続方式

### Decision: Private Endpoint + Managed Identity (Entra ID 認証)

**実装方針**:
- SQL Server: `publicNetworkAccess: 'Disabled'`、`administrators` で Entra ID Only 認証
- Private Endpoint: `groupIds: ['sqlServer']` で SQL Server に接続
- Private DNS Zone: `privatelink.database.windows.net` を作成し VNet にリンク
- Managed Identity: Web App の System-assigned MI に SQL Database 権限を付与（デプロイ後手動ステップ）

**DNS 解決フロー**:
```
Web App → VNet Integration → DNS Query (sql-web-sql-dev-eus2.database.windows.net)
    → Private DNS Zone → Private IP (10.20.2.x) → Private Endpoint → SQL Server
```

**Rationale**: Private Endpoint + Entra ID 認証は Microsoft のゼロトラスト推奨パターン。パスワードレスでシークレット管理不要。

**Alternatives considered**:
- Service Endpoint → 却下: Microsoft は Private Endpoint を推奨。完全なプライベート通信ではない
- SQL 認証（ユーザー/パスワード） → 却下: FR-004 違反。セキュリティリスク
- Key Vault にパスワード保存 → 却下: Managed Identity があればパスワード自体が不要

## 4. NSG ルール設計

### Decision: AppService サブネット → PrivateEndpoint サブネットのポート 1433 のみ許可

**ルール構成**:

| NSG | Rule | Priority | Direction | Source | Dest | Port | Action |
|-----|------|----------|-----------|--------|------|------|--------|
| nsg-appsvc | AllowAppSvcOutbound | 100 | Outbound | VirtualNetwork | VirtualNetwork | 1433 | Allow |
| nsg-appsvc | AllowHttpsOutbound | 110 | Outbound | VirtualNetwork | Internet | 443 | Allow |
| nsg-pe | AllowSqlFromAppSvc | 100 | Inbound | 10.20.1.0/24 (AppSvcSubnet) | VirtualNetwork | 1433 | Allow |
| nsg-pe | DenyAllInbound | 4096 | Inbound | * | * | * | Deny |
| nsg-default | (default rules only) | - | - | - | - | - | - |

**Rationale**: FR-010 の要件「ポート 1433 通信を App Service サブネットからのみ許可」を満たす最小ルール。明示的な Deny ルールでセキュリティを強化。

**Alternatives considered**:
- ASG (Application Security Group) ベース → 却下: Private Endpoint は ASG 非対応
- サービスタグベース (`Sql` タグ) → 却下: Private Endpoint 利用時は不要

## 5. Application Insights 構成

### Decision: ワークスペースベース Application Insights + 接続文字列注入

**実装方針**:
- `avm/res/insights/component` で作成。`workspaceResourceId` で Log Analytics に接続
- Web App の `siteConfig.appSettings` に `APPLICATIONINSIGHTS_CONNECTION_STRING` を設定
- サンプリング率: dev=100%（全トラフィック収集）、prod=50%（`samplingPercentage` パラメータ）

**Rationale**: クラシック Application Insights は非推奨。ワークスペースベースが現在の標準。接続文字列方式はインストルメンテーションキーより推奨。

**Alternatives considered**:
- クラシック Application Insights → 却下: 非推奨
- インストルメンテーションキー方式 → 却下: Microsoft は接続文字列を推奨
- Application Insights なし → 却下: FR-012 違反

## 6. リソース命名規則

### Decision: `{resourceType}-web-sql-{env}-{region}` (CAF 準拠)

**命名マッピング**:

| Resource | CAF 略称 | dev 名 | prod 名 |
|----------|---------|--------|---------|
| Resource Group | rg | `rg-web-sql-dev-eus2` | `rg-web-sql-prod-eus2` |
| App Service Plan | asp | `asp-web-sql-dev-eus2` | `asp-web-sql-prod-eus2` |
| Web App | app | `app-web-sql-dev-eus2` | `app-web-sql-prod-eus2` |
| SQL Server | sql | `sql-web-sql-dev-eus2` | `sql-web-sql-prod-eus2` |
| SQL Database | sqldb | `sqldb-web-sql-dev-eus2` | `sqldb-web-sql-prod-eus2` |
| VNet | vnet | `vnet-web-sql-dev-eus2` | `vnet-web-sql-prod-eus2` |
| NSG (AppSvc) | nsg | `nsg-appsvc-web-sql-dev-eus2` | `nsg-appsvc-web-sql-prod-eus2` |
| NSG (PE) | nsg | `nsg-pe-web-sql-dev-eus2` | `nsg-pe-web-sql-prod-eus2` |
| NSG (Default) | nsg | `nsg-default-web-sql-dev-eus2` | `nsg-default-web-sql-prod-eus2` |
| Private Endpoint | pep | `pep-sql-web-sql-dev-eus2` | `pep-sql-web-sql-prod-eus2` |
| Private DNS Zone | (fixed) | `privatelink.database.windows.net` | `privatelink.database.windows.net` |
| Log Analytics | log | `log-web-sql-dev-eus2` | `log-web-sql-prod-eus2` |
| Application Insights | appi | `appi-web-sql-dev-eus2` | `appi-web-sql-prod-eus2` |

**Rationale**: FR-017 に準拠。001 と同じ CAF 命名パターンで一貫性を保つ。`web-sql` プレフィックスで 001 の `hub-spoke` リソースと名前衝突を防止。

## 7. デプロイ順序（依存関係グラフ）

```
Phase 1: Log Analytics Workspace
    ↓
Phase 2: Application Insights (← Log Analytics)
         NSGs x3 [parallel]
    ↓
Phase 3: VNet + Subnets (← NSGs, AppServiceSubnet に delegation)
         Private DNS Zone [parallel]
    ↓
Phase 4: App Service Plan + Web App (← VNet for Integration, App Insights for telemetry)
         SQL Server + Database [parallel] (← VNet 不要、PE は後で接続)
    ↓
Phase 5: Private Endpoint (← SQL Server + VNet PrivateEndpointSubnet)
         Private DNS Zone VNet Link (← VNet + Private DNS Zone)
    ↓
Phase 6: Diagnostic Settings (AVM モジュールの diagnosticSettings パラメータでインライン構成)
```

**Rationale**: ARM 依存関係に基づく。Log Analytics が最初（全リソースの診断設定の送信先）。VNet Integration は Web App と同時。Private Endpoint は SQL Server 作成後。

**Note**: AVM モジュールでは `diagnosticSettings` パラメータがモジュール内に組み込まれているため、Phase 6 は独立フェーズではなく各モジュール呼び出し時にインラインで構成される。実質的に Phase 1-5 で完結。

## 8. 001 との共存方針

### Decision: 別オーケストレーター (`main-web-sql.bicep`) + 共有 modules フォルダ

**理由**:
- 001 (hub-spoke) と 003 (web-sql) は異なるデプロイ単位。VNet アドレス空間も異なる
- 同一 `infra/modules/` フォルダ内に新モジュールを追加（既存モジュールは変更しない）
- パラメータファイルは `web-sql-dev.bicepparam` / `web-sql-prod.bicepparam` で分離
- `bicepconfig.json` は共有（AVM public レジストリエイリアスは共通）

**Alternatives considered**:
- 既存 main.bicep を拡張 → 却下: 001 のデプロイに影響するリスク
- 別フォルダ `infra-web-sql/` → 却下: bicepconfig.json の重複、モジュール再利用不可
