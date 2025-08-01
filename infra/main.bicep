targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param name string

@description('The environment deployed')
@allowed(['lab', 'dev', 'stg', 'prd'])
param environment string = 'lab'

@description('Name of the application')
param application string = 'rds'

@description('The location where the resources will be created.')
@allowed([
  'eastus'
  'eastus2'
  'southcentralus'
  'swedencentral'
  'westus3'
])
param location string = 'eastus2'

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
    tags: tags
  }
}

module loadTesting './modules/testing/load-testing.bicep' = {
  name: 'loadTesting'
  scope: resourceGroup
  params: {
    name: 'lt-${resourceSuffixKebabcase}'
    tags: tags
  }
}

module apim './modules/apis/apim.bicep' = {
  name: 'apim'
  scope: resourceGroup
  params: {
    name: 'apim-${resourceSuffixKebabcase}'
    tags: tags
  }
}

module cosmosDb './modules/storage/cosmos-db.bicep' = {
  name: 'cosmosDb'
  scope: resourceGroup
  params: {
    name: 'cosmos-${resourceSuffixKebabcase}'
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
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}


module cacheFunction './modules/host/function.bicep' = {
  name: 'cacheFunction'
  scope: resourceGroup
  params: {
    planName: 'asp-cache-${resourceSuffixKebabcase}'
    appName: 'func-cache-${resourceSuffixKebabcase}'
    applicationInsightsName: applicationInsights.outputs.name
    storageAccountName: storageAccountFunctions.outputs.name
    deploymentStorageContainerName: cacheDeploymentPackageContainerName
    azdServiceName: 'cache'
    tags: tags
    appSettings: [
      {
        name  : 'REDIS_PRODUCT_ALL'
        value : 'products:all'
      }
      {
        name  : 'CATALOG_API_URL'
        value : apim.outputs.gatewayUrl
      }
    ]
  }
}

module historyFunction './modules/host/function.bicep' = {
  name: 'historyFunction'
  scope: resourceGroup
  params: {
    planName: 'asp-hist-${resourceSuffixKebabcase}'
    appName: 'func-hist-${resourceSuffixKebabcase}'
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
    ]
  }
}

module aiFoundry './modules/foundry/ai-foundry.bicep' = {
  name: 'aiFoundry'
  scope: resourceGroup
  params: {
    aiFoundryName: 'ais-${resourceSuffixKebabcase}'
  }
}

module aiFoundryProject './modules/foundry/ai-foundry-project.bicep' = {
  name: 'aiFoundryProject'
  scope: resourceGroup
  params: {
    aiFoundryName: aiFoundry.outputs.name
    aiProjectName: 'prj-${resourceSuffixKebabcase}'
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
}


output RESOURCE_GROUP string = resourceGroup.name
