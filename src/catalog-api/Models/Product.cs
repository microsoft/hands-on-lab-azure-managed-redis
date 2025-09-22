using Microsoft.Extensions.VectorData;

namespace CatalogApi.Models;

public class Product
{
    [VectorStoreKey]
    public string Id { get; set; }

    [VectorStoreData(StorageName = "title")]
    public string? Title { get; set; }

    [VectorStoreData(StorageName = "description")]
    public string? Description { get; set; }

    [VectorStoreVector(1536, StorageName = "embedding")]
    public ReadOnlyMemory<float> Embedding { get; set; }
}