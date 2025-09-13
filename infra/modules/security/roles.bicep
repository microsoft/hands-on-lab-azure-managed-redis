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

// Add explicit dependencies and conditions for Redis access policy assignments
resource historyFunctionUAMIRedisEnterpriseDefaultRole 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-05-01-preview' = if (!empty(historyFunctionUamiPrincipalId)) {
  parent: managedRedisDatabase
  name: guid('historyFunctionUAMI', historyFunctionUamiPrincipalId, managedRedisDatabase.id)
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: historyFunctionUamiPrincipalId
    }
  }
}

// TODO: should we refactor the code and just keep a single identity per function to access AMR ?
resource historyFunctionRedisEnterpriseDefaultRole 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-05-01-preview' = if (!empty(historyFunctionPrincipalId)) {
  parent: managedRedisDatabase
  name: guid('historyFunction', historyFunctionPrincipalId, managedRedisDatabase.id)
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: historyFunctionPrincipalId
    }
  }
  dependsOn: [
    historyFunctionUAMIRedisEnterpriseDefaultRole
  ]
}

resource cacheFunctionRedisEnterpriseDefaultRole 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-05-01-preview' = if (!empty(cacheFunctionUamiPrincipalId)) {
  parent: managedRedisDatabase
  name: guid('cacheFunction', cacheFunctionUamiPrincipalId, managedRedisDatabase.id)
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: cacheFunctionUamiPrincipalId
    }
  }
  dependsOn: [
    historyFunctionRedisEnterpriseDefaultRole
  ]
}

resource catalogApiRedisEnterpriseDefaultRole 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-05-01-preview' = if (!empty(appServicePrincipalId)) {
  parent: managedRedisDatabase
  name: guid('catalogApi', appServicePrincipalId, managedRedisDatabase.id)
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: appServicePrincipalId
    }
  }
  dependsOn: [
    cacheFunctionRedisEnterpriseDefaultRole
  ]
}

resource currentuserDefaultRole 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-05-01-preview' = if (!empty(currentUserObjectId)) {
  parent: managedRedisDatabase
  name: guid('currentUser', currentUserObjectId, managedRedisDatabase.id)
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: currentUserObjectId
    }
  }
  dependsOn: [
    catalogApiRedisEnterpriseDefaultRole
  ]
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
