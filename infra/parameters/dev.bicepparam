using '../main.bicep'

// FR-011: dev environment parameters
// FR-012: Separated parameter file
param environment = 'dev'
param location = 'eastus2'
param hubAddressPrefix = '10.0.0.0/16'
param spokeAddressPrefix = '10.10.0.0/16'
param firewallSkuTier = 'Standard'
param logRetentionDays = 30
