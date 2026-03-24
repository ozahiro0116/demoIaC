# Parameter File Contracts

**Feature**: 003-name-web-sql-app | **Date**: 2026-03-24

## web-sql-dev.bicepparam

```bicep
using '../main-web-sql.bicep'

param environment = 'dev'
param location = 'eastus2'
param vnetAddressPrefix = '10.20.0.0/16'
param appServiceSubnetPrefix = '10.20.1.0/24'
param privateEndpointSubnetPrefix = '10.20.2.0/24'
param defaultSubnetPrefix = '10.20.3.0/24'
param appServicePlanSkuName = 'B1'
param sqlDatabaseSkuName = 'Basic'
param sqlDatabaseSkuTier = 'Basic'
param sqlDatabaseSkuCapacity = 5
param sqlAdminUpn = '<deployer-upn>'
param sqlAdminObjectId = '<deployer-object-id>'
param logRetentionDays = 30
param appInsightsSamplingPercentage = 100
```

### dev 環境のパラメータ値

| Parameter | Value | Rationale | FR |
|-----------|-------|-----------|-----|
| environment | `'dev'` | 開発・テスト環境 | FR-014 |
| location | `'eastus2'` | デフォルトリージョン | Assumptions |
| vnetAddressPrefix | `'10.20.0.0/16'` | Assumptions | FR-009 |
| appServiceSubnetPrefix | `'10.20.1.0/24'` | VNet Integration 用 | FR-009 |
| privateEndpointSubnetPrefix | `'10.20.2.0/24'` | Private Endpoint 用 | FR-009 |
| defaultSubnetPrefix | `'10.20.3.0/24'` | 汎用 | FR-009 |
| appServicePlanSkuName | `'B1'` | Basic SKU (コスト最適化) | FR-001 |
| sqlDatabaseSkuName | `'Basic'` | 5 DTU | FR-005 |
| sqlDatabaseSkuTier | `'Basic'` | Basic ティア | FR-005 |
| sqlDatabaseSkuCapacity | `5` | 5 DTU | FR-005 |
| sqlAdminUpn | `'<deployer-upn>'` | デプロイ者が指定 | FR-004 |
| sqlAdminObjectId | `'<deployer-object-id>'` | デプロイ者が指定 | FR-004 |
| logRetentionDays | `30` | 無料枠内 | FR-011 |
| appInsightsSamplingPercentage | `100` | 全トラフィック収集 | FR-012 |

## web-sql-prod.bicepparam

```bicep
using '../main-web-sql.bicep'

param environment = 'prod'
param location = 'eastus2'
param vnetAddressPrefix = '10.21.0.0/16'
param appServiceSubnetPrefix = '10.21.1.0/24'
param privateEndpointSubnetPrefix = '10.21.2.0/24'
param defaultSubnetPrefix = '10.21.3.0/24'
param appServicePlanSkuName = 'P1v3'
param sqlDatabaseSkuName = 'S1'
param sqlDatabaseSkuTier = 'Standard'
param sqlDatabaseSkuCapacity = 20
param sqlAdminUpn = '<deployer-upn>'
param sqlAdminObjectId = '<deployer-object-id>'
param logRetentionDays = 90
param appInsightsSamplingPercentage = 50
```

### prod 環境のパラメータ値

| Parameter | Value | Rationale | FR |
|-----------|-------|-----------|-----|
| environment | `'prod'` | 本番環境 | FR-014 |
| location | `'eastus2'` | デフォルトリージョン | Assumptions |
| vnetAddressPrefix | `'10.21.0.0/16'` | Assumptions | FR-009 |
| appServiceSubnetPrefix | `'10.21.1.0/24'` | VNet Integration 用 | FR-009 |
| privateEndpointSubnetPrefix | `'10.21.2.0/24'` | Private Endpoint 用 | FR-009 |
| defaultSubnetPrefix | `'10.21.3.0/24'` | 汎用 | FR-009 |
| appServicePlanSkuName | `'P1v3'` | Premium V3 (高性能) | FR-001 |
| sqlDatabaseSkuName | `'S1'` | 20 DTU | FR-005 |
| sqlDatabaseSkuTier | `'Standard'` | Standard ティア | FR-005 |
| sqlDatabaseSkuCapacity | `20` | 20 DTU | FR-005 |
| sqlAdminUpn | `'<deployer-upn>'` | デプロイ者が指定 | FR-004 |
| sqlAdminObjectId | `'<deployer-object-id>'` | デプロイ者が指定 | FR-004 |
| logRetentionDays | `90` | インシデント調査期間 | FR-011 |
| appInsightsSamplingPercentage | `50` | 本番サンプリング | FR-012 |

## 環境差分まとめ

| Setting | dev | prod | FR |
|---------|-----|------|----|
| VNet CIDR | 10.20.0.0/16 | 10.21.0.0/16 | FR-009 |
| AppSvc Subnet | 10.20.1.0/24 | 10.21.1.0/24 | FR-009 |
| PE Subnet | 10.20.2.0/24 | 10.21.2.0/24 | FR-009 |
| Default Subnet | 10.20.3.0/24 | 10.21.3.0/24 | FR-009 |
| ASP SKU | B1 (Basic) | P1v3 (Premium V3) | FR-001 |
| SQL DB SKU | Basic (5 DTU) | S1 (20 DTU) | FR-005 |
| Log Retention | 30 days | 90 days | FR-011 |
| AI Sampling | 100% | 50% | FR-012 |
| Resource Names | `*-dev-eus2` | `*-prod-eus2` | FR-017 |
