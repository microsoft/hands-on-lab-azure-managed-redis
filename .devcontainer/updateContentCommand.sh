#!/bin/sh 

# Prepare functions assets
dotnet restore src/cache-refresh-func/CacheRefresh.Func.csproj
dotnet restore src/history-func/History.Api.csproj

# Make hook script executable
chmod +x infra/hook.sh

# Prepare catalog-api assets
cd src/catalog-api 
dotnet restore && dotnet dev-certs https --trust

