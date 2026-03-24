# Data Model: Hub-Spoke Network Infrastructure

**Feature**: 001-hub-spoke-network | **Date**: 2026-03-24

## Entity Relationship Diagram

```
┌─────────────────────┐
│   Resource Group     │
│   rg-hub-spoke-*     │
└─────────┬───────────┘
          │ contains
          ├──────────────────────────────────────────────────┐
          │                                                  │
┌─────────▼───────────┐                          ┌──────────▼──────────┐
│   Log Analytics WS   │◄─── diagnosticSettings ──│  All Resources      │
│   log-hub-spoke-*    │                          └─────────────────────┘
└──────────────────────┘
          │
          ├── retentionInDays: dev=30, prod=90
          │
┌─────────▼───────────┐        ┌──────────────────┐
│   Hub VNet           │◄──────►│   Spoke VNet      │
│   vnet-hub-*         │ Peering│   vnet-spoke-*    │
│                      │        │                   │
│ ┌─AzureFirewallSN──┐│        │ ┌─WorkloadSN────┐ │
│ │ /26              ││        │ │ /24           │ │
│ └──────────────────┘│        │ │ ← NSG + UDR   │ │
│ ┌─AzureBastionSN──┐│        │ └───────────────┘ │
│ │ /26              ││        └───────────────────┘
│ └──────────────────┘│
│ ┌─ManagementSN────┐│
│ │ /24  ← NSG      ││
│ └──────────────────┘│
└──────────────────────┘
          │ hosts
          ├───────────────────────┐
┌─────────▼───────────┐ ┌───────▼───────────┐
│   Azure Firewall     │ │   Azure Bastion    │
│   fw-hub-spoke-*     │ │   bas-hub-spoke-*  │
│   ← pip-fw-*         │ │   ← pip-bas-*      │
│   ← fwp-hub-spoke-*  │ │   SKU: Standard    │
└──────────────────────┘ └────────────────────┘
```

## Entities

### 1. Resource Group

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `rg-hub-spoke-{env}-{region}` | CAF 命名規則 |
| location | string | Azure region | default: eastus2 |
| tags | object | environment, project | 必須タグ |

### 2. Log Analytics Workspace

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `log-hub-spoke-{env}-{region}` | |
| sku | string | `PerGB2018` | 全環境共通 |
| retentionInDays | int | dev: 30, prod: 90 | FR-010 |

### 3. Hub Virtual Network

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `vnet-hub-hub-spoke-{env}-{region}` | |
| addressPrefixes | array | dev: `['10.0.0.0/16']`, prod: `['10.1.0.0/16']` | |
| subnets[0] | object | name: `AzureFirewallSubnet`, prefix: `/26` | NSG 不可 |
| subnets[1] | object | name: `AzureBastionSubnet`, prefix: `/26` | NSG 不可 |
| subnets[2] | object | name: `ManagementSubnet`, prefix: `/24` | NSG 必須 (FR-007) |

**State transitions**: N/A (宣言的リソース)

### 4. Spoke Virtual Network

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `vnet-spoke-hub-spoke-{env}-{region}` | |
| addressPrefixes | array | dev: `['10.10.0.0/16']`, prod: `['10.11.0.0/16']` | |
| subnets[0] | object | name: `WorkloadSubnet`, prefix: `/24` | NSG + UDR 必須 |

### 5. Network Security Group (x2)

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `nsg-{purpose}-hub-spoke-{env}-{region}` | Hub mgmt / Spoke wl |
| securityRules | array | デフォルト拒否 + 必要な allow | FR-007 |

### 6. Route Table

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `rt-spoke-hub-spoke-{env}-{region}` | |
| routes[0] | object | name: `to-internet`, prefix: `0.0.0.0/0`, nextHop: FW private IP | FR-006 |
| disableBgpRoutePropagation | bool | `true` | Spoke トラフィック完全制御 |

### 7. Azure Firewall

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `fw-hub-spoke-{env}-{region}` | |
| sku.tier | string | dev: `Standard`, prod: `Premium` | FR-011 |
| firewallPolicyId | string | Firewall Policy リソース ID | |
| ipConfigurations[0].publicIPAddressId | string | pip-fw-* | FR-002 |

### 8. Firewall Policy

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `fwp-hub-spoke-{env}-{region}` | |
| sku.tier | string | dev: `Standard`, prod: `Premium` | Firewall SKU と一致必須 |
| ruleCollectionGroups | array | deny-all (65000) + allow HTTP/HTTPS (100) | FR-014 |

### 9. Azure Bastion

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `bas-hub-spoke-{env}-{region}` | |
| sku | string | `Standard` | 全環境 Standard (IP-based connection 必須) |
| ipConfigurations[0].publicIPAddressId | string | pip-bas-* | |
| enableIpConnect | bool | `true` | Spoke VM への接続に必須 |

### 10. Public IP Address (x2)

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `pip-{fw|bas}-hub-spoke-{env}-{region}` | |
| sku.name | string | `Standard` | Firewall/Bastion で必須 |
| allocationMethod | string | `Static` | |
| zones | array | `['1','2','3']` (prod) / `[]` (dev) | |

### 11. VNet Peering (x2: Hub→Spoke, Spoke→Hub)

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| name | string | `peer-hub-to-spoke` / `peer-spoke-to-hub` | |
| allowForwardedTraffic | bool | `true` | FW 経由ルーティングに必須 |
| allowGatewayTransit | bool | Hub→Spoke: `true` | 将来の GW 追加に対応 |
| useRemoteGateways | bool | Spoke→Hub: `false` | GW 未構成のため |

### 12. NSG Flow Log

| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| targetResourceId | string | NSG リソース ID | 各 NSG に 1 つ |
| storageId | string | N/A (Log Analytics 直接送信) | |
| enabled | bool | `true` | FR-009 |
| flowAnalyticsConfiguration | object | workspaceResourceId → Log Analytics | |

## Relationships

| From | To | Type | Cardinality |
|------|----|------|-------------|
| Resource Group | All Resources | contains | 1:N |
| Hub VNet | Spoke VNet | VNet Peering | 1:N (初期 1:1) |
| Hub VNet.AzureFirewallSubnet | Azure Firewall | hosts | 1:1 |
| Hub VNet.AzureBastionSubnet | Azure Bastion | hosts | 1:1 |
| NSG | Subnet | attached-to | 1:1 |
| Route Table | Spoke Subnet | attached-to | 1:N |
| Firewall Policy | Azure Firewall | referenced-by | 1:1 |
| Log Analytics | All Resources | receives-logs-from | 1:N |
| Public IP | Firewall / Bastion | assigned-to | 1:1 |
