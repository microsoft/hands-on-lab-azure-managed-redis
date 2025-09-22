using Azure.AI.OpenAI;
using Azure.AI.Projects;
using Azure.Identity;
using CatalogApi.Models;
using OpenAI.Chat;
using OpenAI.Embeddings;

namespace CatalogApi.Services;

public interface IAIFoundryService
{
    EmbeddingClient GetAzureOpenAIEmbeddingClient();
    ChatClient GetAzureOpenAIChatClient();
    Task<ChatCompletion> GetChatCompletionsAsync(string query, List<ProductSearchResult> rag);
}

public class AIFoundryService : IAIFoundryService
{
    private readonly string? _aiFoundryProjectUrl;
    private readonly string? _embeddingDeploymentName;
    private readonly string? _chatDeploymentName;

    public AIFoundryService(IConfiguration configuration)
    {
        _aiFoundryProjectUrl = configuration["AI_FOUNDRY_PROJECT_URL"] ?? throw new ArgumentNullException("AI_FOUNDRY_PROJECT_URL is not set in configuration");
        _embeddingDeploymentName = configuration["EMBEDDING_DEPLOYMENT_NAME"] ?? throw new ArgumentNullException("EMBEDDING_DEPLOYMENT_NAME is not set in configuration");
        _chatDeploymentName = configuration["CHAT_DEPLOYMENT_NAME"] ?? throw new ArgumentNullException("CHAT_DEPLOYMENT_NAME is not set in configuration");
    }

    public EmbeddingClient GetAzureOpenAIEmbeddingClient()
    {
        var projectClient = new AIProjectClient(new Uri(_aiFoundryProjectUrl ?? ""), new DefaultAzureCredential());

        AzureOpenAIClient azureOpenAIClient = (AzureOpenAIClient)projectClient.GetOpenAIClient();
        var embeddingClient = azureOpenAIClient.GetEmbeddingClient(deploymentName: _embeddingDeploymentName);

        return embeddingClient;
    }

    public ChatClient GetAzureOpenAIChatClient()
    {
        var projectClient = new AIProjectClient(new Uri(_aiFoundryProjectUrl ?? ""), new DefaultAzureCredential());

        AzureOpenAIClient azureOpenAIClient = (AzureOpenAIClient)projectClient.GetOpenAIClient();
        var chatClient = azureOpenAIClient.GetChatClient(deploymentName: _chatDeploymentName);

        return chatClient;
    }

    public async Task<ChatCompletion> GetChatCompletionsAsync(string query, List<ProductSearchResult> rag)
    {
        var chatClient = GetAzureOpenAIChatClient();
        var context = string.Join("\n", rag.Select((s, i) => $"{i + 1}. {s.Title} : {s.Description}"));
        var messages = new List<ChatMessage>
        {
            new SystemChatMessage($"""
                context : {context}
                Answer the question based on the context above only. Provide the product name associated with the answer as well. If the
                information to answer the question is not present in the given context then reply "I don't know".
                Query: {query}
            """),
        };

        var response = await chatClient.CompleteChatAsync(messages);
        return response;
    }
}