// ============================================================================
// peering.bicep — Hub↔Spoke Bidirectional VNet Peering (FR-005)
// Uses native Bicep resource (VNet Peering is a sub-resource of VNet)
// ============================================================================

@description('Hub VNet name')
param hubVnetName string

@description('Hub VNet resource ID')
param hubVnetId string

@description('Spoke VNet name')
param spokeVnetName string

@description('Spoke VNet resource ID')
param spokeVnetId string

// ---------------------------------------------------------------------------
// Hub → Spoke Peering (FR-005)
// ---------------------------------------------------------------------------
resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: '${hubVnetName}/peer-hub-to-spoke'
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

// ---------------------------------------------------------------------------
// Spoke → Hub Peering (FR-005)
// ---------------------------------------------------------------------------
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: '${spokeVnetName}/peer-spoke-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
@description('Hub to Spoke peering resource ID')
output hubToSpokePeeringId string = hubToSpokePeering.id

@description('Spoke to Hub peering resource ID')
output spokeToHubPeeringId string = spokeToHubPeering.id
