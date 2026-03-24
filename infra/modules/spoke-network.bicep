// ============================================================================
// spoke-network.bicep — Spoke VNet + Workload Subnet + NSG + UDR (FR-004, FR-006, FR-007)
// AVM: br/public:avm/res/network/virtual-network, network-security-group, route-table
// ============================================================================

@description('Environment name')
param environment string

@description('Azure region')
param location string

@description('Spoke VNet address space CIDR')
param addressPrefix string

@description('Azure Firewall private IP for UDR next hop (FR-006)')
param firewallPrivateIp string

@description('Log Analytics Workspace resource ID for diagnostic settings (FR-008)')
param logAnalyticsWorkspaceId string

@description('Resource tags')
param tags object

// ---------------------------------------------------------------------------
// Naming (FR-015: CAF convention)
// ---------------------------------------------------------------------------
var regionShort = 'eus2'
var vnetName = 'vnet-spoke-hub-spoke-${environment}-${regionShort}'
var nsgName = 'nsg-spoke-wl-hub-spoke-${environment}-${regionShort}'
var routeTableName = 'rt-spoke-hub-spoke-${environment}-${regionShort}'

// Subnet CIDR: first /24 of the /16 address space
var baseOctets = split(split(addressPrefix, '/')[0], '.')
var workloadSubnetPrefix = '${baseOctets[0]}.${baseOctets[1]}.0.0/24'

// ---------------------------------------------------------------------------
// NSG for Workload Subnet (FR-007)
// ---------------------------------------------------------------------------
module workloadNsg 'br/public:avm/res/network/network-security-group:0.5.2' = {
  name: 'deploy-${nsgName}'
  params: {
    name: nsgName
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
// Route Table — default route to Azure Firewall (FR-006)
// ---------------------------------------------------------------------------
module routeTable 'br/public:avm/res/network/route-table:0.5.0' = {
  name: 'deploy-${routeTableName}'
  params: {
    name: routeTableName
    location: location
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'to-internet-via-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Spoke Virtual Network (FR-004, FR-013)
// ---------------------------------------------------------------------------
module spokeVnet 'br/public:avm/res/network/virtual-network:0.7.2' = {
  name: 'deploy-${vnetName}'
  params: {
    name: vnetName
    location: location
    addressPrefixes: [
      addressPrefix
    ]
    subnets: [
      {
        name: 'WorkloadSubnet'
        addressPrefix: workloadSubnetPrefix
        networkSecurityGroupResourceId: workloadNsg.outputs.resourceId
        routeTableResourceId: routeTable.outputs.resourceId
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
@description('Spoke VNet resource ID')
output vnetId string = spokeVnet.outputs.resourceId

@description('Spoke VNet name')
output vnetName string = spokeVnet.outputs.name

@description('Workload Subnet resource ID')
output workloadSubnetId string = spokeVnet.outputs.subnetResourceIds[0]

@description('Workload NSG resource ID')
output workloadNsgId string = workloadNsg.outputs.resourceId

@description('Route Table resource ID')
output routeTableId string = routeTable.outputs.resourceId
