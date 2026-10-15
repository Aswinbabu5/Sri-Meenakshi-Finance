# Multi-stage Dockerfile for Sri Meenakshi Finance Backend API (.NET 10)
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy project files for layer caching
COPY backend/backend_for_loan_app.Domain/*.csproj backend/backend_for_loan_app.Domain/
COPY backend/backend_for_loan_app.Application/*.csproj backend/backend_for_loan_app.Application/
COPY backend/backend_for_loan_app.Infrastructure/*.csproj backend/backend_for_loan_app.Infrastructure/
COPY backend/backend_for_loan_app.API/*.csproj backend/backend_for_loan_app.API/

# Restore dependencies
RUN dotnet restore backend/backend_for_loan_app.API/backend_for_loan_app.API.csproj

# Copy all source files
COPY backend/ backend/

# Publish Release build
WORKDIR /src/backend/backend_for_loan_app.API
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

# Runtime Image
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .

# Expose port and default URLs for cloud environments (Render, Koyeb, Fly.io, etc.)
ENV ASPNETCORE_URLS=http://+:5000
ENV PORT=5000
EXPOSE 5000

ENTRYPOINT ["dotnet", "backend_for_loan_app.API.dll"]
