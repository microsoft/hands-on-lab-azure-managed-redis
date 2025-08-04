param cosmosDbAccountName string
param managedRedisDatabaseName string
param historyFunctionPrincipalId string
param cacheFunctionPrincipalId string
param appServicePrincipalId string

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosDbAccountName
}

resource cosmosDbDataContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: cosmosDbAccount
  name: '00000000-0000-0000-0000-000000000002'
  properties: {
    roleName: 'Cosmos DB Built-in Data Contributor'
    type: 'BuiltInRole'
    assignableScopes: [
      cosmosDbAccount.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]
        notDataActions: []
      }
    ]
  }
}

resource appServiceCosmosDbContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: cosmosDbAccount
  name: guid(cosmosDbAccount.id, cosmosDbDataContributor.id, appServicePrincipalId)
  properties: {
    roleDefinitionId: cosmosDbDataContributor.id
    principalId: appServicePrincipalId
    scope: cosmosDbAccount.id
  }
}

resource managedRedisDatabase 'Microsoft.Cache/redisEnterprise/databases@2025-05-01-preview' existing = {
  name: managedRedisDatabaseName
}

resource historyFunctionRedisEnterpriseDefaultRole 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-05-01-preview' = {
  parent: managedRedisDatabase
  name: historyFunctionPrincipalId
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: historyFunctionPrincipalId
    }
  }
}

resource cacheFunctionRedisEnterpriseDefaultRole 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-05-01-preview' = {
  parent: managedRedisDatabase
  name: cacheFunctionPrincipalId
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: cacheFunctionPrincipalId
    }
  }
  dependsOn: [managedRedisDatabase]
}
