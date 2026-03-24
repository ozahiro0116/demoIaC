// ============================================================================
// Module: SQL Database — SQL Server + Database + Private Endpoint + Private DNS
// Feature: 003-name-web-sql-app (FR-004, FR-005, FR-006, FR-007, FR-013)
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name (dev/prod)')
param environment string

@description('Azure region')
param location string

@description('SQL Database SKU name (Basic/S1)')
param sqlDatabaseSkuName string

@description('SQL Database SKU tier (Basic/Standard)')
param sqlDatabaseSkuTier string

@description('SQL Database DTU capacity')
param sqlDatabaseSkuCapacity int

@description('Entra ID administrator UPN')
param sqlAdminUpn string

@description('Entra ID administrator object ID')
param sqlAdminObjectId string

@description('Private Endpoint subnet resource ID')
param privateEndpointSubnetId string

@description('VNet resource ID for Private DNS Zone link')
param vnetId string

@description('Log Analytics Workspace resource ID for diagnostic settings')
#disable-next-line no-unused-params
param logAnalyticsWorkspaceId string

@description('Resource tags')
param tags object

// ============================================================================
// Variables
// ============================================================================

var regionShort = 'eus2'
var sqlServerName = 'sql-web-sql-${environment}-${regionShort}'
var sqlDatabaseName = 'sqldb-web-sql-${environment}-${regionShort}'
var privateEndpointName = 'pep-sql-web-sql-${environment}-${regionShort}'
#disable-next-line no-hardcoded-env-urls
var privateDnsZoneName = 'privatelink.database.windows.net'

// ============================================================================
// SQL Server + Database (FR-004, FR-005)
// ============================================================================

module sqlServer 'br/public:avm/res/sql/server:0.21.1' = {
  name: 'deploy-sql-server'
  params: {
    name: sqlServerName
    location: location
    administrators: {
      azureADOnlyAuthentication: true
      administratorType: 'ActiveDirectory'
      login: sqlAdminUpn
      principalType: 'User'
      sid: sqlAdminObjectId
      tenantId: tenant().tenantId
    }
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'
    databases: [
      {
        name: sqlDatabaseName
        sku: {
          name: sqlDatabaseSkuName
          tier: sqlDatabaseSkuTier
          capacity: sqlDatabaseSkuCapacity
        }
        maxSizeBytes: sqlDatabaseSkuTier == 'Basic' ? 2147483648 : 34359738368
        availabilityZone: -1
        zoneRedundant: false
      }
    ]
    auditSettings: {
      state: 'Enabled'
      isAzureMonitorTargetEnabled: true
    }
    tags: tags
  }
}

// ============================================================================
// Private DNS Zone (FR-007)
// ============================================================================

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.8.1' = {
  name: 'deploy-private-dns-zone'
  params: {
    name: privateDnsZoneName
    virtualNetworkLinks: [
      {
        name: 'link-to-vnet'
        virtualNetworkResourceId: vnetId
        registrationEnabled: false
      }
    ]
    tags: tags
  }
}

// ============================================================================
// Private Endpoint (FR-006, FR-007)
// ============================================================================

module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.12.0' = {
  name: 'deploy-private-endpoint'
  params: {
    name: privateEndpointName
    location: location
    subnetResourceId: privateEndpointSubnetId
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-connection'
        properties: {
          privateLinkServiceId: sqlServer.outputs.resourceId
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'sqlPrivateDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'config1'
          privateDnsZoneResourceId: privateDnsZone.outputs.resourceId
        }
      ]
    }
    tags: tags
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('SQL Server resource ID')
output sqlServerId string = sqlServer.outputs.resourceId

@description('SQL Server name')
output sqlServerName string = sqlServer.outputs.name

@description('SQL Server FQDN')
output sqlServerFqdn string = sqlServer.outputs.fullyQualifiedDomainName

@description('SQL Database resource ID')
output sqlDatabaseId string = sqlServer.outputs.resourceId

@description('SQL Database name')
output sqlDatabaseName string = sqlDatabaseName

@description('Private Endpoint resource ID')
output privateEndpointId string = privateEndpoint.outputs.resourceId

@description('Private Endpoint private IP')
output privateEndpointIp string = length(privateEndpoint.outputs.customDnsConfigs) > 0 ? privateEndpoint.outputs.customDnsConfigs[0].ipAddresses[0] : ''

@description('Private DNS Zone resource ID')
output privateDnsZoneId string = privateDnsZone.outputs.resourceId
