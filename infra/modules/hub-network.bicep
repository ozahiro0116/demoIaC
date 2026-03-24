// ============================================================================
// hub-network.bicep — Hub VNet + 3 Subnets + Management NSG (FR-001, FR-007)
// AVM: br/public:avm/res/network/virtual-network, network-security-group
// ============================================================================

@description('Environment name')
param environment string

@description('Azure region')
param location string

@description('Hub VNet address space CIDR')
param addressPrefix string

@description('Log Analytics Workspace resource ID for diagnostic settings (FR-008)')
param logAnalyticsWorkspaceId string

@description('Resource tags')
param tags object

// ---------------------------------------------------------------------------
// Naming (FR-015: CAF convention)
// ---------------------------------------------------------------------------
var regionShort = 'eus2'
var vnetName = 'vnet-hub-hub-spoke-${environment}-${regionShort}'
var nsgMgmtName = 'nsg-hub-mgmt-hub-spoke-${environment}-${regionShort}'

// Subnet CIDRs derived from address prefix
// Hub /16 → AzureFirewallSubnet /26, AzureBastionSubnet /26, ManagementSubnet /24
var baseOctets = split(split(addressPrefix, '/')[0], '.')
var firewallSubnetPrefix = '${baseOctets[0]}.${baseOctets[1]}.0.0/26'
var bastionSubnetPrefix = '${baseOctets[0]}.${baseOctets[1]}.0.64/26'
var managementSubnetPrefix = '${baseOctets[0]}.${baseOctets[1]}.1.0/24'

// ---------------------------------------------------------------------------
// NSG for Management Subnet (FR-007)
// ---------------------------------------------------------------------------
module managementNsg 'br/public:avm/res/network/network-security-group:0.5.2' = {
  name: 'deploy-${nsgMgmtName}'
  params: {
    name: nsgMgmtName
    location: location
    tags: tags
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Hub Virtual Network (FR-001, FR-013)
// ---------------------------------------------------------------------------
module hubVnet 'br/public:avm/res/network/virtual-network:0.7.2' = {
  name: 'deploy-${vnetName}'
  params: {
    name: vnetName
    location: location
    addressPrefixes: [
      addressPrefix
    ]
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: firewallSubnetPrefix
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: bastionSubnetPrefix
      }
      {
        name: 'ManagementSubnet'
        addressPrefix: managementSubnetPrefix
        networkSecurityGroupResourceId: managementNsg.outputs.resourceId
      }
    ]
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
@description('Hub VNet resource ID')
output vnetId string = hubVnet.outputs.resourceId

@description('Hub VNet name')
output vnetName string = hubVnet.outputs.name

@description('AzureFirewallSubnet resource ID')
output firewallSubnetId string = hubVnet.outputs.subnetResourceIds[0]

@description('AzureBastionSubnet resource ID')
output bastionSubnetId string = hubVnet.outputs.subnetResourceIds[1]

@description('ManagementSubnet resource ID')
output managementSubnetId string = hubVnet.outputs.subnetResourceIds[2]

@description('Management NSG resource ID')
output managementNsgId string = managementNsg.outputs.resourceId
