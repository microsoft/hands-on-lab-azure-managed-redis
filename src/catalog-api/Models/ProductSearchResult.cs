namespace CatalogApi.Models;

public class ProductSearchResult
{
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public float VectorScore { get; set; }
}