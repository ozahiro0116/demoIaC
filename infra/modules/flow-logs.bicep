// ============================================================================
// flow-logs.bicep — NSG Flow Logs with Traffic Analytics (FR-009)
// Note: Azure API requires a storage account for flow logs even when
// Traffic Analytics sends data to Log Analytics.
// ============================================================================

@description('Environment name')
param environment string

@description('Azure region')
param location string

@description('NSG resource IDs to enable flow logs on')
param nsgIds array

@description('Log Analytics Workspace resource ID for Traffic Analytics')
param logAnalyticsWorkspaceId string

@description('Resource tags')
param tags object

// ---------------------------------------------------------------------------
// Naming
// ---------------------------------------------------------------------------
var regionShort = 'eus2'
// Storage account names: 3-24 chars, lowercase alphanumeric only
var storageAccountName = 'stflowlog${environment}${regionShort}'

// ---------------------------------------------------------------------------
// Storage Account for Flow Log data (Azure API requirement)
// ---------------------------------------------------------------------------
resource flowLogStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  tags: tags
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// ---------------------------------------------------------------------------
// NSG Flow Logs (FR-009)
// Create one flow log per NSG with Traffic Analytics → Log Analytics
// ---------------------------------------------------------------------------
resource flowLogs 'Microsoft.Network/networkWatchers/flowLogs@2024-05-01' = [
  for (nsgId, index) in nsgIds: {
    name: 'NetworkWatcher_${location}/flowlog-nsg-${index}'
    location: location
    tags: tags
    properties: {
      targetResourceId: nsgId
      storageId: flowLogStorage.id
      enabled: true
      format: {
        type: 'JSON'
        version: 2
      }
      retentionPolicy: {
        days: 30
        enabled: true
      }
      flowAnalyticsConfiguration: {
        networkWatcherFlowAnalyticsConfiguration: {
          enabled: true
          workspaceResourceId: logAnalyticsWorkspaceId
          trafficAnalyticsInterval: 10
        }
      }
    }
  }
]

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Flow Log resource IDs')
output flowLogIds array = [for (nsgId, index) in nsgIds: flowLogs[index].id]
