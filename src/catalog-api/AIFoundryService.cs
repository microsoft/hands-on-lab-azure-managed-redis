using Azure.AI.OpenAI;
using Azure.AI.Projects;
using Azure.Identity;
using OpenAI.Chat;
using OpenAI.Embeddings;

public interface IAIFoundryService
{
    EmbeddingClient GetAzureOpenAIEmbeddingClient();
    ChatClient GetAzureOpenAIChatClient();
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
}