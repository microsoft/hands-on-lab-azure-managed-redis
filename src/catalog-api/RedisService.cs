using Azure.Identity;
using Microsoft.SemanticKernel.Connectors.Redis;
using OpenAI.Embeddings;
using StackExchange.Redis;

public interface IRedisService
{
    Task<string?> Get(string key);
    Task Set(string key, string value);
    Task AddToStream(string streamName, Dictionary<string, string?> data);
    Task CreateProductsIndex(IEnumerable<Product> products);
    Task<string> SearchProducts(string input);
}

public class RedisService : IRedisService
{
    private IDatabase? _database = null;
    private readonly string? _endpoint;

    private readonly IAIFoundryService _aiFoundryService;

    private readonly int _defaultTTLInSeconds = 60;
    private readonly TimeSpan _ttl; // Time To Live

    private readonly string _productsCollectionName = "Products-collection";

    public RedisService(IConfiguration configuration, IAIFoundryService aiFoundryService)
    {
        _aiFoundryService = aiFoundryService;
        _ttl = TTL(configuration["AZURE_REDIS_TTL_IN_SECONDS"]);
        _endpoint = configuration["AZURE_REDIS_ENDPOINT"];
    }

    private async Task<IDatabase> GetDatabaseAsync()
    {
        if (_database != null)
        {
            return _database;
        }

        Console.WriteLine("Initializing Redis database connection");

        var configurationOptions = await ConfigurationOptions.Parse(_endpoint).ConfigureForAzureWithTokenCredentialAsync(new DefaultAzureCredential());
        var connectionMultiplexer = await ConnectionMultiplexer.ConnectAsync(configurationOptions);

        _database = connectionMultiplexer.GetDatabase();

        Console.WriteLine("Redis database connection established");

        return _database;
    }

    private TimeSpan TTL(string? ttlInSecondsAsString)
    {
        int ttlInSeconds;

        try
        {
            ttlInSeconds = string.IsNullOrEmpty(ttlInSecondsAsString) ? _defaultTTLInSeconds : int.Parse(ttlInSecondsAsString);
        }
        catch
        {
            ttlInSeconds = _defaultTTLInSeconds;
        }

        if (ttlInSeconds <= 0)
        {
            ttlInSeconds = _defaultTTLInSeconds;
        }

        return TimeSpan.FromSeconds(ttlInSeconds);
    }

    public async Task<string?> Get(string key)
    {
        try
        {
            var database = await GetDatabaseAsync();
            var value = await database.StringGetAsync(key);
            var stringValue = value.ToString();

            if (stringValue == string.Empty)
            {
                return null;
            }

            return stringValue;
        }
        catch
        {
            return null;
        }
    }

    public async Task Set(string key, string value)
    {
        var database = await GetDatabaseAsync();
        await database.StringSetAsync(key, value, _ttl);
    }

    public async Task AddToStream(string streamName, Dictionary<string, string?> data)
    {
        List<NameValueEntry> entries = new();

        foreach (KeyValuePair<string, string?> keyValuePair in data)
        {
            entries.Add(new(keyValuePair.Key, keyValuePair.Value));
        }

        var database = await GetDatabaseAsync();
        await database.StreamAddAsync(streamName, entries.ToArray());
    }

    private async Task<RedisVectorStore> GetRedisVectorStore()
    {
        var database = await GetDatabaseAsync();

        var vectorStore = new RedisVectorStore(
            database,
            new() { StorageType = RedisStorageType.HashSet });

        return vectorStore;
    }

    public async Task CreateProductsIndex(IEnumerable<Product> products)
    {
        var embeddingClient = _aiFoundryService.GetAzureOpenAIEmbeddingClient();

        Console.WriteLine("Creating Redis Vector Store index...");

        var vectorStore = await GetRedisVectorStore();

        // Connect to a collection using the VectorStore abstraction.
        var collection = vectorStore.GetCollection<string, Product>(_productsCollectionName);

        // Create the collection if it doesn't exist.
        await collection.EnsureCollectionExistsAsync();

        var tasks = products.Select(product => Task.Run(async () =>
        {
            product.Embedding = (await embeddingClient.GenerateEmbeddingAsync(product.Description)).Value.ToFloats();
        }));
        await Task.WhenAll(tasks);

        await collection.UpsertAsync(products);
    }

    public async Task<string> SearchProducts(string input)
    {
        var embeddingClient = _aiFoundryService.GetAzureOpenAIEmbeddingClient();
        var searchVector = (await embeddingClient.GenerateEmbeddingAsync(input)).Value.ToFloats();

        var vectorStore = await GetRedisVectorStore();
        var collection = vectorStore.GetCollection<string, Product>(_productsCollectionName);
        var resultRecords = await collection.SearchAsync(searchVector, top: 1).ToListAsync();

        Console.WriteLine("Search string: " + input);

        return resultRecords?.FirstOrDefault()?.Record?.Description ?? "Description non disponible";
    }
}

static class HelperExtensions
{
    public static async ValueTask<List<T>> ToListAsync<T>(this IAsyncEnumerable<T> source, CancellationToken cancellationToken = default)
    {
        var result = new List<T>();

        await foreach (var item in source.WithCancellation(cancellationToken).ConfigureAwait(false))
        {
            result.Add(item);
        }

        return result;
    }
}
