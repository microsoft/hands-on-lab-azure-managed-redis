param aiFoundryName string
param location string = resourceGroup().location

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: aiFoundryName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    // required to work in AI Foundry
    allowProjectManagement: true 

    // Defines developer API endpoint subdomain
    customSubDomainName: aiFoundryName

    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

output name string = aiFoundry.name
output endpoint string = aiFoundry.properties.endpoint
