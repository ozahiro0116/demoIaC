# Tasks: Web App + SQL Database on Azure (AVM)

**Input**: Design documents from `/specs/003-name-web-sql-app/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: テスト要件は spec.md に明示されていないため、テストタスクは含まない。バリデーションは各フェーズのチェックポイントで `az bicep lint` → `az deployment group validate` → `az deployment group what-if` を実行する。

**Organization**: タスクはユーザーストーリー単位で整理。各ストーリーは独立してデプロイ・検証可能。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可能（異なるファイル、依存関係なし）
- **[Story]**: 対応ユーザーストーリー（US1〜US5）
- ファイルパスはリポジトリルートからの相対パス

---

## Phase 1: Setup

**Purpose**: 003 フィーチャー用のオーケストレーターとモジュールファイルのスキャフォールド。infra/ ディレクトリと bicepconfig.json は 001-hub-spoke-network で作成済み。

- [X] T001 Create orchestrator skeleton with parameters and empty module calls in infra/main-web-sql.bicep
- [X] T002 [P] Create empty module file infra/modules/web-sql-monitoring.bicep with parameter/output stubs per contracts/main.md
- [X] T003 [P] Create empty module file infra/modules/web-sql-network.bicep with parameter/output stubs per contracts/main.md
- [X] T004 [P] Create empty module file infra/modules/app-service.bicep with parameter/output stubs per contracts/main.md
- [X] T005 [P] Create empty module file infra/modules/sql-database.bicep with parameter/output stubs per contracts/main.md
- [X] T006 [P] Create dev parameter file infra/parameters/web-sql-dev.bicepparam per contracts/parameters.md
- [X] T007 [P] Create prod parameter file infra/parameters/web-sql-prod.bicepparam per contracts/parameters.md

**Checkpoint**: `az bicep lint --file infra/main-web-sql.bicep` がエラーなく完了すること

---

## Phase 2: Foundational — 監視基盤 (Blocking)

**Purpose**: Log Analytics Workspace と Application Insights を構築。すべてのリソースの diagnosticSettings 送信先となるため、他のモジュールより先に完成させる必要がある。

**⚠️ CRITICAL**: Phase 3 以降のモジュールは logAnalyticsWorkspaceId を必要とするため、このフェーズ完了まで実装不可。

- [X] T008 Implement Log Analytics Workspace using AVM `br/public:avm/res/operational-insights/workspace:0.15.0` in infra/modules/web-sql-monitoring.bicep (FR-011)
- [X] T009 Implement Application Insights using AVM `br/public:avm/res/insights/component:0.7.1` with workspaceResourceId linkage in infra/modules/web-sql-monitoring.bicep (FR-012)
- [X] T010 Wire web-sql-monitoring module call in infra/main-web-sql.bicep with environment-based retentionInDays and samplingPercentage parameters
- [X] T011 Validate: `az deployment group validate` with infra/parameters/web-sql-dev.bicepparam — monitoring resources only

**Checkpoint**: Log Analytics Workspace + Application Insights がバリデーション成功。workspaceId と appInsightsConnectionString が output として取得できること

---

## Phase 3: User Story 1 — Web アプリケーション基盤の構築 (Priority: P1) 🎯 MVP

**Goal**: App Service Plan + Web App を AVM でデプロイし、Managed Identity 有効化、Application Insights 接続を完了する

**Independent Test**: App Service を単独デプロイし、デフォルトページが HTTP 200 で応答すること、Managed Identity が有効であることを確認

### Implementation for User Story 1

- [X] T012 [US1] Implement App Service Plan using AVM `br/public:avm/res/web/serverfarm:0.7.0` with environment-based SKU (B1/P1v3) in infra/modules/app-service.bicep (FR-001)
- [X] T013 [US1] Implement Web App using AVM `br/public:avm/res/web/site:0.22.0` with managedIdentities.systemAssigned, httpsOnly, .NET 8 runtime in infra/modules/app-service.bicep (FR-002)
- [X] T014 [US1] Configure Application Insights connection string in Web App siteConfig.appSettings (APPLICATIONINSIGHTS_CONNECTION_STRING) in infra/modules/app-service.bicep (FR-012)
- [X] T015 [US1] Configure diagnosticSettings for App Service to Log Analytics Workspace in infra/modules/app-service.bicep (FR-013)
- [X] T016 [US1] Wire app-service module call in infra/main-web-sql.bicep with dependencies on monitoring module outputs
- [X] T017 [US1] Validate: `az deployment group validate` with infra/parameters/web-sql-dev.bicepparam — monitoring + app-service modules

**Checkpoint**: Web App がバリデーション成功。US1 単独で webAppName, webAppDefaultHostname, webAppManagedIdentityPrincipalId が output として取得できること

---

## Phase 4: User Story 2 — SQL Database のデプロイとセキュア接続 (Priority: P1)

**Goal**: SQL Server + Database を AVM でデプロイし、Entra ID Only 認証、パブリックアクセス無効、Private Endpoint + Private DNS Zone を構成する

**Independent Test**: SQL Server + Database を単独デプロイし、Private Endpoint が作成されていること、パブリックネットワークアクセスが無効であることを確認

### Implementation for User Story 2

- [X] T018 [US2] Implement SQL Server using AVM `br/public:avm/res/sql/server:0.21.1` with Entra ID administrators, publicNetworkAccess Disabled, minimalTlsVersion 1.2 in infra/modules/sql-database.bicep (FR-004)
- [X] T019 [US2] Implement SQL Database inline via SQL Server databases parameter with environment-based SKU (Basic 5DTU / S1 20DTU) in infra/modules/sql-database.bicep (FR-005)
- [X] T020 [US2] Implement Private Endpoint using AVM `br/public:avm/res/network/private-endpoint:0.12.0` with groupIds ['sqlServer'] in infra/modules/sql-database.bicep (FR-006)
- [X] T021 [US2] Implement Private DNS Zone using AVM `br/public:avm/res/network/private-dns-zone:0.8.1` for privatelink.database.windows.net with VNet link in infra/modules/sql-database.bicep (FR-007)
- [X] T022 [US2] Configure privateDnsZoneGroup on Private Endpoint for automatic A record registration in infra/modules/sql-database.bicep (FR-007)
- [X] T023 [US2] Configure diagnosticSettings for SQL Server to Log Analytics Workspace in infra/modules/sql-database.bicep (FR-013)
- [X] T024 [US2] Wire sql-database module call in infra/main-web-sql.bicep with dependencies on monitoring and network module outputs
- [X] T025 [US2] Validate: `az deployment group validate` with infra/parameters/web-sql-dev.bicepparam — monitoring + network + sql-database modules

**Checkpoint**: SQL Server + Database + Private Endpoint + Private DNS Zone がバリデーション成功。sqlServerFqdn, privateEndpointIp が output として取得できること

---

## Phase 5: User Story 3 — ネットワークセキュリティの確保 (Priority: P2)

**Goal**: VNet + 3 サブネット + 3 NSG を構成し、App Service VNet Integration と SQL Private Endpoint のネットワーク分離を実現する

**Independent Test**: NSG ルールを確認し、SQL Database (ポート 1433) への通信が App Service サブネットからのみ許可されていることを検証

### Implementation for User Story 3

- [X] T026 [P] [US3] Implement NSG for App Service subnet (nsg-appsvc) with AllowSqlOutbound/AllowHttpsOutbound rules using AVM `br/public:avm/res/network/network-security-group:0.5.3` in infra/modules/web-sql-network.bicep (FR-010)
- [X] T027 [P] [US3] Implement NSG for Private Endpoint subnet (nsg-pe) with AllowSqlFromAppSvc/DenyAllInbound rules using AVM in infra/modules/web-sql-network.bicep (FR-010)
- [X] T028 [P] [US3] Implement NSG for Default subnet (nsg-default) with default rules only using AVM in infra/modules/web-sql-network.bicep (FR-010)
- [X] T029 [US3] Implement VNet using AVM `br/public:avm/res/network/virtual-network:0.7.2` with 3 subnets, NSG associations, and Microsoft.Web/serverFarms delegation on AppServiceSubnet in infra/modules/web-sql-network.bicep (FR-009, FR-003)
- [X] T030 [US3] Configure diagnosticSettings for NSGs to Log Analytics Workspace in infra/modules/web-sql-network.bicep (FR-013)
- [X] T031 [US3] Wire web-sql-network module call in infra/main-web-sql.bicep with dependency on monitoring module output (logAnalyticsWorkspaceId)
- [X] T032 [US3] Add VNet Integration: set virtualNetworkSubnetId on Web App in infra/modules/app-service.bicep using appServiceSubnetId parameter (FR-003)
- [X] T033 [US3] Update app-service module call in infra/main-web-sql.bicep to pass appServiceSubnetId from network module output
- [X] T034 [US3] Update sql-database module call in infra/main-web-sql.bicep to pass privateEndpointSubnetId and vnetId from network module output
- [X] T035 [US3] Validate: `az deployment group validate` with infra/parameters/web-sql-dev.bicepparam — all modules wired

**Checkpoint**: 全モジュール統合バリデーション成功。VNet Integration + Private Endpoint がネットワークモジュール経由で正しくサブネットに接続されていること

---

## Phase 6: User Story 4 — 監視とログ収集の構成 (Priority: P2)

**Goal**: Phase 2 で構築した監視基盤に対し、全リソースの診断設定が正しく構成されていることを検証・補完する

**Independent Test**: Log Analytics Workspace に各リソースの診断ログが送信設定されていることを確認

### Implementation for User Story 4

- [X] T036 [US4] Verify and complete diagnosticSettings for App Service (AppServiceHTTPLogs, AppServiceConsoleLogs, AppServiceAppLogs, AllMetrics) in infra/modules/app-service.bicep (FR-013)
- [X] T037 [US4] Verify and complete diagnosticSettings for SQL Server (SQLSecurityAuditEvents, AllMetrics) in infra/modules/sql-database.bicep (FR-013)
- [X] T038 [US4] Verify and complete diagnosticSettings for all 3 NSGs (NetworkSecurityGroupEvent, NetworkSecurityGroupRuleCounter) in infra/modules/web-sql-network.bicep (FR-013)
- [X] T039 [US4] Add monitoring-related outputs to infra/main-web-sql.bicep: logAnalyticsWorkspaceId, appInsightsConnectionString
- [X] T040 [US4] Validate: `az deployment group what-if` with infra/parameters/web-sql-dev.bicepparam — confirm all diagnostic settings appear in what-if output

**Checkpoint**: what-if 出力ですべてのリソースに diagnosticSettings が含まれていること

---

## Phase 7: User Story 5 — dev/prod 環境のパラメータ切り替え (Priority: P3)

**Goal**: 同一コードベースから environment パラメータ切替で dev/prod 環境を正しくデプロイできることを検証する

**Independent Test**: dev と prod パラメータそれぞれで what-if を実行し、リソース名に環境トークンが含まれ、SKU が環境に応じた設定になっていることを比較検証

### Implementation for User Story 5

- [X] T041 [US5] Verify CAF naming convention implementation: all resource names follow `{resourceType}-web-sql-{env}-{region}` pattern across all modules (FR-017)
- [X] T042 [US5] Verify parameter file completeness: all required parameters in infra/parameters/web-sql-dev.bicepparam match contracts/parameters.md values
- [X] T043 [US5] Verify parameter file completeness: all required parameters in infra/parameters/web-sql-prod.bicepparam match contracts/parameters.md values
- [X] T044 [P] [US5] Validate dev: `az deployment group what-if` with infra/parameters/web-sql-dev.bicepparam — confirm B1 SKU, Basic 5DTU, 30-day retention, 100% sampling
- [X] T045 [P] [US5] Validate prod: `az deployment group what-if` with infra/parameters/web-sql-prod.bicepparam — confirm P1v3 SKU, S1 20DTU, 90-day retention, 50% sampling
- [X] T046 [US5] Compare dev vs prod what-if outputs: resource names contain correct env token, SKU values differ as expected

**Checkpoint**: dev/prod 両環境の what-if が成功し、環境差分が contracts/parameters.md の「環境差分まとめ」と一致すること

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: 全ストーリー横断の品質確認と最終整備

- [X] T047 Run `az bicep lint --file infra/main-web-sql.bicep` and fix all warnings
- [X] T048 [P] Verify all outputs in infra/main-web-sql.bicep match contracts/main.md output contract (10 outputs)
- [X] T049 [P] Verify AVM module usage rate is 100% (9/9 AVM modules) per research.md (FR-016)
- [ ] T050 Run full dev deployment: `az deployment group create` with infra/parameters/web-sql-dev.bicepparam per quickstart.md
- [ ] T051 Post-deploy validation per quickstart.md: Web App HTTP 200 (SC-003), Private Endpoint Approved (SC-004), diagnostics configured (SC-006)
- [ ] T052 Document post-deploy manual step: Managed Identity SQL role assignment (db_datareader/db_datawriter) per quickstart.md (FR-008)

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup ──────────────────────────────────────► (no deps)
    ↓
Phase 2: Foundational (Monitoring) ──────────────────► BLOCKS Phase 3-7
    ↓
Phase 3: US1 App Service ───┐
Phase 4: US2 SQL Database ──┤── (all depend on Phase 2)
Phase 5: US3 Network ───────┘   (US3 integrates US1+US2 with network)
    ↓
Phase 6: US4 Monitoring verify ──► (depends on Phase 3-5)
Phase 7: US5 Parameter verify ──► (depends on Phase 3-5)
    ↓
Phase 8: Polish ─────────────────► (depends on all phases)
```

### User Story Dependencies

- **US1 (P1)**: Phase 2 完了後に開始可能。他ストーリーへの依存なし（VNet Integration は US3 で追加）
- **US2 (P1)**: Phase 2 完了後に開始可能。Private Endpoint のサブネットは US3 で接続するが、モジュール内でパラメータとして受け取るため独立実装可能
- **US3 (P2)**: Phase 2 完了後に開始可能。US1/US2 のモジュールにネットワークパラメータを統合する（T032-T034）
- **US4 (P2)**: US1/US2/US3 のモジュールが完成していること。診断設定の検証・補完フェーズ
- **US5 (P3)**: US1/US2/US3 のモジュールが完成していること。パラメータ環境切替の検証フェーズ

### Parallel Opportunities

- **Phase 1**: T002-T007 はすべて [P] — 6 ファイルを同時作成可能
- **Phase 3 + Phase 4**: US1 (App Service) と US2 (SQL Database) は**異なるモジュールファイル**のため、Phase 2 完了後に並列実装可能
- **Phase 5**: T026-T028 (3 NSG) は [P] — 同一ファイル内だが独立リソース定義のため並列記述可能
- **Phase 7**: T044-T045 (dev/prod what-if) は [P] — 異なるパラメータファイルで並列検証可能

---

## Parallel Example: Phase 3 + Phase 4

```bash
# Phase 2 完了後、US1 と US2 を並列に開始:

# Developer A: User Story 1 (App Service)
Task T012: App Service Plan in infra/modules/app-service.bicep
Task T013: Web App in infra/modules/app-service.bicep
Task T014: App Insights connection in infra/modules/app-service.bicep

# Developer B: User Story 2 (SQL Database)  
Task T018: SQL Server in infra/modules/sql-database.bicep
Task T019: SQL Database in infra/modules/sql-database.bicep
Task T020: Private Endpoint in infra/modules/sql-database.bicep
Task T021: Private DNS Zone in infra/modules/sql-database.bicep
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup — スキャフォールド作成
2. Phase 2: Foundational — Log Analytics + App Insights
3. Phase 3: US1 — App Service Plan + Web App + MI + App Insights 接続
4. **STOP and VALIDATE**: Web App デフォルトページが HTTP 200 で応答することを確認
5. MVP として dev 環境にデプロイ可能

### Incremental Delivery

1. Setup + Foundational → 監視基盤完成
2. + US1 (App Service) → Web App 単独稼働 (MVP!)
3. + US2 (SQL Database) → データストア + Private Endpoint 追加
4. + US3 (Network) → VNet Integration + NSG でネットワーク分離完成
5. + US4 (Monitoring verify) → 全リソース診断設定完了
6. + US5 (Parameter verify) → dev/prod 環境切替検証完了
7. Polish → lint + 最終デプロイ + ポストデプロイ検証

### AVM Module Summary

| Module File | AVM Modules Used | Count |
|-------------|-----------------|-------|
| web-sql-monitoring.bicep | operational-insights/workspace, insights/component | 2 |
| web-sql-network.bicep | network/network-security-group (x3), network/virtual-network | 4 |
| app-service.bicep | web/serverfarm, web/site | 2 |
| sql-database.bicep | sql/server, network/private-endpoint, network/private-dns-zone | 3 |
| **Total** | | **11 AVM module calls (9 unique)** |

---

## Notes

- [P] タスク = 異なるファイルまたは独立リソース、依存関係なし
- [US*] ラベル = ユーザーストーリーへのトレーサビリティ
- 各ストーリーは独立してバリデーション可能
- タスク完了ごとにコミット推奨
- チェックポイントでストーリー単位の検証を実施
- infra/ ディレクトリ・bicepconfig.json は 001-hub-spoke-network で作成済みのため再作成不要
