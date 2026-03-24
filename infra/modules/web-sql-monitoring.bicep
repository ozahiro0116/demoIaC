// ============================================================================
// Module: Monitoring — Log Analytics Workspace + Application Insights
// Feature: 003-name-web-sql-app (FR-011, FR-012)
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name (dev/prod)')
param environment string

@description('Azure region')
param location string

@description('Log Analytics data retention in days')
param retentionInDays int

@description('Application Insights sampling percentage')
param samplingPercentage int

@description('Resource tags')
param tags object

// ============================================================================
// Variables
// ============================================================================

var regionShort = 'eus2'
var logAnalyticsName = 'log-web-sql-${environment}-${regionShort}'
var appInsightsName = 'appi-web-sql-${environment}-${regionShort}'

// ============================================================================
// Log Analytics Workspace (FR-011)
// ============================================================================

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.15.0' = {
  name: 'deploy-log-analytics'
  params: {
    name: logAnalyticsName
    location: location
    skuName: 'PerGB2018'
    dataRetention: retentionInDays
    tags: tags
  }
}

// ============================================================================
// Application Insights (FR-012)
// ============================================================================

module appInsights 'br/public:avm/res/insights/component:0.7.1' = {
  name: 'deploy-app-insights'
  params: {
    name: appInsightsName
    location: location
    workspaceResourceId: logAnalytics.outputs.resourceId
    kind: 'web'
    applicationType: 'web'
    samplingPercentage: samplingPercentage
    tags: tags
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Log Analytics Workspace resource ID')
output workspaceId string = logAnalytics.outputs.resourceId

@description('Log Analytics Workspace name')
output workspaceName string = logAnalytics.outputs.name

@description('Application Insights resource ID')
output appInsightsId string = appInsights.outputs.resourceId

@description('Application Insights connection string')
output appInsightsConnectionString string = appInsights.outputs.connectionString

@description('Application Insights instrumentation key')
output appInsightsInstrumentationKey string = appInsights.outputs.instrumentationKey
