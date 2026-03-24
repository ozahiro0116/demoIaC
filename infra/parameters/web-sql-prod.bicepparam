using '../main-web-sql.bicep'

param environment = 'prod'
param location = 'eastus2'
param vnetAddressPrefix = '10.21.0.0/16'
param appServiceSubnetPrefix = '10.21.1.0/24'
param privateEndpointSubnetPrefix = '10.21.2.0/24'
param defaultSubnetPrefix = '10.21.3.0/24'
param appServicePlanSkuName = 'P1v3'
param sqlDatabaseSkuName = 'S1'
param sqlDatabaseSkuTier = 'Standard'
param sqlDatabaseSkuCapacity = 20
param sqlAdminUpn = '<deployer-upn>'
param sqlAdminObjectId = '<deployer-object-id>'
param logRetentionDays = 90
param appInsightsSamplingPercentage = 50
