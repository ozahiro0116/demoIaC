// ============================================================================
// firewall.bicep — Azure Firewall + Policy + Public IP (FR-002, FR-014)
// AVM: br/public:avm/res/network/azure-firewall, firewall-policy, public-ip-address
// ============================================================================

@description('Environment name')
param environment string

@description('Azure region')
param location string

@description('AzureFirewallSubnet resource ID')
param firewallSubnetId string

@allowed(['Standard', 'Premium'])
@description('Firewall SKU tier (FR-011: dev=Standard, prod=Premium)')
param skuTier string

@description('Log Analytics Workspace resource ID for diagnostic settings (FR-008)')
param logAnalyticsWorkspaceId string

@description('Resource tags')
param tags object

// ---------------------------------------------------------------------------
// Naming (FR-015: CAF convention)
// ---------------------------------------------------------------------------
var regionShort = 'eus2'
var firewallName = 'fw-hub-spoke-${environment}-${regionShort}'
var policyName = 'fwp-hub-spoke-${environment}-${regionShort}'
var pipName = 'pip-fw-hub-spoke-${environment}-${regionShort}'

// PIP zones: prod gets zone-redundant, dev gets no zones (cost saving)
var pipZones = environment == 'prod' ? [1, 2, 3] : []

// ---------------------------------------------------------------------------
// Public IP for Firewall (FR-002, FR-013)
// ---------------------------------------------------------------------------
module firewallPip 'br/public:avm/res/network/public-ip-address:0.9.1' = {
  name: 'deploy-${pipName}'
  params: {
    name: pipName
    location: location
    skuName: 'Standard'
    publicIPAllocationMethod: 'Static'
    availabilityZones: pipZones
    tags: tags
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Firewall Policy with deny-all + allow HTTP/HTTPS (FR-014, FR-013)
// ---------------------------------------------------------------------------
module firewallPolicy 'br/public:avm/res/network/firewall-policy:0.3.4' = {
  name: 'deploy-${policyName}'
  params: {
    name: policyName
    location: location
    tier: skuTier
    tags: tags
    ruleCollectionGroups: [
      {
        name: 'rcg-allow-web-outbound'
        priority: 100
        ruleCollections: [
          {
            name: 'rc-allow-http-https'
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            priority: 100
            action: {
              type: 'Allow'
            }
            rules: [
              {
                name: 'allow-http'
                ruleType: 'ApplicationRule'
                sourceAddresses: ['*']
                protocols: [
                  {
                    protocolType: 'Http'
                    port: 80
                  }
                ]
                targetFqdns: ['*']
              }
              {
                name: 'allow-https'
                ruleType: 'ApplicationRule'
                sourceAddresses: ['*']
                protocols: [
                  {
                    protocolType: 'Https'
                    port: 443
                  }
                ]
                targetFqdns: ['*']
              }
            ]
          }
        ]
      }
      {
        name: 'rcg-deny-all'
        priority: 65000
        ruleCollections: [
          {
            name: 'rc-deny-all'
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            priority: 65000
            action: {
              type: 'Deny'
            }
            rules: [
              {
                name: 'deny-all-network'
                ruleType: 'NetworkRule'
                sourceAddresses: ['*']
                destinationAddresses: ['*']
                destinationPorts: ['*']
                ipProtocols: ['Any']
              }
            ]
          }
        ]
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Azure Firewall (FR-002, FR-013)
// ---------------------------------------------------------------------------
module azureFirewall 'br/public:avm/res/network/azure-firewall:0.10.0' = {
  name: 'deploy-${firewallName}'
  params: {
    name: firewallName
    location: location
    virtualNetworkResourceId: split(firewallSubnetId, '/subnets/')[0]
    azureSkuTier: skuTier
    firewallPolicyId: firewallPolicy.outputs.resourceId
    publicIPResourceID: firewallPip.outputs.resourceId
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
@description('Azure Firewall resource ID')
output firewallId string = azureFirewall.outputs.resourceId

@description('Azure Firewall private IP address')
output firewallPrivateIp string = azureFirewall.outputs.privateIp

@description('Azure Firewall public IP address')
output firewallPublicIp string = firewallPip.outputs.ipAddress

@description('Firewall Policy resource ID')
output firewallPolicyId string = firewallPolicy.outputs.resourceId
