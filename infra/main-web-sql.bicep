// ============================================================================
// Orchestrator: Web App + SQL Database on Azure (AVM)
// Feature: 003-name-web-sql-app
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@allowed(['dev', 'prod'])
@description('Deployment environment (dev or prod)')
param environment string

@description('Azure region for all resources')
param location string = 'eastus2'

@description('VNet address space CIDR')
param vnetAddressPrefix string

@description('AppService subnet CIDR')
param appServiceSubnetPrefix string

@description('PrivateEndpoint subnet CIDR')
param privateEndpointSubnetPrefix string

@description('Default subnet CIDR')
param defaultSubnetPrefix string

@description('App Service Plan SKU name (B1/P1v3)')
param appServicePlanSkuName string

@description('SQL Database SKU name (Basic/S1)')
param sqlDatabaseSkuName string

@description('SQL Database SKU tier (Basic/Standard)')
param sqlDatabaseSkuTier string

@description('SQL Database DTU capacity')
param sqlDatabaseSkuCapacity int

@description('Entra ID administrator UPN for SQL Server')
param sqlAdminUpn string

@description('Entra ID administrator object ID for SQL Server')
param sqlAdminObjectId string

@description('Log Analytics data retention in days')
param logRetentionDays int = 30

@description('Application Insights sampling percentage')
param appInsightsSamplingPercentage int = 100

// ============================================================================
// Variables
// ============================================================================

var tags = {
  environment: environment
  project: 'web-sql'
  managedBy: 'bicep'
}

// ============================================================================
// Module: Monitoring (Phase 2 — blocking)
// ============================================================================

module monitoring 'modules/web-sql-monitoring.bicep' = {
  name: 'deploy-web-sql-monitoring'
  params: {
    environment: environment
    location: location
    retentionInDays: logRetentionDays
    samplingPercentage: appInsightsSamplingPercentage
    tags: tags
  }
}

// ============================================================================
// Module: Network (Phase 5 — depends on monitoring)
// ============================================================================

module network 'modules/web-sql-network.bicep' = {
  name: 'deploy-web-sql-network'
  params: {
    environment: environment
    location: location
    vnetAddressPrefix: vnetAddressPrefix
    appServiceSubnetPrefix: appServiceSubnetPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    defaultSubnetPrefix: defaultSubnetPrefix
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

// ============================================================================
// Module: App Service (Phase 3 — depends on monitoring + network)
// ============================================================================

module appService 'modules/app-service.bicep' = {
  name: 'deploy-app-service'
  params: {
    environment: environment
    location: location
    appServicePlanSkuName: appServicePlanSkuName
    appServiceSubnetId: network.outputs.appServiceSubnetId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

// ============================================================================
// Module: SQL Database (Phase 4 — depends on monitoring + network)
// ============================================================================

module sqlDatabase 'modules/sql-database.bicep' = {
  name: 'deploy-sql-database'
  params: {
    environment: environment
    location: location
    sqlDatabaseSkuName: sqlDatabaseSkuName
    sqlDatabaseSkuTier: sqlDatabaseSkuTier
    sqlDatabaseSkuCapacity: sqlDatabaseSkuCapacity
    sqlAdminUpn: sqlAdminUpn
    sqlAdminObjectId: sqlAdminObjectId
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    vnetId: network.outputs.vnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Web App name')
output webAppName string = appService.outputs.webAppName

@description('Web App default FQDN')
output webAppDefaultHostname string = appService.outputs.webAppDefaultHostname

@description('Web App Managed Identity principal ID')
output webAppManagedIdentityPrincipalId string = appService.outputs.webAppManagedIdentityPrincipalId

@description('SQL Server FQDN')
output sqlServerFqdn string = sqlDatabase.outputs.sqlServerFqdn

@description('SQL Database name')
output sqlDatabaseName string = sqlDatabase.outputs.sqlDatabaseName

@description('Private Endpoint private IP')
output privateEndpointIp string = sqlDatabase.outputs.privateEndpointIp

@description('VNet resource ID')
output vnetId string = network.outputs.vnetId

@description('Log Analytics Workspace resource ID')
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId

@description('Application Insights connection string')
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

@description('Resource group name')
output resourceGroupName string = resourceGroup().name
