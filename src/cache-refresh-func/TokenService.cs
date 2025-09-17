using Azure.Core;
using Azure.Identity;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace Func.RedisCache.Products;

public interface ITokenService
{
    Task<string> GetAccessTokenAsync();
}

public class TokenService : ITokenService
{
    private readonly TokenCredential _credential;
    private readonly string[] _scopes;

    public TokenService()
    {
        // Uses DefaultAzureCredential which automatically works with:
        // - Managed Identity (in production on Azure)
        // - Azure CLI (for local development)
        // - Environment variables
        // - Visual Studio / VS Code
        _credential = new DefaultAzureCredential();
        
        // Scope for the Azure Management API or your custom API
        // Adjust as needed
        _scopes = new[] { "https://management.azure.com/.default" };
    }

    public async Task<string> GetAccessTokenAsync()
    {
        try
        {
            var tokenRequestContext = new TokenRequestContext(_scopes);
            var token = await _credential.GetTokenAsync(tokenRequestContext, CancellationToken.None);
            return token.Token;
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException("Unable to obtain the Azure access token", ex);
        }
    }
}
