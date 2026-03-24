// ============================================================================
// Module: App Service — App Service Plan + Web App
// Feature: 003-name-web-sql-app (FR-001, FR-002, FR-003, FR-012, FR-013)
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name (dev/prod)')
param environment string

@description('Azure region')
param location string

@description('App Service Plan SKU name (B1/P1v3)')
param appServicePlanSkuName string

@description('App Service VNet Integration subnet resource ID')
param appServiceSubnetId string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Log Analytics Workspace resource ID for diagnostic settings')
param logAnalyticsWorkspaceId string

@description('Resource tags')
param tags object

// ============================================================================
// Variables
// ============================================================================

var regionShort = 'eus2'
var appServicePlanName = 'asp-web-sql-${environment}-${regionShort}'
var webAppName = 'app-web-sql-${environment}-${regionShort}'

// ============================================================================
// App Service Plan (FR-001)
// ============================================================================

module appServicePlan 'br/public:avm/res/web/serverfarm:0.7.0' = {
  name: 'deploy-app-service-plan'
  params: {
    name: appServicePlanName
    location: location
    skuName: appServicePlanSkuName
    kind: 'App'
    tags: tags
  }
}

// ============================================================================
// Web App (FR-002, FR-003, FR-012, FR-013)
// ============================================================================

module webApp 'br/public:avm/res/web/site:0.22.0' = {
  name: 'deploy-web-app'
  params: {
    name: webAppName
    location: location
    kind: 'app'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    httpsOnly: true
    virtualNetworkSubnetResourceId: appServiceSubnetId
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
      ]
    }
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

@description('App Service Plan resource ID')
output appServicePlanId string = appServicePlan.outputs.resourceId

@description('Web App resource ID')
output webAppId string = webApp.outputs.resourceId

@description('Web App name')
output webAppName string = webApp.outputs.name

@description('Web App default hostname')
output webAppDefaultHostname string = webApp.outputs.defaultHostname

@description('Web App Managed Identity principal ID')
output webAppManagedIdentityPrincipalId string = webApp.outputs.?systemAssignedMIPrincipalId ?? ''
