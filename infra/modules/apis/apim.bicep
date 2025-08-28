param name string
param location string = resourceGroup().location
param skuName string = 'Standardv2'
param tags object = {}

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: 'company@hol.io'
    publisherName: 'Hands On Lab Company'
  }  
}

output id string = apim.id
output name string = apim.name
output gatewayUrl string = apim.properties.gatewayUrl
