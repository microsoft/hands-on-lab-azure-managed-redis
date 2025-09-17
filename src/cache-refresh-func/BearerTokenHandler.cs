using System;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace Func.RedisCache.Products;

public class BearerTokenHandler : DelegatingHandler
{
    private readonly ITokenService _tokenService;

    public BearerTokenHandler(ITokenService tokenService)
    {
        _tokenService = tokenService ?? throw new ArgumentNullException(nameof(tokenService));
    }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, 
        CancellationToken cancellationToken)
    {
        // Obtenir le token d'accès à la volée pour chaque requête
        var accessToken = await _tokenService.GetAccessTokenAsync();
        
        // Ajouter le header Authorization avec le token Bearer
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);

        return await base.SendAsync(request, cancellationToken);
    }
}
