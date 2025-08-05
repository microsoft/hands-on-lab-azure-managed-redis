```csharp
using Microsoft.Extensions.Logging;
using StackExchange.Redis;
using Microsoft.Azure.Functions.Worker.Redis;

namespace Microsoft.Azure.Functions.Worker.Redis.Samples
{
    public static class SampleRedisSamples
    {   
        private readonly ILogger _logger;

        public RefreshRedisCache(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<RefreshRedisCache>();
        }

        [Description("This function will be triggered when a message is published to the pubsubTest channel.")]
        [Function("PubSubTrigger")]
        public static void PubSubTrigger(
            [RedisPubSubTrigger("AZURE_REDIS_CONNECTION", "PubSubChannelSample")] string message)
        {
            _logger.LogInformation(message);
        }

        [Description("This function will be triggered when a message is published to the KeySpaceTest key.")]
        [Function("KeyspaceTrigger")]
        public static void KeyspaceTrigger(
            [RedisPubSubTrigger("AZURE_REDIS_CONNECTION", "__keyspace@0__:KeySample")] string message)
        {
            _logger.LogInformation(message);

        }

        [Description("This function will be triggered when the DEL command is being executed")]
        [Function("KeyeventTrigger")]
        public static void KeyeventTrigger(
            [RedisPubSubTrigger("AZURE_REDIS_CONNECTION", "__keyevent@0__:expired")] string message)
        {
            _logger.LogInformation(message);
        }

        [Description("This function will be triggered when a change is being made to the listTest list.")]
        [Function("ListTrigger")]
        public static void ListTrigger(
            [RedisListTrigger("AZURE_REDIS_CONNECTION", "SampleList")] string entry)
        {
            _logger.LogInformation(entry);
        }

        [Description("This function will be triggered when a change is being made to the StreamTest Stream.")]
        [Function("StreamTrigger")]
        public static void StreamTrigger(
            [RedisStreamTrigger("AZURE_REDIS_CONNECTION", "SampleStream")] string entry)
        {
            _logger.LogInformation(entry);
        }
    }
}
```