using Azure.AI.OpenAI;
using Azure.AI.Projects;
using Azure.Identity;
using OpenAI.Embeddings;

public interface IAIFoundryService
{
    EmbeddingClient GetAzureOpenAIEmbeddingClient();
}

public class AIFoundryService : IAIFoundryService
{
    private AzureOpenAIClient? _azureOpenAIClient = null;
    private readonly string? aiFoundryProjectUrl;
    private readonly string? embeddingDeploymentName;

    public AIFoundryService(IConfiguration configuration)
    {
        aiFoundryProjectUrl = configuration["AI_FOUNDRY_PROJECT_URL"];
        embeddingDeploymentName = configuration["EMBEDDING_DEPLOYMENT_NAME"];
    }

    public EmbeddingClient GetAzureOpenAIEmbeddingClient()
    {
        var projectClient = new AIProjectClient(new Uri(aiFoundryProjectUrl), new DefaultAzureCredential());

        AzureOpenAIClient azureOpenAIClient = (AzureOpenAIClient)projectClient.GetOpenAIClient();
        var embeddingClient = azureOpenAIClient.GetEmbeddingClient(deploymentName: embeddingDeploymentName);

        return embeddingClient;
    }
}