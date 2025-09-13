param apimName string
param serviceUrl string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
}

resource productsApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'products'
  properties: {
    displayName: 'Products'
    path: ''
    protocols: ['https']
    serviceUrl: serviceUrl
    subscriptionRequired: false
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
  }
}

resource getProductsOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: productsApi
  name: 'get-products'
  properties: {
    displayName: 'Get Products'
    method: 'GET'
    urlTemplate: '/products'
    description: 'Get products.'
    responses: [
      {
        statusCode: 200
        description: 'Success'
      }
    ]
  }
}

output apiId string = productsApi.id
output apiName string = productsApi.name
