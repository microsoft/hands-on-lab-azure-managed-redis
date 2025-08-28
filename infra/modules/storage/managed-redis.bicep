param name string
param location string = resourceGroup().location
param skuName string = 'Balanced_B0'
param tags object = {}
param redisPort int = 10000

resource managedRedisEnterprise 'Microsoft.Cache/redisEnterprise@2025-05-01-preview' = {
  name: name
  location: location
  sku: {
    name: skuName
  }
  tags: tags
  identity: {
    type: 'None'
  }
  properties: {
    minimumTlsVersion: '1.2'
    highAvailability: 'Enabled'
  }
}

resource managedRedisEnterpriseDatabase 'Microsoft.Cache/redisEnterprise/databases@2025-05-01-preview' = {
  parent: managedRedisEnterprise
  name: 'default'
  properties: {
    clientProtocol: 'Encrypted'
    port: redisPort
    clusteringPolicy: 'EnterpriseCluster'
    evictionPolicy: 'NoEviction'
    modules: [
      {
        name: 'RedisBloom'
      }
      {
        name: 'RedisTimeSeries'
      }
      {
        name: 'RedisJSON'
      }
      {
        name: 'RediSearch'
      }
    ]
    persistence: {
      aofEnabled: false
      rdbEnabled: false
    }
    deferUpgrade: 'NotDeferred'
    accessKeysAuthentication: 'Enabled' // Required for APIM integration as of August 2025
  }
}

output id string = managedRedisEnterprise.id
output name string = managedRedisEnterprise.name
output databaseName string = managedRedisEnterpriseDatabase.name
output databaseResourceName string = '${managedRedisEnterprise.name}/${managedRedisEnterpriseDatabase.name}'
output endpoint string = '${managedRedisEnterprise.properties.hostName}:${redisPort}'
output hostName string = managedRedisEnterprise.properties.hostName
