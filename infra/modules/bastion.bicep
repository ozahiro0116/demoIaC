// ============================================================================
// bastion.bicep — Azure Bastion (Standard SKU) + Public IP (FR-003)
// AVM: br/public:avm/res/network/bastion-host, public-ip-address
// ============================================================================

@description('Environment name')
param environment string

@description('Azure region')
param location string

@description('AzureBastionSubnet resource ID')
param bastionSubnetId string

@description('Log Analytics Workspace resource ID for diagnostic settings (FR-008)')
param logAnalyticsWorkspaceId string

@description('Resource tags')
param tags object

// ---------------------------------------------------------------------------
// Naming (FR-015: CAF convention)
// ---------------------------------------------------------------------------
var regionShort = 'eus2'
var bastionName = 'bas-hub-spoke-${environment}-${regionShort}'
var pipName = 'pip-bas-hub-spoke-${environment}-${regionShort}'

// PIP zones: prod gets zone-redundant, dev gets no zones
var pipZones = environment == 'prod' ? [1, 2, 3] : []

// ---------------------------------------------------------------------------
// Public IP for Bastion (FR-013)
// ---------------------------------------------------------------------------
module bastionPip 'br/public:avm/res/network/public-ip-address:0.9.1' = {
  name: 'deploy-${pipName}'
  params: {
    name: pipName
    location: location
    skuName: 'Standard'
    publicIPAllocationMethod: 'Static'
    availabilityZones: pipZones
    tags: tags
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Azure Bastion — Standard SKU with IP-based connection (FR-003, FR-013)
// ---------------------------------------------------------------------------
module bastionHost 'br/public:avm/res/network/bastion-host:0.8.2' = {
  name: 'deploy-${bastionName}'
  params: {
    name: bastionName
    location: location
    virtualNetworkResourceId: split(bastionSubnetId, '/subnets/')[0]
    skuName: 'Standard'
    enableIpConnect: true
    tags: tags
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Azure Bastion resource ID')
output bastionId string = bastionHost.outputs.resourceId

@description('Azure Bastion public IP address')
output bastionPublicIp string = bastionPip.outputs.ipAddress
