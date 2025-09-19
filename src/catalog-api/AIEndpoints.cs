using Microsoft.AspNetCore.Mvc;

public static class AIEndpoints
{
    public static void MapAIEndpoints(this WebApplication app)
    {
        app.MapPost("/vectorize", async (ICosmosService cosmosService, IRedisService redisService) =>
        {
            // Fetch data from Cosmos DB
            var products = await cosmosService.RetrieveAllProductsAsync();

            // Create an index and vectorize the products using Azure OpenAI
            await redisService.CreateProductsIndex(products);

            return Results.Created();
        });
        
        app.MapPost("/ask", async ([FromBody] AskRequest request, IRedisService redisService) =>
        {
            var searchResults = await redisService.SearchProducts(request.Input);

            return Results.Ok(searchResults);
        });
    }
}