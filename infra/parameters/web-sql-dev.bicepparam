using '../main-web-sql.bicep'

param environment = 'dev'
param location = 'eastus2'
param vnetAddressPrefix = '10.20.0.0/16'
param appServiceSubnetPrefix = '10.20.1.0/24'
param privateEndpointSubnetPrefix = '10.20.2.0/24'
param defaultSubnetPrefix = '10.20.3.0/24'
param appServicePlanSkuName = 'B1'
param sqlDatabaseSkuName = 'Basic'
param sqlDatabaseSkuTier = 'Basic'
param sqlDatabaseSkuCapacity = 5
param sqlAdminUpn = 'hozaki@MngEnvMCAP858742.onmicrosoft.com'
param sqlAdminObjectId = 'a26fee8b-e754-43ac-ad98-299ee8f2068b'
param logRetentionDays = 30
param appInsightsSamplingPercentage = 100
