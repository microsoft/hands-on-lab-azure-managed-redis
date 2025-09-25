using CatalogApi.Models;
using CatalogApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace CatalogApi.Endpoints;

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

        app.MapPost("/ask", async ([FromBody] AskRequest request, IAIFoundryService aiFoundryService, IRedisService redisService) =>
        {
            var searchResults = await redisService.SearchProducts(request.Query);

            var chatCompletionAnswer = await aiFoundryService.GetChatCompletionsAsync(request.Query, searchResults);

            return Results.Ok(chatCompletionAnswer);
        });
    }
}