# Implementation Plan: Hub-Spoke Network Infrastructure

**Branch**: `001-hub-spoke-network` | **Date**: 2026-03-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-hub-spoke-network/spec.md`

## Summary

Hub-Spoke ネットワーク基盤を Azure Verified Modules (AVM) Bicep で構築する。Hub VNet に Azure Firewall（deny-all + 最小 allow）と Bastion（Standard SKU）を配置し、Spoke VNet と VNet Peering + UDR で接続する。全リソースに NSG・診断設定・フローログを適用し、dev/prod 環境をパラメータファイル切替で管理する。CAF 準拠の命名規則 `{resourceType}-hub-spoke-{env}-{region}` を採用。

## Technical Context

**Language/Version**: Bicep (Azure CLI 2.67+ / Bicep CLI 0.32+)
**Primary Dependencies**: Azure Verified Modules (AVM) — 10 モジュール（詳細は research.md）
**Storage**: N/A（ネットワークインフラのみ）
**Testing**: `az bicep lint` → `az deployment group validate` → `az deployment group what-if`
**Target Platform**: Azure Resource Manager (ARM) — eastus2 リージョン
**Project Type**: IaC infrastructure project（Bicep モジュール構成）
**Performance Goals**: デプロイ完了 < 30 分、全リソース「正常」状態
**Constraints**: AVM モジュール使用率 90% 以上、Security by Default（NSG/診断設定必須）
**Scale/Scope**: Hub VNet x1 + Spoke VNet x1（初期）、将来 Spoke 追加可能な構造

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| **I. AVM First** | ✅ PASS | 10 リソースタイプすべてに AVM モジュールが存在。FR-013 で AVM 使用を義務化。バージョン固定で運用。 |
| **II. WAF Compliance** | ✅ PASS | Security pillar: NSG/FW/診断設定 (FR-007,008,014)。Reliability: Peering 双方向 (FR-005)。Operational Excellence: パラメータ分離 (FR-012)。 |
| **III. Security by Default** | ✅ PASS | 全サブネット NSG (FR-007)、全リソース診断設定 (FR-008)、NSG フローログ (FR-009)、FW deny-all (FR-014)、Bastion でパブリック IP 不要。 |
| **IV. Parameterization** | ✅ PASS | environment パラメータ (FR-011)、.bicepparam ファイル分離 (FR-012)、CAF 命名規則に env トークン (FR-015)。 |

**Gate Result**: ✅ ALL PASS — Phase 0 に進行可能。

## Project Structure

### Documentation (this feature)

```text
specs/001-hub-spoke-network/
├── plan.md              # This file
├── research.md          # Phase 0: AVM module research & decisions
├── data-model.md        # Phase 1: Entity/resource model
├── quickstart.md        # Phase 1: Getting started guide
├── contracts/           # Phase 1: Bicep interface contracts
│   ├── main.md          # Orchestrator module contract
│   └── parameters.md    # Parameter file contracts (dev/prod)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
infra/
├── main.bicep                    # Orchestrator — deploys all modules
├── modules/
│   ├── hub-network.bicep         # Hub VNet + subnets + NSGs
│   ├── spoke-network.bicep       # Spoke VNet + subnets + NSGs + UDR
│   ├── firewall.bicep            # Azure Firewall + Policy + Public IP
│   ├── bastion.bicep             # Azure Bastion + Public IP
│   ├── peering.bicep             # Bi-directional VNet Peering
│   ├── monitoring.bicep          # Log Analytics + diagnostic settings
│   └── flow-logs.bicep           # NSG Flow Logs
├── parameters/
│   ├── dev.bicepparam            # dev environment parameters
│   └── prod.bicepparam           # prod environment parameters
└── bicepconfig.json              # AVM registry + linter settings
```

**Structure Decision**: IaC プロジェクトのため `infra/` ディレクトリにフラット構造で配置。各 Bicep ファイルは 1 つのリソースグループ or 論理単位に対応し、main.bicep がオーケストレーターとして全モジュールを呼び出す。パラメータファイルは環境ごとに分離。

## Complexity Tracking

> 憲法違反なし — このセクションは空。
