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
    Task<List<string>> SearchProducts(string query);
}

public class RedisService : IRedisService
{
    private IDatabase? _database = null;
    private readonly string? _endpoint;

    private readonly IAIFoundryService _aiFoundryService;

    private readonly int _defaultTTLInSeconds = 60;
    private readonly TimeSpan _ttl; // Time To Live

    private readonly string _productsIndexName = "products_index";

    public RedisService(IConfiguration configuration, IAIFoundryService aiFoundryService)
    {
        _aiFoundryService = aiFoundryService;
        _ttl = TTL(configuration["AZURE_REDIS_TTL_IN_SECONDS"]);
        _endpoint = configuration["AZURE_REDIS_ENDPOINT"];
    }

    /// Asynchronously retrieves or establishes a connection to the Redis database.
    /// </summary>
    /// <returns>
    /// A <see cref="Task{IDatabase}"/> representing the asynchronous operation, 
    /// containing the Redis database instance.
    /// </returns>
    /// <remarks>
    /// This method implements lazy initialization of the Redis connection. 
    /// If a database connection already exists, it returns the cached instance.
    /// Otherwise, it creates a new connection using Azure Managed Identity authentication
    /// via <see cref="DefaultAzureCredential"/> and caches it for subsequent calls.
    /// </remarks>
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

    /// <summary>
    /// Determines the Time To Live (TTL) for cache entries based on the provided string input.
    /// </summary>
    /// <param name="ttlInSecondsAsString">A string representing the desired TTL in seconds.</param>
    /// <returns>A <see cref="TimeSpan"/> representing the TTL duration.</returns>
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

    /// <summary>
    /// Retrieves a value from Redis by its key.
    /// </summary>
    /// <param name="key">The key of the value to retrieve.</param>
    /// <returns>A <see cref="Task{String}"/> representing the asynchronous operation, 
    /// containing the value associated with the specified key, or null if not found or on error.</returns>
    /// <remarks>
    /// This method attempts to fetch the value associated with the provided key from the Redis database.
    /// If the key does not exist or an error occurs during retrieval, it returns null.
    /// </remarks>
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

    /// <summary>
    /// Sets a value in Redis with the specified key and a predefined Time To Live (TTL).
    /// </summary>
    /// <param name="key">The key under which the value will be stored.</param>
    /// <param name="value">The value to be stored in Redis.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    /// <remarks>
    /// This method stores the provided value in the Redis database under the specified key.
    /// The entry will expire after the duration defined by the TTL property.
    /// </remarks>
    public async Task Set(string key, string value)
    {
        var database = await GetDatabaseAsync();
        await database.StringSetAsync(key, value, _ttl);
    }

    /// <summary>
    /// Adds an entry to a Redis stream with the specified name and data.
    /// </summary>
    /// <param name="streamName">The name of the Redis stream.</param>
    /// <param name="data">A dictionary containing the data to be added to the stream.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    /// <remarks>
    /// This method constructs a list of name-value pairs from the provided dictionary
    /// and adds them as a new entry to the specified Redis stream.
    /// </remarks>
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

    /// <summary>
    /// Converts an OpenAI embedding response to a byte array representation.
    /// </summary>
    /// <param name="embeddingResponse">The client result containing the OpenAI embedding.</param>
    /// <returns>A byte array containing the binary representation of the embedding floats.</returns>
    /// <remarks>
    /// This method extracts the float array from the embedding response and converts it to a byte array
    /// suitable for storage in Redis. Each float (4 bytes) in the embedding is converted to its byte representation.
    /// </remarks>
    private static byte[] EmbeddingToByteArray(System.ClientModel.ClientResult<OpenAIEmbedding> embeddingResponse)
    {
        var embedding = embeddingResponse.Value.ToFloats().ToArray();

        // Convert embedding to bytes for Redis
        var embeddingBytes = new byte[embedding.Length * 4];
        Buffer.BlockCopy(embedding, 0, embeddingBytes, 0, embeddingBytes.Length);
        return embeddingBytes;
    }

    /// <summary>
    /// Creates a vector index in Redis for the provided collection of products.
    /// </summary>
    /// <param name="products">An enumerable collection of products to be indexed.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    /// <remarks>
    /// This method creates a vector index in Redis using the provided products. It first checks if
    /// an index with the specified name already exists and drops it if found. Then, it creates a new index
    /// with the defined schema and populates it with the product data, including generating embeddings for each product
    /// using the Azure OpenAI embedding client.
    /// </remarks>
    public async Task CreateProductsIndex(IEnumerable<Product> products)
    {
        try
        {
            var database = await GetDatabaseAsync();

            // Check if the index already exists
            var existingIndexes = await database.ExecuteAsync("FT._LIST");
            var indexes = (string[])existingIndexes;

            // Drop the index if it exists
            if (indexes.Contains(_productsIndexName))
            {
                Console.WriteLine("Dropping existing Redis Vector Store index...");
                await database.ExecuteAsync("FT.DROPINDEX", _productsIndexName);
            }

            Console.WriteLine("Creating Redis Vector Store index...");

            // Create the index with vector field
            await database.ExecuteAsync("FT.CREATE", _productsIndexName,
                "ON", "HASH",
                "PREFIX", "1", "product_vector:",
                "SCHEMA",
                "title", "TEXT", "SORTABLE",
                "description", "TEXT",
                "embedding", "VECTOR", "FLAT", "6", "TYPE", "FLOAT32", "DIM", "1536", "DISTANCE_METRIC", "COSINE");

            var embeddingClient = _aiFoundryService.GetAzureOpenAIEmbeddingClient();

            foreach (var product in products)
            {
                // Text to generate embedding for
                var textToEmbed = $"{product.Title} - {product.Description}";

                // Generate embedding
                var embeddingResponse = await embeddingClient.GenerateEmbeddingAsync(textToEmbed);
                byte[] embeddingBytes = EmbeddingToByteArray(embeddingResponse);

                var key = $"product_vector:{product.Id}";
                var hash = new HashEntry[]
                {
                        new("title", product.Title),
                        new("description", product.Description),
                        new("embedding", embeddingBytes)
                };

                await database!.HashSetAsync(key, hash);
            }
        }
        catch (Exception ex)
        {
            throw new Exception("Error occurred while creating the vector index", ex);
        }
    }

    /// <summary>
    /// Searches for products in the Redis vector index that are similar to the provided query.
    /// </summary>
    /// <param name="query">The search query string.</param>
    /// <returns>A <see cref="Task{String}"/> representing the asynchronous operation,
    /// containing the search results as a string.</returns>
    /// <remarks>
    /// This method performs a vector search in the Redis index using the provided query. It generates
    /// an embedding for the query using the Azure OpenAI embedding client and then executes a KNN search
    /// to find the most similar products based on their embeddings. The results include the titles and descriptions
    /// of the top matching products.
    /// </remarks>
    public async Task<List<string>> SearchProducts(string query)
    {
        try
        {
            var database = await GetDatabaseAsync();
            var embeddingClient = _aiFoundryService.GetAzureOpenAIEmbeddingClient();

            // Generate embedding for the query
            var queryEmbeddingResponse = await embeddingClient.GenerateEmbeddingAsync(query);
            byte[] queryEmbeddingBytes = EmbeddingToByteArray(queryEmbeddingResponse);

            // Perform vector search using KNN
            var searchResult = await database.ExecuteAsync("FT.SEARCH", _productsIndexName,
                "(*)=>[KNN 10 @embedding $query_vec AS vector_score]",
                "PARAMS", "2", "query_vec", queryEmbeddingBytes,
                "SORTBY", "vector_score", "ASC",
                "RETURN", "3", "title", "description", "vector_score",
                "DIALECT", "2");  // Use the vector search feature since version two of the query dialect.

            // Process and format the search results
            var resultArray = (RedisResult[])searchResult;
            int totalResults = (int)resultArray[0];
            List<string> results = new();
            for (int i = 1; i < resultArray.Length; i += 2)
            {
                var fields = (RedisResult[])resultArray[i + 1];
                string title = string.Empty;
                string description = string.Empty;
                string vectorScore = string.Empty;

                for (int j = 0; j < fields.Length; j += 2)
                {
                    string fieldName = (string)fields[j];
                    string fieldValue = (string)fields[j + 1];

                    if (fieldName == "title")
                    {
                        title = fieldValue;
                    }
                    else if (fieldName == "description")
                    {
                        description = fieldValue;
                    }
                    else if (fieldName == "vector_score")
                    {
                        vectorScore = (1.0f - float.Parse(fieldValue)).ToString("F4");
                    }
                }

                results.Add($"Title: {title}\nDescription: {description}");
                Console.WriteLine($"Title: {title}\nDescription: {description}\nVector Score: {vectorScore}\n");
            }

            return results;
        }
        catch (Exception ex)
        {
            throw new Exception("Error occurred while performing vector search", ex);
        }
    }
}