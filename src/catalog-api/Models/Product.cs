namespace CatalogApi.Models;

public class Product
{
    public required string Id { get; set; }

    public string? Title { get; set; }

    public string? Description { get; set; }
}