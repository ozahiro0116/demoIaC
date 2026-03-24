// ============================================================================
// main.bicep — Hub-Spoke Network Infrastructure Orchestrator
// REQ: FR-011 (environment param), FR-012 (parameter files), FR-013 (AVM)
// ============================================================================

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Parameters (FR-011, FR-012)
// ---------------------------------------------------------------------------
@allowed(['dev', 'prod'])
@description('Deployment environment')
param environment string

@description('Azure region')
param location string = 'eastus2'

@description('Hub VNet address space CIDR')
param hubAddressPrefix string

@description('Spoke VNet address space CIDR')
param spokeAddressPrefix string

@allowed(['Standard', 'Premium'])
@description('Azure Firewall SKU tier (FR-011: dev=Standard, prod=Premium)')
param firewallSkuTier string

@description('Log Analytics data retention in days (FR-010: dev=30, prod=90)')
param logRetentionDays int

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
var tags = {
  project: 'hub-spoke'
  environment: environment
  managedBy: 'bicep'
}

// ---------------------------------------------------------------------------
// Phase 1: Monitoring — Log Analytics Workspace (FR-010)
// ---------------------------------------------------------------------------
module monitoring 'modules/monitoring.bicep' = {
  name: 'deploy-monitoring'
  params: {
    environment: environment
    location: location
    retentionInDays: logRetentionDays
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Phase 2: Hub Network — VNet + Subnets + NSG (FR-001, FR-007)
// ---------------------------------------------------------------------------
module hubNetwork 'modules/hub-network.bicep' = {
  name: 'deploy-hub-network'
  params: {
    environment: environment
    location: location
    addressPrefix: hubAddressPrefix
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Phase 3: Firewall — Azure Firewall + Policy + PIP (FR-002, FR-014)
// ---------------------------------------------------------------------------
module firewall 'modules/firewall.bicep' = {
  name: 'deploy-firewall'
  params: {
    environment: environment
    location: location
    firewallSubnetId: hubNetwork.outputs.firewallSubnetId
    skuTier: firewallSkuTier
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Phase 3: Bastion — Azure Bastion + PIP (FR-003)
// ---------------------------------------------------------------------------
module bastion 'modules/bastion.bicep' = {
  name: 'deploy-bastion'
  params: {
    environment: environment
    location: location
    bastionSubnetId: hubNetwork.outputs.bastionSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Phase 4: Spoke Network — VNet + Subnet + NSG + UDR (FR-004, FR-006, FR-007)
// ---------------------------------------------------------------------------
module spokeNetwork 'modules/spoke-network.bicep' = {
  name: 'deploy-spoke-network'
  params: {
    environment: environment
    location: location
    addressPrefix: spokeAddressPrefix
    firewallPrivateIp: firewall.outputs.firewallPrivateIp
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Phase 5: VNet Peering — Hub↔Spoke bidirectional (FR-005)
// ---------------------------------------------------------------------------
module peering 'modules/peering.bicep' = {
  name: 'deploy-peering'
  params: {
    hubVnetName: hubNetwork.outputs.vnetName
    hubVnetId: hubNetwork.outputs.vnetId
    spokeVnetName: spokeNetwork.outputs.vnetName
    spokeVnetId: spokeNetwork.outputs.vnetId
  }
}

// ---------------------------------------------------------------------------
// Phase 6: NSG Flow Logs (FR-009)
// ---------------------------------------------------------------------------
module flowLogs 'modules/flow-logs.bicep' = {
  name: 'deploy-flow-logs'
  params: {
    environment: environment
    location: location
    nsgIds: [
      hubNetwork.outputs.managementNsgId
      spokeNetwork.outputs.workloadNsgId
    ]
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Hub VNet resource ID')
output hubVnetId string = hubNetwork.outputs.vnetId

@description('Spoke VNet resource ID')
output spokeVnetId string = spokeNetwork.outputs.vnetId

@description('Azure Firewall private IP address')
output firewallPrivateIp string = firewall.outputs.firewallPrivateIp

@description('Azure Bastion resource ID')
output bastionId string = bastion.outputs.bastionId

@description('Log Analytics Workspace resource ID')
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId

@description('Resource group name')
output resourceGroupName string = resourceGroup().name
