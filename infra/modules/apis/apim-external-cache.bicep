
// As of August 2025, the API Management service supports integration with Azure Cache for Redis as an external cache via Connection String / Access Key only.
// It means we need to enable the Access Keys Authentication on Redis to allow this integration.
// https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-cache-external#prerequisites

param apimName string
param cacheResourceName string
param cacheResourceEndpoint string
param cacheLocation string = 'default'

resource cacheDatabase 'Microsoft.Cache/redisEnterprise/databases@2025-05-01-preview' existing = {
  name: cacheResourceName
}

var cacheResourceAccessKey string = cacheDatabase.listKeys().primaryKey


resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

resource apimcache 'Microsoft.ApiManagement/service/caches@2024-10-01-preview' = {
  parent: apim
  name: cacheDatabase.name
  properties: {
    connectionString: '${cacheResourceEndpoint},password=${cacheResourceAccessKey},ssl=True,abortConnect=False'
    description: 'External Cache used as a Default Cache for the API Management instance regions.'
    resourceId: cacheDatabase.id
    useFromLocation: cacheLocation
  }
}
