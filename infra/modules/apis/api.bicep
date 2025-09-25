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

resource vectorizeOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: productsApi
  name: 'vectorize-data'
  properties: {
    displayName: 'Vectorize Data'
    method: 'POST'
    urlTemplate: '/vectorize'
    description: 'Vectorize your data.'
    request: {
      queryParameters: []
      headers: []
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// Create a POST operation to ask questions
resource askOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: productsApi
  name: 'ask-question'
  properties: {
    displayName: 'Ask Question'
    method: 'POST'
    urlTemplate: '/ask'
    description: 'Ask a question about your data.'
    request: {
      queryParameters: []
      headers: []
      representations: [
        {
          contentType: 'application/json'
          examples: {
            default: {
              value: {
                query: 'I am doing... can you help me?'
              }
              description: 'Example question'
            }
          }
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: [
          {
            contentType: 'application/json'
            examples: {
              default: {
                value: {
                  answer: 'Our return policy lasts 30 days.'
                }
                description: 'Example answer'
              }
            }
          }
        ]
      }
    ]
  }
}


resource getProductOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: productsApi
  name: 'get-product-by-id'
  properties: {
    displayName: 'Get Product by ID'
    method: 'GET'
    urlTemplate: '/products/{id}'
    description: 'Get a product by its ID.'
    templateParameters: [
      {
        name: 'id'
        description: 'The ID of the product to retrieve.'
        type: 'string'
        required: true
      }
    ]
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
