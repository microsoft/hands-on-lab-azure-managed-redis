targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param name string

@description('The location where the resources will be created.')
@allowed([
  'eastus'
  'eastus2'
  'southcentralus'
  'swedencentral'
  'westus3'
])
param location string

@description('The environment deployed')
@allowed(['lab', 'dev', 'stg', 'prd'])
param environment string = 'lab'

@description('Name of the application')
param application string = 'rds'

@description('Optional. The tags to be assigned to the created resources.')
param tags object = {
  'azd-env-name': name
  Deployment: 'bicep'
  Environment: environment
  Location: location
  Application: application
  Lab: 'HoL Azure Managed Redis'
}

var resourceToken = toLower(uniqueString(subscription().id, name, environment, application))
var resourceSuffix = [
  toLower(environment)
  substring(toLower(location), 0, 2)
  substring(toLower(application), 0, 3)
  substring(resourceToken, 0, 8)
]
var resourceSuffixKebabcase = join(resourceSuffix, '-')
var resourceSuffixLowercase = join(resourceSuffix, '')

@description('The resource group.')
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${resourceSuffixKebabcase}'
  location: location
  tags: tags
}

module logAnalytics './modules/monitor/log.bicep' = {
  name: 'logAnalytics'
  scope: resourceGroup
  params: {
    name: 'log-${resourceSuffixKebabcase}'
    location: location
    tags: tags
  }
}

module loadTesting './modules/testing/load-testing.bicep' = {
  name: 'loadTesting'
  scope: resourceGroup
  params: {
    name: 'lt-${resourceSuffixKebabcase}'
    location: location
    tags: tags
  }
}

module managedRedis './modules/storage/managed-redis.bicep' = {
  name: 'managedRedis'
  scope: resourceGroup
  params: {
    name: 'redis-${resourceSuffixKebabcase}'
    location: location
    tags: tags
  }
}

module apim './modules/apis/apim.bicep' = {
  name: 'apim'
  scope: resourceGroup
  params: {
    name: 'apim-${resourceSuffixKebabcase}'
    location: location
    tags: tags
  }
}

module apimExternalCache './modules/apis/apim-external-cache.bicep' = {
  name: 'apimExternalCache'
  scope: resourceGroup
  params: {
    apimName: apim.outputs.name
    cacheResourceName: managedRedis.outputs.databaseResourceName
    cacheResourceEndpoint: managedRedis.outputs.endpoint
    cacheLocation: 'default'
  }
  dependsOn: [
    apim
    managedRedis
  ]
}

module cosmosDb './modules/storage/cosmos-db.bicep' = {
  name: 'cosmosDb'
  scope: resourceGroup
  params: {
    name: 'cosmos-${resourceSuffixKebabcase}'
    location: location
    tags: tags
  }
}

var cacheDeploymentPackageContainerName = 'cachedeploymentpackage'
var historyDeploymentPackageContainerName = 'historydeploymentpackage'

module storageAccountFunctions './modules/storage/storage-account.bicep' = {
  name: 'storageAccountFunctions'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    name: take('stfunc${resourceSuffixLowercase}', 24)
    containers: [
      {name: cacheDeploymentPackageContainerName}
      {name: historyDeploymentPackageContainerName}
    ]
  }
}

module applicationInsights './modules/monitor/application-insights.bicep' = {
  name: 'applicationInsights'
  scope: resourceGroup
  params: {
    name: 'appi-${resourceSuffixKebabcase}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

module cacheFunctionIdentity './modules/security/uami.bicep' = {
  name: 'cacheFunctionIdentity'
  scope: resourceGroup
  params: {
    name: 'uami-cache-${resourceSuffixKebabcase}'
    location: location
    tags: tags
  }
}

module cacheFunction './modules/host/function.bicep' = {
  name: 'cacheFunction'
  scope: resourceGroup
  params: {
    planName: 'asp-cache-${resourceSuffixKebabcase}'
    appName: 'func-cache-${resourceSuffixKebabcase}'
    location: location
    applicationInsightsName: applicationInsights.outputs.name
    userAssignedIdentityId: cacheFunctionIdentity.outputs.id
    storageAccountName: storageAccountFunctions.outputs.name
    deploymentStorageContainerName: cacheDeploymentPackageContainerName
    azdServiceName: 'cache-refresh'
    tags: tags
    appSettings: [
      {
        name  : 'REDIS_KEY_PRODUCTS_ALL'
        value : 'products:all'
      }
      {
        name  : 'AZURE_REDIS_TTL_IN_SECONDS'
        value : '60'
      }
      {
        name  : 'CATALOG_API_URL'
        value : apim.outputs.gatewayUrl
      }
      {
        name  : 'AZURE_REDIS_CONNECTION__redisHostName'
        value : managedRedis.outputs.hostName
      }
      {
        name  : 'AZURE_REDIS_CONNECTION__principalId'
        value : cacheFunctionIdentity.outputs.principalId
      }
      {
        name  : 'AZURE_REDIS_CONNECTION__clientId'
        value : cacheFunctionIdentity.outputs.clientId
      }
    ]
  }
}

module historyFunctionIdentity './modules/security/uami.bicep' = {
  name: 'historyFunctionIdentity'
  scope: resourceGroup
  params: {
    name: 'uami-hist-${resourceSuffixKebabcase}'
    location: location
    tags: tags
  }
}

module historyFunction './modules/host/function.bicep' = {
  name: 'historyFunction'
  scope: resourceGroup
  params: {
    planName: 'asp-hist-${resourceSuffixKebabcase}'
    appName: 'func-hist-${resourceSuffixKebabcase}'
    location: location
    applicationInsightsName: applicationInsights.outputs.name
    storageAccountName: storageAccountFunctions.outputs.name
    deploymentStorageContainerName: historyDeploymentPackageContainerName
    azdServiceName: 'history'
    tags: tags
    appSettings: [
      {
        name  : 'PRODUCT_VIEWS_STREAM_NAME'
        value : 'productViews'
      }
      {
        name  : 'AZURE_REDIS_CONNECTION__redisHostName'
        value : managedRedis.outputs.hostName
      }
      {
        name  : 'AZURE_REDIS_CONNECTION__principalId'
        value : historyFunctionIdentity.outputs.principalId
      }
      {
        name  : 'AZURE_REDIS_CONNECTION__clientId'
        value : historyFunctionIdentity.outputs.clientId
      }
      {
        name  : 'AZURE_REDIS_ENDPOINT'
        value : managedRedis.outputs.endpoint
      }
    ]
  }
}

module aiFoundry './modules/foundry/ai-foundry.bicep' = {
  name: 'aiFoundry'
  scope: resourceGroup
  params: {
    aiFoundryName: 'ais-${resourceSuffixKebabcase}'
    location: location
  }
}

module aiFoundryProject './modules/foundry/ai-foundry-project.bicep' = {
  name: 'aiFoundryProject'
  scope: resourceGroup
  params: {
    aiFoundryName: aiFoundry.outputs.name
    aiProjectName: 'prj-${resourceSuffixKebabcase}'
    location: location
  }
}

module chatDeploymentModel './modules/foundry/ai-foundry-model.bicep' = {
  name: 'chatDeploymentModel'
  scope: resourceGroup
  params: {
    aiFoundryName: aiFoundry.outputs.name
    modelName :'gpt-4.1-nano'
    modelCapacity : 100
    modelVersion: '2025-04-14'
  }
}

module embeddingsDeploymentModel './modules/foundry/ai-foundry-model.bicep' = {
  name: 'embeddingsDeploymentModel'
  scope: resourceGroup
  params: {
    aiFoundryName: aiFoundry.outputs.name
    modelName :'text-embedding-ada-002'
    modelCapacity : 100
    modelVersion: '2'
  }
  dependsOn:[chatDeploymentModel]
}

module appServicePlan './modules/host/appserviceplan.bicep' = {
  name: 'appServicePlan'
  scope: resourceGroup
  params: {
    name: 'asp-${resourceSuffixKebabcase}'
    location: location
    kind: 'Linux'
    sku: {
        name: 'S1'
        tier: 'Standard'
        size: 'S1'
        family: '1'
        capacity: 1
    }
    tags: tags
  }
}

// Catalog API
module appService './modules/host/appservice.bicep' = {
  name: 'appService'
  scope: resourceGroup
  params: {
    name: 'app-${resourceSuffixKebabcase}'
    location: location
    tags: union(tags, { 'azd-service-name': 'catalog-api' })
    applicationInsightsName: applicationInsights.outputs.name
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    managedIdentity: true
    appSettings: {
      AZURE_COSMOS_ENDPOINT: cosmosDb.outputs.endpoint
      AZURE_COSMOS_DATABASE: 'catalogdb'
      AZURE_REDIS_ENDPOINT: managedRedis.outputs.endpoint
      PRODUCT_LIST_CACHE_DISABLE: '0'
      SIMULATED_DB_LATENCY_IN_SECONDS: '2'
      PRODUCT_VIEWS_STREAM_NAME: 'productViews'
    }
  }
}

module roles './modules/security/roles.bicep' = {
  name: 'roles'
  scope: resourceGroup
  params: {
    cosmosDbAccountName: cosmosDb.outputs.name
    managedRedisDatabaseName: managedRedis.outputs.databaseResourceName
    historyFunctionUamiPrincipalId: historyFunctionIdentity.outputs.principalId
    historyFunctionPrincipalId: historyFunction.outputs.principalId
    cacheFunctionUamiPrincipalId: cacheFunctionIdentity.outputs.principalId
    cacheFunctionPrincipalId: cacheFunction.outputs.principalId
    appServicePrincipalId: appService.outputs.identityPrincipalId
    appInsightsName: applicationInsights.outputs.name
    currentUserObjectId: deployer().objectId
  }
}

output RESOURCE_GROUP string = resourceGroup.name
output APP_SERVICE_URI string = appService.outputs.uri
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
