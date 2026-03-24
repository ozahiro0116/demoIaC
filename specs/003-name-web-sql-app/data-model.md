# Data Model: Web App + SQL Database on Azure (AVM)

**Feature**: 003-name-web-sql-app | **Date**: 2026-03-24

## Entity Relationship Diagram

```
┌─────────────────────┐
│   Resource Group     │
│   rg-web-sql-*       │
└─────────┬───────────┘
          │ contains
          │
┌─────────▼───────────┐
│   Log Analytics WS   │◄─── diagnosticSettings ──── All Resources
│   log-web-sql-*      │
└─────────┬───────────┘
          │ workspaceResourceId
┌─────────▼───────────┐        ┌──────────────────────┐
│   Application        │        │   VNet                │
│   Insights           │        │   vnet-web-sql-*      │
│   appi-web-sql-*     │        │                       │
└─────────┬───────────┘        │ ┌─AppServiceSN───────┐│
          │ connectionString    │ │ /24                ││
          │                     │ │ delegation:Web/SF  ││
┌─────────▼───────────┐        │ │ ← nsg-appsvc-*    ││
│   App Service Plan   │        │ └────────┬──────────┘│
│   asp-web-sql-*      │        │ ┌─PrivateEndpointSN─┐│
│   B1 (dev) / P1v3    │        │ │ /24                ││
│                      │        │ │ ← nsg-pe-*        ││
│ ┌─ Web App ────────┐│        │ └────────┬──────────┘│
│ │ app-web-sql-*    ││        │ ┌─DefaultSN─────────┐│
│ │ MI: system       ││        │ │ /24                ││
│ │ VNet Integration─┼┼───────►│ │ ← nsg-default-*   ││
│ └──────────────────┘│        │ └───────────────────┘│
└──────────────────────┘        └──────────┬───────────┘
                                           │
          ┌────────────────────────────────┤
          │                                │
┌─────────▼───────────┐        ┌──────────▼──────────┐
│   Private DNS Zone   │        │   Private Endpoint   │
│   privatelink.       │◄──────│   pep-sql-web-sql-*  │
│   database.windows.  │ A rec │   ← PrivateEndpointSN│
│   net                │        └──────────┬──────────┘
│   ← VNet Link       │                   │ privateLinkServiceConnections
└──────────────────────┘        ┌──────────▼──────────┐
                                │   SQL Server         │
                                │   sql-web-sql-*      │
                                │   Entra ID Only      │
                                │   publicAccess: off  │
                                │                      │
                                │ ┌─ SQL Database ───┐ │
                                │ │ sqldb-web-sql-*  │ │
                                │ │ Basic/S1         │ │
                                │ └──────────────────┘ │
                                └──────────────────────┘
```

## Entities

### 1. Resource Group

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `rg-web-sql-{env}-{region}` | CAF 命名規則 (FR-017) |
| location | string | Azure region | default: eastus2 |
| tags | object | environment, project, managedBy | 必須タグ |

### 2. Log Analytics Workspace

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `log-web-sql-{env}-{region}` | FR-011 |
| sku | string | `PerGB2018` | 全環境共通 |
| retentionInDays | int | dev: 30, prod: 90 | FR-011 |
| diagnosticSettings | array | Log Analytics self | AVM パラメータ |

### 3. Application Insights

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `appi-web-sql-{env}-{region}` | FR-012 |
| kind | string | `web` | Web アプリケーション用 |
| applicationType | string | `web` | Web タイプ |
| workspaceResourceId | string | Log Analytics WS リソース ID | ワークスペースベース (FR-012) |
| samplingPercentage | int | dev: 100, prod: 50 | FR-012 |

### 4. Virtual Network

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `vnet-web-sql-{env}-{region}` | FR-009 |
| addressPrefixes | array | dev: `['10.20.0.0/16']`, prod: `['10.21.0.0/16']` | Assumptions |
| subnets[0] | object | AppServiceSubnet, /24, delegation | FR-009, FR-003 |
| subnets[1] | object | PrivateEndpointSubnet, /24 | FR-009, FR-006 |
| subnets[2] | object | DefaultSubnet, /24 | FR-009 |

**Subnet Details**:

| Subnet | CIDR (dev) | CIDR (prod) | NSG | Delegation | Purpose |
|--------|-----------|-------------|-----|------------|---------|
| AppServiceSubnet | 10.20.1.0/24 | 10.21.1.0/24 | nsg-appsvc-* | Microsoft.Web/serverFarms | VNet Integration |
| PrivateEndpointSubnet | 10.20.2.0/24 | 10.21.2.0/24 | nsg-pe-* | なし | Private Endpoint 配置 |
| DefaultSubnet | 10.20.3.0/24 | 10.21.3.0/24 | nsg-default-* | なし | 汎用 (将来拡張) |

### 5. Network Security Group (x3)

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `nsg-{purpose}-web-sql-{env}-{region}` | FR-010 |
| securityRules | array | 用途別ルール | FR-010 |

**NSG Rules — nsg-appsvc (App Service Subnet)**:

| Rule | Priority | Direction | Source | Dest | Port | Protocol | Action |
|------|----------|-----------|--------|------|------|----------|--------|
| AllowSqlOutbound | 100 | Outbound | VirtualNetwork | 10.20.2.0/24 | 1433 | TCP | Allow |
| AllowHttpsOutbound | 110 | Outbound | VirtualNetwork | Internet | 443 | TCP | Allow |

**NSG Rules — nsg-pe (Private Endpoint Subnet)**:

| Rule | Priority | Direction | Source | Dest | Port | Protocol | Action |
|------|----------|-----------|--------|------|------|----------|--------|
| AllowSqlFromAppSvc | 100 | Inbound | 10.20.1.0/24 | VirtualNetwork | 1433 | TCP | Allow |
| DenyAllInbound | 4096 | Inbound | * | * | * | * | Deny |

**NSG Rules — nsg-default (Default Subnet)**: デフォルトルールのみ（カスタムルールなし）

### 6. App Service Plan

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `asp-web-sql-{env}-{region}` | FR-001 |
| sku.name | string | dev: `B1`, prod: `P1v3` | FR-001 |
| kind | string | `linux` or `app` | OS タイプ |
| reserved | bool | Linux の場合 `true` | |

### 7. Web App (App Service)

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `app-web-sql-{env}-{region}` | FR-002 |
| kind | string | `app` | Web App |
| managedIdentities | object | `{ systemAssigned: true }` | FR-002 |
| virtualNetworkSubnetId | string | AppServiceSubnet リソース ID | FR-003 |
| siteConfig.appSettings | array | APPLICATIONINSIGHTS_CONNECTION_STRING | FR-012 |
| siteConfig.netFrameworkVersion | string | `v8.0` | Assumptions (.NET 8 default) |
| httpsOnly | bool | `true` | Security by Default |

### 8. Azure SQL Server

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `sql-web-sql-{env}-{region}` | FR-004 |
| administrators | object | Entra ID admin (UPN), azureADOnlyAuthentication: true | FR-004 |
| publicNetworkAccess | string | `Disabled` | FR-004 |
| minimalTlsVersion | string | `1.2` | Security by Default |

### 9. Azure SQL Database

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `sqldb-web-sql-{env}-{region}` | FR-005 |
| sku.name | string | dev: `Basic`, prod: `S1` | FR-005 |
| sku.tier | string | dev: `Basic`, prod: `Standard` | FR-005 |
| sku.capacity | int | dev: 5 (DTU), prod: 20 (DTU) | FR-005 |
| maxSizeBytes | int | dev: 2GB, prod: 250GB | SKU に応じた上限 |

### 10. Private Endpoint

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `pep-sql-web-sql-{env}-{region}` | FR-006 |
| subnetResourceId | string | PrivateEndpointSubnet リソース ID | FR-006 |
| privateLinkServiceConnections[0].privateLinkServiceId | string | SQL Server リソース ID | |
| privateLinkServiceConnections[0].groupIds | array | `['sqlServer']` | SQL Server グループ |
| privateDnsZoneGroup | object | Private DNS Zone リソース ID | 自動 A レコード登録 |

### 11. Private DNS Zone

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `privatelink.database.windows.net` | FR-007 (固定名) |
| virtualNetworkLinks[0] | object | VNet リソース ID, registrationEnabled: false | FR-007 |

### 12. Diagnostic Settings (各リソースに適用)

| Target Resource | Log Categories | Metrics | Notes |
|----------------|---------------|---------|-------|
| App Service | AppServiceHTTPLogs, AppServiceConsoleLogs, AppServiceAppLogs | AllMetrics | FR-013 |
| SQL Server | SQLSecurityAuditEvents | AllMetrics | FR-013 |
| NSG (x3) | NetworkSecurityGroupEvent, NetworkSecurityGroupRuleCounter | - | FR-013 |

**Note**: AVM モジュールの `diagnosticSettings` パラメータでインライン構成。別途モジュールは不要。
