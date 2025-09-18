using Microsoft.AspNetCore.Mvc;

public static class AIEndpoints
{
    public static void MapAIEndpoints(this WebApplication app)
    {
        app.MapGet("/vectorize", async (ICosmosService cosmosService, IRedisService redisService) =>
        {
            // Fetch data from Cosmos DB
            var products = await cosmosService.RetrieveAllProductsAsync();

            // Create an index and vectorize the products using Azure OpenAI
            await redisService.CreateProductsIndexAsync(products);

            return Results.Ok("Index created and products vectorized successfully.");
        });
        
        app.MapGet("/search", async (string query, IRedisService redisService) =>
        {
            // Perform a vector search using the provided query
            // This is a placeholder implementation; replace with actual search logic
            var searchResults = new List<string> { $"Search results for query: {query}" };

            return Results.Ok(searchResults);
        });
    }
}