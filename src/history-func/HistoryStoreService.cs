using System;
using System.Text.Json;
using Azure.Identity;
using Microsoft.Azure.StackExchangeRedis;
using StackExchange.Redis;

namespace History.Api
{
    public interface IHistoryStoreService {
        Task<IEnumerable<ProductView>> GetHistory(string userId);
        Task AddToHistory(string userId, ProductView productView);
    }

    public class HistoryStoreService : IHistoryStoreService
    { 
        private IDatabase? _database = null;
        private readonly int _maxListSize = 10;
        private readonly string _redisEndpoint = Environment.GetEnvironmentVariable("AZURE_REDIS_ENDPOINT");

        private async Task<IDatabase> GetDatabaseAsync() {
            if (_database != null) {
                return _database;
            }

            Console.WriteLine("Initializing Redis database connection");

            var configurationOptions = await ConfigurationOptions.Parse(_redisEndpoint).ConfigureForAzureWithTokenCredentialAsync(new DefaultAzureCredential());
            var connectionMultiplexer = await ConnectionMultiplexer.ConnectAsync(configurationOptions);

            _database = connectionMultiplexer.GetDatabase();

            Console.WriteLine("Redis database connection established");

            return _database;
        }

        private string UserHistoryKey(string userId) => $"history:{userId}";

        public async Task<IEnumerable<ProductView>> GetHistory(string userId)
        {
            string key = UserHistoryKey(userId);
            var database = await GetDatabaseAsync();
            var list = await database.ListRangeAsync(key, 0, -1);

            if (list == null) {
                return Enumerable.Empty<ProductView>();
            }

            var productViews = list.Select(item => JsonSerializer.Deserialize<ProductView>(item.ToString()));
            return productViews;
        }

        public async Task AddToHistory(string userId, ProductView productView)
        {
            string key = UserHistoryKey(userId);
            string productViewJson = JsonSerializer.Serialize<ProductView>(productView);
            var database = await GetDatabaseAsync();

            await database.ListLeftPushAsync(key, productViewJson);
            await database.ListTrimAsync(key, 0, _maxListSize - 1);
        }
    }
}