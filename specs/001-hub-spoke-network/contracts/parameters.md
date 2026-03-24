# Parameter File Contracts

**Feature**: 001-hub-spoke-network | **Date**: 2026-03-24

## dev.bicepparam

```bicep
using '../main.bicep'

param environment = 'dev'
param location = 'eastus2'
```

### dev 環境のパラメータ値

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| environment | `'dev'` | 開発・テスト環境 |
| location | `'eastus2'` | デフォルトリージョン |
| hubAddressPrefix | `'10.0.0.0/16'` | spec Assumptions |
| spokeAddressPrefix | `'10.10.0.0/16'` | spec Assumptions |
| firewallSkuTier | `'Standard'` | コスト最適化 |
| bastionSku | `'Standard'` | IP-based connection 必須 |
| logRetentionDays | `30` | 無料枠内 |

## prod.bicepparam

```bicep
using '../main.bicep'

param environment = 'prod'
param location = 'eastus2'
```

### prod 環境のパラメータ値

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| environment | `'prod'` | 本番環境 |
| location | `'eastus2'` | デフォルトリージョン |
| hubAddressPrefix | `'10.1.0.0/16'` | spec Assumptions |
| spokeAddressPrefix | `'10.11.0.0/16'` | spec Assumptions |
| firewallSkuTier | `'Premium'` | 高度な脅威検知 |
| bastionSku | `'Standard'` | IP-based connection 必須 |
| logRetentionDays | `90` | インシデント調査期間 |

## 環境差分まとめ

| Setting | dev | prod | FR |
|---------|-----|------|----|
| Hub CIDR | 10.0.0.0/16 | 10.1.0.0/16 | FR-011 |
| Spoke CIDR | 10.10.0.0/16 | 10.11.0.0/16 | FR-011 |
| Firewall SKU | Standard | Premium | FR-011 |
| Bastion SKU | Standard | Standard | Clarification Q3 |
| Log Retention | 30 days | 90 days | FR-010 |
| PIP Zones | [] | ['1','2','3'] | WAF Reliability |
