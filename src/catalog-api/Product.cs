using Microsoft.Extensions.VectorData;

public class Product
{
    [VectorStoreKey]
    public string Id { get; set; }

    [VectorStoreData(StorageName = "title")]
    public string? Title { get; set; }

    [VectorStoreData(StorageName = "description")]
    public string? Description { get; set; }

    // [VectorStoreData(StorageName = "image")]
    // public string? Image { get; set; }
    // [VectorStoreData(StorageName = "quantity")]
    // public int? Quantity { get; set; }
    // // Price in cents
    // [VectorStoreData(StorageName = "price")]
    // public int? Price { get; set; }
    [VectorStoreVector(1536, StorageName = "embedding")]
    public ReadOnlyMemory<float> Embedding { get; set; }
}