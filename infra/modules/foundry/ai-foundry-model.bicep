param aiFoundryName string
param modelName string
param modelCapacity int
param modelVersion string

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: aiFoundryName
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01'= {
  parent: aiFoundry
  name: modelName
  sku : {
    capacity: modelCapacity
    name: 'GlobalStandard'
  }
  properties: {
    model:{
      name: modelName
      format: 'OpenAI'
      version: modelVersion
    }
  }
}
