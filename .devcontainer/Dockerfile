FROM mcr.microsoft.com/devcontainers/dotnet:8.0-bookworm

RUN sudo apt-get update 

## Required to execute redis-cli commands
# TODO: Clean if not possible to redis-cli via MSEntra ID
RUN su vscode -c "umask 0002 && sudo apt-get install redis -y 2>&1"

# TODO: Check if still required as benchmark will be replaced by Azure Load Testing
## Install Redis client toolings
RUN su vscode -c "umask 0002 && sudo apt-get install redis-tools -y 2>&1"

## Install the curl client
RUN su vscode -c "sudo apt-get install curl"