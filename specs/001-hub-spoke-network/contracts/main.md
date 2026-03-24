# Bicep Module Contracts: Hub-Spoke Network

**Feature**: 001-hub-spoke-network | **Date**: 2026-03-24

## main.bicep — Orchestrator Contract

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `environment` | `'dev' \| 'prod'` | ✅ | - | デプロイ対象環境 |
| `location` | string | ❌ | `'eastus2'` | Azure リージョン |
| `hubAddressPrefix` | string | ❌ | env別 | Hub VNet アドレス空間 |
| `spokeAddressPrefix` | string | ❌ | env別 | Spoke VNet アドレス空間 |

### Outputs

| Output | Type | Description |
|--------|------|-------------|
| `hubVnetId` | string | Hub VNet リソース ID |
| `spokeVnetId` | string | Spoke VNet リソース ID |
| `firewallPrivateIp` | string | Azure Firewall プライベート IP |
| `bastionId` | string | Bastion リソース ID |
| `logAnalyticsWorkspaceId` | string | Log Analytics Workspace リソース ID |
| `resourceGroupName` | string | デプロイ先リソースグループ名 |

### Module Dependencies (deploy order)

```
1. monitoring.bicep     → logAnalyticsWorkspaceId
2. hub-network.bicep    → hubVnetId, hubSubnetIds
   spoke-network.bicep  → spokeVnetId (parallel with hub)
3. firewall.bicep       → firewallPrivateIp (depends on hubVnetId)
   bastion.bicep        → bastionId (depends on hubVnetId)
4. peering.bicep        → (depends on hubVnetId + spokeVnetId)
5. flow-logs.bicep      → (depends on NSG IDs + logAnalyticsWorkspaceId)
```

## Module Contracts

### hub-network.bicep

**Purpose**: Hub VNet + 3 subnets + management NSG を作成

| Parameter | Type | Description |
|-----------|------|-------------|
| `environment` | string | 環境名 |
| `location` | string | リージョン |
| `addressPrefix` | string | Hub VNet CIDR |
| `logAnalyticsWorkspaceId` | string | 診断設定送信先 |
| `tags` | object | リソースタグ |

| Output | Type |
|--------|------|
| `vnetId` | string |
| `vnetName` | string |
| `firewallSubnetId` | string |
| `bastionSubnetId` | string |
| `managementSubnetId` | string |
| `managementNsgId` | string |

### spoke-network.bicep

**Purpose**: Spoke VNet + workload subnet + NSG + Route Table を作成

| Parameter | Type | Description |
|-----------|------|-------------|
| `environment` | string | 環境名 |
| `location` | string | リージョン |
| `addressPrefix` | string | Spoke VNet CIDR |
| `firewallPrivateIp` | string | UDR の nextHop アドレス |
| `logAnalyticsWorkspaceId` | string | 診断設定送信先 |
| `tags` | object | リソースタグ |

| Output | Type |
|--------|------|
| `vnetId` | string |
| `vnetName` | string |
| `workloadSubnetId` | string |
| `workloadNsgId` | string |
| `routeTableId` | string |

### firewall.bicep

**Purpose**: Azure Firewall + Firewall Policy + Public IP を作成

| Parameter | Type | Description |
|-----------|------|-------------|
| `environment` | string | 環境名 |
| `location` | string | リージョン |
| `firewallSubnetId` | string | AzureFirewallSubnet リソース ID |
| `skuTier` | `'Standard' \| 'Premium'` | FW SKU |
| `logAnalyticsWorkspaceId` | string | 診断設定送信先 |
| `tags` | object | リソースタグ |

| Output | Type |
|--------|------|
| `firewallId` | string |
| `firewallPrivateIp` | string |
| `firewallPublicIp` | string |
| `firewallPolicyId` | string |

### bastion.bicep

**Purpose**: Azure Bastion (Standard) + Public IP を作成

| Parameter | Type | Description |
|-----------|------|-------------|
| `environment` | string | 環境名 |
| `location` | string | リージョン |
| `bastionSubnetId` | string | AzureBastionSubnet リソース ID |
| `logAnalyticsWorkspaceId` | string | 診断設定送信先 |
| `tags` | object | リソースタグ |

| Output | Type |
|--------|------|
| `bastionId` | string |
| `bastionPublicIp` | string |

### peering.bicep

**Purpose**: Hub↔Spoke 双方向 VNet Peering を作成

| Parameter | Type | Description |
|-----------|------|-------------|
| `hubVnetName` | string | Hub VNet 名 |
| `hubVnetId` | string | Hub VNet リソース ID |
| `spokeVnetName` | string | Spoke VNet 名 |
| `spokeVnetId` | string | Spoke VNet リソース ID |

| Output | Type |
|--------|------|
| `hubToSpokePeeringId` | string |
| `spokeToHubPeeringId` | string |

### monitoring.bicep

**Purpose**: Log Analytics Workspace を作成

| Parameter | Type | Description |
|-----------|------|-------------|
| `environment` | string | 環境名 |
| `location` | string | リージョン |
| `retentionInDays` | int | 保持期間（dev:30, prod:90） |
| `tags` | object | リソースタグ |

| Output | Type |
|--------|------|
| `workspaceId` | string |
| `workspaceName` | string |

### flow-logs.bicep

**Purpose**: NSG Flow Log を全 NSG に対して作成

| Parameter | Type | Description |
|-----------|------|-------------|
| `location` | string | リージョン |
| `nsgIds` | array | NSG リソース ID の配列 |
| `logAnalyticsWorkspaceId` | string | Traffic Analytics 送信先 |
| `tags` | object | リソースタグ |

| Output | Type |
|--------|------|
| `flowLogIds` | array |
