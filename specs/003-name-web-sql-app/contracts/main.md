# Bicep Module Contracts: Web App + SQL Database

**Feature**: 003-name-web-sql-app | **Date**: 2026-03-24

## main-web-sql.bicep — Orchestrator Contract

### Parameters

| Parameter | Type | Required | Default | Description | FR |
|-----------|------|----------|---------|-------------|-----|
| `environment` | `'dev' \| 'prod'` | ✅ | - | デプロイ対象環境 | FR-014 |
| `location` | string | ❌ | `'eastus2'` | Azure リージョン | Assumptions |
| `vnetAddressPrefix` | string | ✅ | - | VNet アドレス空間 CIDR | FR-009 |
| `appServiceSubnetPrefix` | string | ✅ | - | AppService サブネット CIDR | FR-009 |
| `privateEndpointSubnetPrefix` | string | ✅ | - | PrivateEndpoint サブネット CIDR | FR-009 |
| `defaultSubnetPrefix` | string | ✅ | - | Default サブネット CIDR | FR-009 |
| `appServicePlanSkuName` | string | ✅ | - | ASP SKU 名 (B1/P1v3) | FR-001 |
| `sqlDatabaseSkuName` | string | ✅ | - | SQL DB SKU 名 (Basic/S1) | FR-005 |
| `sqlDatabaseSkuTier` | string | ✅ | - | SQL DB SKU ティア | FR-005 |
| `sqlDatabaseSkuCapacity` | int | ✅ | - | SQL DB DTU 容量 | FR-005 |
| `sqlAdminUpn` | string | ✅ | - | Entra ID 管理者 UPN | FR-004 |
| `sqlAdminObjectId` | string | ✅ | - | Entra ID 管理者オブジェクト ID | FR-004 |
| `logRetentionDays` | int | ❌ | `30` | Log Analytics 保持期間 | FR-011 |
| `appInsightsSamplingPercentage` | int | ❌ | `100` | Application Insights サンプリング率 | FR-012 |

### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `webAppName` | string | Web App 名 |
| `webAppDefaultHostname` | string | Web App の FQDN (HTTPS) |
| `webAppManagedIdentityPrincipalId` | string | Web App MI のプリンシパル ID |
| `sqlServerFqdn` | string | SQL Server の FQDN |
| `sqlDatabaseName` | string | SQL Database 名 |
| `privateEndpointIp` | string | Private Endpoint のプライベート IP |
| `vnetId` | string | VNet リソース ID |
| `logAnalyticsWorkspaceId` | string | Log Analytics Workspace リソース ID |
| `appInsightsConnectionString` | string | Application Insights 接続文字列 |
| `resourceGroupName` | string | デプロイ先リソースグループ名 |

### Module Dependencies (deploy order)

```
1. web-sql-monitoring.bicep  → logAnalyticsWorkspaceId, appInsightsConnectionString
2. web-sql-network.bicep     → vnetId, subnetIds, nsgIds (parallel with step 1 if no diag)
3. app-service.bicep         → webAppName, webAppManagedIdentityPrincipalId
                                (depends on monitoring + network)
4. sql-database.bicep        → sqlServerFqdn, sqlDatabaseName, privateEndpointIp
                                (depends on network for PE subnet)
```

---

## Module Contracts

### web-sql-monitoring.bicep

**Purpose**: Log Analytics Workspace + Application Insights を作成

**AVM modules used**:
- `br/public:avm/res/operational-insights/workspace:0.15.0`
- `br/public:avm/res/insights/component:0.7.1`

| Parameter | Type | Description |
|-----------|------|-------------|
| `environment` | string | 環境名 |
| `location` | string | リージョン |
| `retentionInDays` | int | Log Analytics 保持期間 |
| `samplingPercentage` | int | Application Insights サンプリング率 |
| `tags` | object | リソースタグ |

| Output | Type |
|--------|------|
| `workspaceId` | string |
| `workspaceName` | string |
| `appInsightsId` | string |
| `appInsightsConnectionString` | string |
| `appInsightsInstrumentationKey` | string |

---

### web-sql-network.bicep

**Purpose**: VNet + 3 subnets + 3 NSGs を作成

**AVM modules used**:
- `br/public:avm/res/network/virtual-network:0.7.2`
- `br/public:avm/res/network/network-security-group:0.5.3`

| Parameter | Type | Description |
|-----------|------|-------------|
| `environment` | string | 環境名 |
| `location` | string | リージョン |
| `vnetAddressPrefix` | string | VNet CIDR |
| `appServiceSubnetPrefix` | string | AppServiceSubnet CIDR |
| `privateEndpointSubnetPrefix` | string | PrivateEndpointSubnet CIDR |
| `defaultSubnetPrefix` | string | DefaultSubnet CIDR |
| `logAnalyticsWorkspaceId` | string | 診断設定送信先 |
| `tags` | object | リソースタグ |

| Output | Type |
|--------|------|
| `vnetId` | string |
| `vnetName` | string |
| `appServiceSubnetId` | string |
| `privateEndpointSubnetId` | string |
| `defaultSubnetId` | string |
| `appServiceNsgId` | string |
| `privateEndpointNsgId` | string |
| `defaultNsgId` | string |

---

### app-service.bicep

**Purpose**: App Service Plan + Web App (VNet Integration + MI + App Insights) を作成

**AVM modules used**:
- `br/public:avm/res/web/serverfarm:0.7.0`
- `br/public:avm/res/web/site:0.22.0`

| Parameter | Type | Description |
|-----------|------|-------------|
| `environment` | string | 環境名 |
| `location` | string | リージョン |
| `appServicePlanSkuName` | string | ASP SKU 名 |
| `appServiceSubnetId` | string | VNet Integration 先サブネット ID |
| `appInsightsConnectionString` | string | App Insights 接続文字列 |
| `logAnalyticsWorkspaceId` | string | 診断設定送信先 |
| `tags` | object | リソースタグ |

| Output | Type |
|--------|------|
| `appServicePlanId` | string |
| `webAppId` | string |
| `webAppName` | string |
| `webAppDefaultHostname` | string |
| `webAppManagedIdentityPrincipalId` | string |

---

### sql-database.bicep

**Purpose**: SQL Server + Database + Private Endpoint + Private DNS Zone を作成

**AVM modules used**:
- `br/public:avm/res/sql/server:0.21.1`
- `br/public:avm/res/network/private-endpoint:0.12.0`
- `br/public:avm/res/network/private-dns-zone:0.8.1`

| Parameter | Type | Description |
|-----------|------|-------------|
| `environment` | string | 環境名 |
| `location` | string | リージョン |
| `sqlDatabaseSkuName` | string | DB SKU 名 |
| `sqlDatabaseSkuTier` | string | DB SKU ティア |
| `sqlDatabaseSkuCapacity` | int | DB DTU 容量 |
| `sqlAdminUpn` | string | Entra ID 管理者 UPN |
| `sqlAdminObjectId` | string | Entra ID 管理者オブジェクト ID |
| `privateEndpointSubnetId` | string | PE 配置先サブネット ID |
| `vnetId` | string | Private DNS Zone VNet リンク先 |
| `logAnalyticsWorkspaceId` | string | 診断設定送信先 |
| `tags` | object | リソースタグ |

| Output | Type |
|--------|------|
| `sqlServerId` | string |
| `sqlServerName` | string |
| `sqlServerFqdn` | string |
| `sqlDatabaseId` | string |
| `sqlDatabaseName` | string |
| `privateEndpointId` | string |
| `privateEndpointIp` | string |
| `privateDnsZoneId` | string |
