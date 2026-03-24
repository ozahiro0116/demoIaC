# Tasks: Hub-Spoke Network Infrastructure

**Input**: Design documents from `/specs/001-hub-spoke-network/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Automated test tasks are not included (not requested in spec). Validation is performed via `az bicep lint` + `az deployment group validate` + `az deployment group what-if`.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: プロジェクト構造の初期化と Bicep 基盤設定

- [X] T001 Create project directory structure: infra/, infra/modules/, infra/parameters/
- [X] T002 [P] Create bicepconfig.json with AVM public module registry alias and linter rules in infra/bicepconfig.json

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 全 User Story が依存する共有インフラ（Log Analytics Workspace）と main.bicep スキャフォールド

**⚠️ CRITICAL**: Log Analytics Workspace は全モジュールの diagnosticSettings 送信先。このフェーズ完了まで User Story 作業は不可。

- [X] T003 Create monitoring.bicep using AVM `br/public:avm/res/operational-insights/workspace` with environment naming (`log-hub-spoke-{env}-{region}`) and retentionInDays parameter (dev:30, prod:90) in infra/modules/monitoring.bicep
- [X] T004 Scaffold main.bicep orchestrator with targetScope, environment/location parameters, tags variable, and monitoring module invocation in infra/main.bicep

**Checkpoint**: Foundation ready — User Story 実装を開始可能

---

## Phase 3: User Story 1 — Hub VNet の構築とセキュリティ集約 (Priority: P1) 🎯 MVP

**Goal**: Hub VNet を作成し、Azure Firewall（deny-all + allow HTTP/HTTPS）と Azure Bastion（Standard SKU）を配置してセキュリティ集約を実現する

**Independent Test**: Hub VNet 単独デプロイ → AzureFirewallSubnet・AzureBastionSubnet・ManagementSubnet の 3 サブネット存在、FW に PIP 割当、Bastion に PIP 割当、管理サブネットに NSG、全リソースに診断設定が有効であることを確認

### Implementation for User Story 1

- [X] T005 [P] [US1] Create hub-network.bicep using AVM `br/public:avm/res/network/virtual-network` with 3 subnets (AzureFirewallSubnet /26, AzureBastionSubnet /26, ManagementSubnet /24), management NSG via AVM `br/public:avm/res/network/network-security-group`, and diagnosticSettings for VNet and NSG in infra/modules/hub-network.bicep
- [X] T006 [P] [US1] Create firewall.bicep using AVM `br/public:avm/res/network/azure-firewall` + AVM `br/public:avm/res/network/firewall-policy` (deny-all network rule priority 65000 + allow HTTP/HTTPS application rule priority 100) + AVM `br/public:avm/res/network/public-ip-address`, with diagnosticSettings in infra/modules/firewall.bicep
- [X] T007 [P] [US1] Create bastion.bicep using AVM `br/public:avm/res/network/bastion-host` (Standard SKU, enableIpConnect: true) + AVM `br/public:avm/res/network/public-ip-address`, with diagnosticSettings in infra/modules/bastion.bicep
- [X] T008 [US1] Integrate hub-network, firewall, bastion modules into main.bicep: wire logAnalyticsWorkspaceId → each module, hub-network outputs (firewallSubnetId, bastionSubnetId) → firewall/bastion inputs in infra/main.bicep
- [X] T009 [US1] Create initial dev.bicepparam with environment='dev', location='eastus2', hubAddressPrefix='10.0.0.0/16' for US1 validation in infra/parameters/dev.bicepparam
- [X] T010 [US1] Validate US1: run `az bicep lint --file infra/main.bicep` and `az deployment group validate` with dev.bicepparam

**Checkpoint**: Hub VNet + Firewall + Bastion が単独でデプロイ・検証可能。SC-006 (Bastion接続) と SC-007 (AVM使用率) の基盤が確立。

---

## Phase 4: User Story 2 — Spoke VNet の構築と Hub への接続 (Priority: P2)

**Goal**: Spoke VNet を作成してワークロード用サブネットを配置し、Hub VNet と VNet Peering で接続。UDR により Spoke トラフィックを Azure Firewall 経由でルーティングする

**Independent Test**: Spoke VNet デプロイ → WorkloadSubnet に NSG + UDR が付与、Hub↔Spoke 双方向 Peering が Connected、UDR の default route nextHop が Firewall Private IP であることを確認

**Dependencies**: US1 の firewall.bicep が firewallPrivateIp を出力（UDR の nextHop に必要）

### Implementation for User Story 2

- [X] T011 [P] [US2] Create spoke-network.bicep using AVM `br/public:avm/res/network/virtual-network` with WorkloadSubnet (/24), AVM NSG, AVM Route Table (0.0.0.0/0 → firewallPrivateIp, disableBgpRoutePropagation: true), and diagnosticSettings in infra/modules/spoke-network.bicep
- [X] T012 [P] [US2] Create peering.bicep for Hub↔Spoke bidirectional VNet Peering (allowForwardedTraffic: true, Hub→Spoke allowGatewayTransit: true, Spoke→Hub useRemoteGateways: false) in infra/modules/peering.bicep
- [X] T013 [US2] Integrate spoke-network and peering modules into main.bicep: wire firewallPrivateIp → spoke-network, hubVnetId/spokeVnetId → peering in infra/main.bicep
- [X] T014 [US2] Update dev.bicepparam with spokeAddressPrefix='10.10.0.0/16' in infra/parameters/dev.bicepparam
- [X] T015 [US2] Validate US2: run `az deployment group validate` with updated dev.bicepparam, verify Peering and UDR configuration in template

**Checkpoint**: Hub-Spoke トポロジ完成。SC-003 (FW経由ルーティング) の基盤が確立。Spoke サブネットの effective routes で 0.0.0.0/0 → FW Private IP を検証可能。

---

## Phase 5: User Story 3 — NSG・診断設定・フローログの全面適用 (Priority: P2)

**Goal**: 全 NSG にフローログを有効化し、全リソースの診断設定が Log Analytics に正しく接続されていることを保証する

**Independent Test**: 全 NSG でフローログが有効、Traffic Analytics が Log Analytics に送信、全リソース（VNet, FW, Bastion, NSG, PIP）に diagnosticSettings が設定されていることを確認

**Dependencies**: US1 + US2 の NSG リソース ID がフローログのターゲットとして必要

### Implementation for User Story 3

- [X] T016 [US3] Create flow-logs.bicep using AVM `br/public:avm/res/network/network-watcher` flow-log submodule, configure Traffic Analytics with logAnalyticsWorkspaceId, accept nsgIds array parameter in infra/modules/flow-logs.bicep
- [X] T017 [US3] Integrate flow-logs module into main.bicep: collect managementNsgId from hub-network and workloadNsgId from spoke-network, pass as nsgIds array in infra/main.bicep
- [X] T018 [US3] Validate US3: run `az deployment group validate`, review template to confirm all resources have diagnosticSettings and all NSGs have flow logs

**Checkpoint**: Security by Default 完全適用。SC-004 (診断ログ) と SC-005 (フローログ) の検証条件が満たされる。

---

## Phase 6: User Story 4 — dev/prod 環境のパラメータ切り替え (Priority: P3)

**Goal**: 同一 Bicep コードベースから dev/prod パラメータファイル切り替えのみで、環境ごとに適切な SKU・スケール・冗長設定を持つネットワーク基盤をデプロイ可能にする

**Independent Test**: dev.bicepparam と prod.bicepparam のそれぞれで `az deployment group validate` が成功し、リソース名に環境トークン (dev/prod) が含まれ、FW SKU (Standard/Premium)・PIP zones・Log retention が環境に応じた値であることを確認

### Implementation for User Story 4

- [X] T019 [US4] Finalize dev.bicepparam with all parameters: environment='dev', hubAddressPrefix='10.0.0.0/16', spokeAddressPrefix='10.10.0.0/16', firewallSkuTier='Standard', logRetentionDays=30 in infra/parameters/dev.bicepparam
- [X] T020 [P] [US4] Create prod.bicepparam with prod-specific values: environment='prod', hubAddressPrefix='10.1.0.0/16', spokeAddressPrefix='10.11.0.0/16', firewallSkuTier='Premium', logRetentionDays=90, PIP zones=['1','2','3'] in infra/parameters/prod.bicepparam
- [X] T021 [US4] Validate US4: run `az deployment group validate` with both dev.bicepparam and prod.bicepparam, verify resource name differences and SKU variations in what-if output

**Checkpoint**: 環境分離完了。SC-001 (dev 単一コマンドデプロイ) と SC-002 (prod 同一コードベース) の条件が満たされる。

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: 最終バリデーションとドキュメント整合性の確認

- [X] T022 [P] Run comprehensive `az bicep lint` on all Bicep files in infra/ directory
- [X] T023 Validate quickstart.md commands against actual file paths and parameter names in specs/001-hub-spoke-network/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup ─────────────────────┐
                                    ▼
Phase 2: Foundational ──────────────┤ (Log Analytics = 全モジュールの前提)
                                    ▼
Phase 3: US1 (Hub+FW+Bastion) ─────┤ 🎯 MVP
                                    ▼
Phase 4: US2 (Spoke+Peering) ──────┤ (firewallPrivateIp に依存)
                                    ▼
Phase 5: US3 (Flow Logs) ──────────┤ (NSG IDs に依存)
                                    ▼
Phase 6: US4 (dev/prod params) ────┤ (全モジュール完成後)
                                    ▼
Phase 7: Polish ────────────────────┘
```

### User Story Dependencies

- **US1 (P1)**: Foundational (Phase 2) 完了後に開始可能。他 Story への依存なし
- **US2 (P2)**: US1 に依存（firewallPrivateIp が UDR の nextHop に必要）
- **US3 (P2)**: US1 + US2 に依存（NSG リソース ID がフローログのターゲット）
- **US4 (P3)**: US1〜US3 完了後が望ましい（全パラメータが確定してから環境差分を構成）

### Within Each User Story

- モジュールファイル（[P] マーク付き）は並列作成可能
- main.bicep への統合は全モジュール完成後
- バリデーション（lint + validate）は統合後に実施
- Checkpoint で Story 単独の動作確認

### Parallel Opportunities

**Phase 1**: T001 と T002 は並列可能
**Phase 3 (US1)**: T005, T006, T007 は並列可能（異なるファイル、依存なし）
**Phase 4 (US2)**: T011, T012 は並列可能（異なるファイル）
**Phase 6 (US4)**: T019, T020 は並列可能（異なるファイル）

---

## Parallel Example: User Story 1

```text
# 3 つのモジュールを並列で作成:
Task T005: hub-network.bicep (Hub VNet + subnets + NSG)
Task T006: firewall.bicep (Azure Firewall + Policy + PIP)
Task T007: bastion.bicep (Azure Bastion + PIP)

# 完了後、main.bicep に統合:
Task T008: main.bicep へ 3 モジュールを統合
```

## Parallel Example: User Story 2

```text
# 2 つのモジュールを並列で作成:
Task T011: spoke-network.bicep (Spoke VNet + NSG + UDR)
Task T012: peering.bicep (Hub↔Spoke bidirectional)

# 完了後、main.bicep に統合:
Task T013: main.bicep へ 2 モジュールを統合
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup（ディレクトリ構造 + bicepconfig.json）
2. Phase 2: Foundational（monitoring.bicep + main.bicep スキャフォールド）
3. Phase 3: User Story 1（Hub VNet + Firewall + Bastion）
4. **STOP and VALIDATE**: `az deployment group validate` で US1 単独デプロイ可能を確認
5. dev 環境に実デプロイして SC-006 (Bastion接続) を検証

### Incremental Delivery

1. Setup + Foundational → 基盤完了
2. + User Story 1 → Hub セキュリティ集約完了 → Validate/Deploy (**MVP!**)
3. + User Story 2 → Hub-Spoke トポロジ完成 → SC-003 (FW ルーティング) 検証可能
4. + User Story 3 → Security by Default 全面適用 → SC-004, SC-005 検証可能
5. + User Story 4 → 環境分離完了 → SC-001, SC-002 達成
6. 各 Story 追加は前の Story を壊さない（増分追加のみ）

### FR → Task Traceability

| FR | Task(s) | Story |
|----|---------|-------|
| FR-001 (Hub 3 subnets) | T005 | US1 |
| FR-002 (Firewall + PIP) | T006 | US1 |
| FR-003 (Bastion) | T007 | US1 |
| FR-004 (Spoke subnet) | T011 | US2 |
| FR-005 (Bidirectional peering) | T012 | US2 |
| FR-006 (UDR → FW) | T011 | US2 |
| FR-007 (NSG on all subnets) | T005, T011 | US1, US2 |
| FR-008 (Diagnostic settings) | T003, T005–T007, T011 | US1–US3 |
| FR-009 (NSG flow logs) | T016 | US3 |
| FR-010 (Log Analytics retention) | T003 | Foundational |
| FR-011 (environment param) | T004, T008, T013, T017 | All |
| FR-012 (Parameter files) | T009, T014, T019, T020 | US1–US4 |
| FR-013 (AVM usage) | T002–T007, T011, T012, T016 | All |
| FR-014 (FW deny-all + allow) | T006 | US1 |
| FR-015 (CAF naming) | T005–T007, T011 | US1, US2 |

---

## Notes

- [P] tasks = 異なるファイルで依存関係なし → 並列実行可能
- [Story] ラベルは spec.md の User Story にマッピング
- 各 User Story は独立して完了・検証可能
- Commit は各タスクまたは論理グループごとを推奨
- 任意の Checkpoint で Stop & Validate 可能
