using '../main.bicep'

// FR-011: prod environment parameters
// FR-012: Separated parameter file
param environment = 'prod'
param location = 'eastus2'
param hubAddressPrefix = '10.1.0.0/16'
param spokeAddressPrefix = '10.11.0.0/16'
param firewallSkuTier = 'Premium'
param logRetentionDays = 90
