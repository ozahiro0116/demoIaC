// ============================================================================
// monitoring.bicep — Log Analytics Workspace (FR-010, FR-008, FR-013)
// AVM: br/public:avm/res/operational-insights/workspace
// ============================================================================

@description('Environment name (dev or prod)')
param environment string

@description('Azure region for deployment')
param location string

@description('Data retention in days (FR-010: dev=30, prod=90)')
param retentionInDays int

@description('Resource tags')
param tags object

// ---------------------------------------------------------------------------
// Naming (FR-015: CAF naming convention)
// ---------------------------------------------------------------------------
var regionShort = 'eus2'
var workspaceName = 'log-hub-spoke-${environment}-${regionShort}'

// ---------------------------------------------------------------------------
// Log Analytics Workspace (FR-010, FR-013)
// ---------------------------------------------------------------------------
module workspace 'br/public:avm/res/operational-insights/workspace:0.9.1' = {
  name: 'deploy-${workspaceName}'
  params: {
    name: workspaceName
    location: location
    skuName: 'PerGB2018'
    dataRetention: retentionInDays
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Log Analytics Workspace resource ID')
output workspaceId string = workspace.outputs.resourceId

@description('Log Analytics Workspace name')
output workspaceName string = workspace.outputs.name
