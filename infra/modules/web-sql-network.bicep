// ============================================================================
// Module: Network — VNet + 3 Subnets + 3 NSGs
// Feature: 003-name-web-sql-app (FR-009, FR-010, FR-003)
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name (dev/prod)')
param environment string

@description('Azure region')
param location string

@description('VNet address space CIDR')
param vnetAddressPrefix string

@description('AppService subnet CIDR')
param appServiceSubnetPrefix string

@description('PrivateEndpoint subnet CIDR')
param privateEndpointSubnetPrefix string

@description('Default subnet CIDR')
param defaultSubnetPrefix string

@description('Log Analytics Workspace resource ID for diagnostic settings')
param logAnalyticsWorkspaceId string

@description('Resource tags')
param tags object

// ============================================================================
// Variables
// ============================================================================

var regionShort = 'eus2'
var vnetName = 'vnet-web-sql-${environment}-${regionShort}'
var nsgAppSvcName = 'nsg-appsvc-web-sql-${environment}-${regionShort}'
var nsgPeName = 'nsg-pe-web-sql-${environment}-${regionShort}'
var nsgDefaultName = 'nsg-default-web-sql-${environment}-${regionShort}'

// ============================================================================
// NSG: App Service Subnet (FR-010)
// ============================================================================

module nsgAppSvc 'br/public:avm/res/network/network-security-group:0.5.3' = {
  name: 'deploy-nsg-appsvc'
  params: {
    name: nsgAppSvcName
    location: location
    securityRules: [
      {
        name: 'AllowSqlOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: privateEndpointSubnetPrefix
        }
      }
      {
        name: 'AllowHttpsOutbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Internet'
        }
      }
    ]
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
        logCategoriesAndGroups: [
          { categoryGroup: 'allLogs' }
        ]
      }
    ]
    tags: tags
  }
}

// ============================================================================
// NSG: Private Endpoint Subnet (FR-010)
// ============================================================================

module nsgPe 'br/public:avm/res/network/network-security-group:0.5.3' = {
  name: 'deploy-nsg-pe'
  params: {
    name: nsgPeName
    location: location
    securityRules: [
      {
        name: 'AllowSqlFromAppSvc'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: appServiceSubnetPrefix
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
        logCategoriesAndGroups: [
          { categoryGroup: 'allLogs' }
        ]
      }
    ]
    tags: tags
  }
}

// ============================================================================
// NSG: Default Subnet (FR-010)
// ============================================================================

module nsgDefault 'br/public:avm/res/network/network-security-group:0.5.3' = {
  name: 'deploy-nsg-default'
  params: {
    name: nsgDefaultName
    location: location
    securityRules: []
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
        logCategoriesAndGroups: [
          { categoryGroup: 'allLogs' }
        ]
      }
    ]
    tags: tags
  }
}

// ============================================================================
// VNet + 3 Subnets (FR-009, FR-003)
// ============================================================================

module vnet 'br/public:avm/res/network/virtual-network:0.7.2' = {
  name: 'deploy-vnet'
  params: {
    name: vnetName
    location: location
    addressPrefixes: [
      vnetAddressPrefix
    ]
    subnets: [
      {
        name: 'AppServiceSubnet'
        addressPrefix: appServiceSubnetPrefix
        networkSecurityGroupResourceId: nsgAppSvc.outputs.resourceId
        delegation: 'Microsoft.Web/serverFarms'
      }
      {
        name: 'PrivateEndpointSubnet'
        addressPrefix: privateEndpointSubnetPrefix
        networkSecurityGroupResourceId: nsgPe.outputs.resourceId
      }
      {
        name: 'DefaultSubnet'
        addressPrefix: defaultSubnetPrefix
        networkSecurityGroupResourceId: nsgDefault.outputs.resourceId
      }
    ]
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
        logCategoriesAndGroups: [
          { categoryGroup: 'allLogs' }
        ]
        metricCategories: [
          { category: 'AllMetrics' }
        ]
      }
    ]
    tags: tags
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('VNet resource ID')
output vnetId string = vnet.outputs.resourceId

@description('VNet name')
output vnetName string = vnet.outputs.name

@description('App Service subnet resource ID')
output appServiceSubnetId string = vnet.outputs.subnetResourceIds[0]

@description('Private Endpoint subnet resource ID')
output privateEndpointSubnetId string = vnet.outputs.subnetResourceIds[1]

@description('Default subnet resource ID')
output defaultSubnetId string = vnet.outputs.subnetResourceIds[2]

@description('App Service NSG resource ID')
output appServiceNsgId string = nsgAppSvc.outputs.resourceId

@description('Private Endpoint NSG resource ID')
output privateEndpointNsgId string = nsgPe.outputs.resourceId

@description('Default NSG resource ID')
output defaultNsgId string = nsgDefault.outputs.resourceId
