param cosmosDbAccountName string
param managedRedisDatabaseName string
param historyFunctionUamiPrincipalId string
param historyFunctionPrincipalId string
param cacheFunctionUamiPrincipalId string
param cacheFunctionPrincipalId string
param appServicePrincipalId string
param appInsightsName string
param currentUserObjectId string

// https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/monitor#monitoring-metrics-publisher
var metricsPublisherRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb')

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

resource currentUserDbContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: cosmosDbAccount
  name: guid(cosmosDbAccount.id, cosmosDbDataContributor.id, currentUserObjectId)
  properties: {
    roleDefinitionId: cosmosDbDataContributor.id
    principalId: currentUserObjectId
    scope: cosmosDbAccount.id
  }
}

resource managedRedisDatabase 'Microsoft.Cache/redisEnterprise/databases@2025-05-01-preview' existing = {
  name: managedRedisDatabaseName
}

resource historyFunctionUAMIRedisEnterpriseDefaultRole 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-05-01-preview' = {
  parent: managedRedisDatabase
  name: historyFunctionUamiPrincipalId
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: historyFunctionUamiPrincipalId
    }
  }
}

// TODO: should we refactor the code and just keep a single identity per function to access AMR ?
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
  name: cacheFunctionUamiPrincipalId
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: cacheFunctionUamiPrincipalId
    }
  }
  dependsOn: [managedRedisDatabase]
}

resource catalogApiRedisEnterpriseDefaultRole 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-05-01-preview' = {
  parent: managedRedisDatabase
  name: appServicePrincipalId
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: appServicePrincipalId
    }
  }
  dependsOn: [managedRedisDatabase]
}

resource currentuserDefaultRole 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-05-01-preview' = {
  parent: managedRedisDatabase
  name: currentUserObjectId
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: currentUserObjectId
    }
  }
  dependsOn: [managedRedisDatabase]
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource monitoringMetricsPublisherFuncStdAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(appInsights.id, appServicePrincipalId, metricsPublisherRoleId)
  scope: appInsights
  properties: {
    roleDefinitionId: metricsPublisherRoleId
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource monitoringMetricsPublisherHistoryFunctionAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(appInsights.id, historyFunctionPrincipalId, metricsPublisherRoleId)
  scope: appInsights
  properties: {
    roleDefinitionId: metricsPublisherRoleId
    principalId: historyFunctionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource monitoringMetricsPublisherCacheFunctionAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(appInsights.id, cacheFunctionPrincipalId, metricsPublisherRoleId)
  scope: appInsights
  properties: {
    roleDefinitionId: metricsPublisherRoleId
    principalId: cacheFunctionPrincipalId
    principalType: 'ServicePrincipal'
  }
}
