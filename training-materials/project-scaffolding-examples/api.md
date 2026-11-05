# API examples (.NET minimal API + xUnit v3)

Copied code from the project-scaffolding template, as proven on 2026-10-23. The template itself records the decisions and rules; these are full example files for reference. `<Solution>` is the solution name in dotted PascalCase, and `<solution>` is the same name lowercased. The sample entity is `DanceType`. Rename it to fit the product, and keep the shape.

## Latest stable NuGet versions (PowerShell)

```powershell
foreach ($p in 'Microsoft.AspNetCore.OpenApi','Scalar.AspNetCore','Microsoft.AspNetCore.Mvc.Testing','Shouldly','xunit.v3') {
  $d = dotnet package search $p --exact-match --format json | Out-String | ConvertFrom-Json
  $v = $d.searchResult | % { $_.packages } | % { $_.version } | ? { $_ -notmatch '-' }
  "$p : $($v | Select-Object -Last 1)"
}
```

## `global.json`

```json
{
  "sdk": {
    "version": "10.0.400",
    "rollForward": "latestFeature"
  },
  "test": {
    "runner": "Microsoft.Testing.Platform"
  }
}
```

## `Directory.Build.props`

```xml
<Project>

  <!-- Shared settings for every .NET project in the repository -->
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

</Project>
```

## `Directory.Packages.props`

```xml
<Project>

  <!-- Central package management: versions live here, projects reference packages without a version -->
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>

  <ItemGroup Label="API">
    <PackageVersion Include="Microsoft.AspNetCore.OpenApi" Version="10.0.13" />
    <PackageVersion Include="Scalar.AspNetCore" Version="2.18.3" />
  </ItemGroup>

  <ItemGroup Label="Tests">
    <PackageVersion Include="Microsoft.AspNetCore.Mvc.Testing" Version="10.0.13" />
    <PackageVersion Include="Shouldly" Version="4.3.0" />
    <PackageVersion Include="xunit.v3" Version="4.0.2" />
  </ItemGroup>

</Project>
```

## `.editorconfig`

```ini
root = true

# Scoped to .NET files so the UI keeps its own tooling defaults

[*.cs]
charset = utf-8
indent_style = space
indent_size = 4
insert_final_newline = true
trim_trailing_whitespace = true

# Layout
csharp_new_line_before_open_brace = all
csharp_new_line_before_else = true
csharp_new_line_before_catch = true
csharp_new_line_before_finally = true
csharp_style_namespace_declarations = file_scoped:warning
csharp_prefer_braces = true:suggestion
dotnet_sort_system_directives_first = false

# Private static readonly fields are PascalCase, e.g. DanceTypes
dotnet_naming_rule.private_static_readonly_fields_pascal.symbols = private_static_readonly_fields
dotnet_naming_rule.private_static_readonly_fields_pascal.style = pascal_case
dotnet_naming_rule.private_static_readonly_fields_pascal.severity = suggestion
dotnet_naming_symbols.private_static_readonly_fields.applicable_kinds = field
dotnet_naming_symbols.private_static_readonly_fields.applicable_accessibilities = private
dotnet_naming_symbols.private_static_readonly_fields.required_modifiers = static, readonly

# Other private fields are _camelCase, e.g. _logger
dotnet_naming_rule.private_fields_underscore.symbols = private_fields
dotnet_naming_rule.private_fields_underscore.style = underscore_camel_case
dotnet_naming_rule.private_fields_underscore.severity = suggestion
dotnet_naming_symbols.private_fields.applicable_kinds = field
dotnet_naming_symbols.private_fields.applicable_accessibilities = private

dotnet_naming_style.pascal_case.capitalization = pascal_case
dotnet_naming_style.underscore_camel_case.capitalization = camel_case
dotnet_naming_style.underscore_camel_case.required_prefix = _

[*.{csproj,props,targets,slnx}]
indent_style = space
indent_size = 2
```

## `<Solution>.API.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <InvariantGlobalization>true</InvariantGlobalization>
  </PropertyGroup>

  <!-- Local overrides are read from the project folder by dotnet run, never shipped -->
  <ItemGroup>
    <Content Update="appsettings.Local.json" CopyToOutputDirectory="Never" CopyToPublishDirectory="Never" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" />
    <PackageReference Include="Scalar.AspNetCore" />
  </ItemGroup>

</Project>
```

## `Program.cs`

```csharp
using System.Runtime.CompilerServices;
using Scalar.AspNetCore;
using <Solution>.API;
using <Solution>.API.Presentation;

[assembly: InternalsVisibleTo("<Solution>.API.UnitTests")]

var builder = WebApplication.CreateBuilder(args);

// Git-ignored local overrides; env vars and command-line args are re-added so they still win
if (builder.Environment.IsDevelopment())
{
    builder.Configuration
        .AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true)
        .AddEnvironmentVariables()
        .AddCommandLine(args);
}

builder.Services.AddServices(builder.Configuration);
builder.Services.AddPresentation(builder.Configuration);

var app = builder.Build();

app.UseExceptionHandler();
app.UseStatusCodePages();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();
app.UseCors();

app.MapEndpoints();
app.MapHealthChecks("health-check");

app.Run();
```

## `DependencyInjection.cs`

```csharp
using System.Text.Json.Serialization;
using <Solution>.API.Application;
using <Solution>.API.Domain.Configuration;
using <Solution>.API.Infrastructure;

namespace <Solution>.API;

public static class DependencyInjection
{
    /// <summary>Registers the clock and the application services implemented in Infrastructure.</summary>
    public static IServiceCollection AddServices(this IServiceCollection services, IConfiguration configuration)
    {
        // Single source of truth for the current UTC time; inject TimeProvider rather than calling DateTime.UtcNow
        services.AddSingleton(TimeProvider.System);

        services.AddScoped<IDanceTypeService, DanceTypeService>();

        return services;
    }

    /// <summary>Registers HTTP concerns: OpenAPI, problem details, health checks, JSON and CORS.</summary>
    public static IServiceCollection AddPresentation(this IServiceCollection services, IConfiguration configuration)
    {
        var corsConfig = new CorsConfig();

        configuration.Bind(nameof(CorsConfig), corsConfig);
        services.AddSingleton(corsConfig);

        services.AddOpenApi();
        services.AddProblemDetails();
        services.AddHealthChecks();

        // Serialize enums by name so callers receive "Latin" rather than 2
        services.ConfigureHttpJsonOptions(options =>
            options.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));

        services.AddCors(options => options.AddDefaultPolicy(policy =>
            policy.WithOrigins(corsConfig.AllowedOrigins)
                .AllowAnyMethod()
                .AllowAnyHeader()));

        return services;
    }
}
```

## `appsettings.json`

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "CorsConfig": {
    "AllowedOrigins": []
  }
}
```

## `appsettings.Development.json`

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "<Solution>": "Debug"
    }
  },
  "CorsConfig": {
    "AllowedOrigins": [ "http://localhost:5173" ]
  }
}
```

## `Properties/launchSettings.json`

```json
{
  "$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar",
      "applicationUrl": "http://localhost:5185",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar",
      "applicationUrl": "https://localhost:7185;http://localhost:5185",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
```

## `<Solution>.API.http`

```http
@HostAddress = http://localhost:5185

GET {{HostAddress}}/dance-types
Accept: application/json

###

GET {{HostAddress}}/health-check

###
```

## `Domain/Enums/DanceCategory.cs`

```csharp
namespace <Solution>.API.Domain.Enums;

public enum DanceCategory
{
    Unknown,
    Social,
    Latin,
    Theatrical
}
```

## `Domain/Models/DanceType.cs`

```csharp
using <Solution>.API.Domain.Enums;

namespace <Solution>.API.Domain.Models;

/// <summary>A style of dance, such as Swing or Salsa.</summary>
public record DanceType(
    int Id,
    string Name,
    DanceCategory Category,
    string Description);
```

## `Domain/Configuration/CorsConfig.cs`

```csharp
namespace <Solution>.API.Domain.Configuration;

/// <summary>Browser origins allowed to call the API, such as the UI dev server.</summary>
public class CorsConfig
{
    public string[] AllowedOrigins { get; set; } = [];
}
```

## `Application/IDanceTypeService.cs`

```csharp
using <Solution>.API.Domain.Models;

namespace <Solution>.API.Application;

public interface IDanceTypeService
{
    /// <summary>Retrieves every supported dance type.</summary>
    Task<IReadOnlyList<DanceType>> GetDanceTypes(CancellationToken cancellationToken);
}
```

## `Infrastructure/DanceTypeService.cs`

```csharp
using <Solution>.API.Application;
using <Solution>.API.Domain.Enums;
using <Solution>.API.Domain.Models;

namespace <Solution>.API.Infrastructure;

public class DanceTypeService : IDanceTypeService
{
    // TODO: Replace the dummy data with a persisted store
    private static readonly IReadOnlyList<DanceType> DanceTypes =
    [
        new(1, "Swing", DanceCategory.Social, "An energetic partner dance that grew up alongside swing-era jazz."),
        new(2, "Jazz", DanceCategory.Theatrical, "A performance style built on isolations, improvisation and syncopated rhythm."),
        new(3, "Salsa", DanceCategory.Latin, "A Latin partner dance with Cuban roots, danced to an eight-count rhythm.")
    ];

    private readonly ILogger<DanceTypeService> _logger;

    public DanceTypeService(ILogger<DanceTypeService> logger)
    {
        _logger = logger;
    }

    public Task<IReadOnlyList<DanceType>> GetDanceTypes(CancellationToken cancellationToken)
    {
        _logger.LogDebug("Retrieved {DanceTypeCount} dance types", DanceTypes.Count);

        return Task.FromResult(DanceTypes);
    }
}
```

## `Presentation/Endpoints.cs`

```csharp
namespace <Solution>.API.Presentation;

public static class Endpoints
{
    public static WebApplication MapEndpoints(this WebApplication app)
    {
        var danceTypes = app.MapGroup("dance-types")
            .WithTags("Dance Types");

        danceTypes.MapGet("", Functions.GetDanceTypes)
            .WithName(nameof(Functions.GetDanceTypes))
            .WithSummary("Retrieves every supported dance type.");

        return app;
    }
}
```

## `Presentation/Functions.cs`

```csharp
using Microsoft.AspNetCore.Http.HttpResults;
using <Solution>.API.Application;
using <Solution>.API.Domain.Models;

namespace <Solution>.API.Presentation;

/// <summary>Handler bodies for the routes mapped in <see cref="Endpoints"/>.</summary>
public static class Functions
{
    /// <summary>Returns every supported dance type.</summary>
    public static async Task<Ok<IReadOnlyList<DanceType>>> GetDanceTypes(IDanceTypeService danceTypeService, CancellationToken cancellationToken)
    {
        var danceTypes = await danceTypeService.GetDanceTypes(cancellationToken);

        return TypedResults.Ok(danceTypes);
    }
}
```

## `<Solution>.API.UnitTests.csproj` (container-layout project reference)

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" />
    <PackageReference Include="Shouldly" />
    <PackageReference Include="xunit.v3" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\<Solution>.API\<Solution>.API.csproj" />
  </ItemGroup>

  <ItemGroup>
    <Using Include="Shouldly" />
    <Using Include="Xunit" />
  </ItemGroup>

</Project>
```

## `<Solution>Test.cs` (base fixture)

```csharp
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace <Solution>.API.UnitTests;

/// <summary>Builds the application services from <c>AddServices</c> with in-memory configuration for each test class.</summary>
public class <Solution>Test : IAsyncLifetime
{
    protected IServiceCollection Services { get; } = new ServiceCollection();

    // InitializeAsync ensures not null
    protected ServiceProvider Provider { get; private set; } = null!;

    public virtual ValueTask InitializeAsync()
    {
        // Add settings here as services start reading configuration
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>())
            .Build();

        Services.AddLogging();
        Services.AddServices(configuration);

        ConfigureServices();

        // Match the Development host so captive scoped dependencies fail here too
        Provider = Services.BuildServiceProvider(new ServiceProviderOptions { ValidateScopes = true, ValidateOnBuild = true });

        return ValueTask.CompletedTask;
    }

    /// <summary>Runs before the provider is built, so feature fixtures can swap real services for fakes.</summary>
    protected virtual void ConfigureServices()
    {
    }

    public virtual async ValueTask DisposeAsync()
    {
        await Provider.DisposeAsync();

        GC.SuppressFinalize(this);
    }
}
```

## `<Solution>ApplicationFactory.cs`

```csharp
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace <Solution>.API.UnitTests;

/// <summary>Hosts the API in memory with pinned settings, so tests never read developer-local files.</summary>
public class <Solution>ApplicationFactory : WebApplicationFactory<Program>
{
    public const string AllowedOrigin = "http://localhost:5173";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // Not Development, so appsettings.Development.json and appsettings.Local.json are skipped
        builder.UseEnvironment("Testing");
        builder.UseSetting("CorsConfig:AllowedOrigins:0", AllowedOrigin);

        // Keep the startup scope and registration checks that Development turns on
        builder.UseDefaultServiceProvider(options =>
        {
            options.ValidateScopes = true;
            options.ValidateOnBuild = true;
        });
    }
}
```

## Fake, feature fixture and handler test

```csharp
// TestDoubles/FakeDanceTypeService.cs
public class FakeDanceTypeService : IDanceTypeService
{
    public static readonly DanceType FakeDanceType = new(99, "Fake Dance", DanceCategory.Unknown, "A dance type that only exists in tests.");

    public Task<IReadOnlyList<DanceType>> GetDanceTypes(CancellationToken cancellationToken)
        => Task.FromResult<IReadOnlyList<DanceType>>([FakeDanceType]);
}

// Presentation/FunctionsTest.cs
public class FunctionsTest : <Solution>Test
{
    protected override void ConfigureServices()
    {
        Services.RemoveAll<IDanceTypeService>();
        Services.AddScoped<IDanceTypeService, FakeDanceTypeService>();
    }
}

// Presentation/FunctionsTests.cs
public class FunctionsTests : FunctionsTest
{
    [Fact]
    public async Task GetDanceTypes_ShouldReturnServiceResult_IfServiceReturnsDanceTypes()
    {
        // Arrange
        await using var scope = Provider.CreateAsyncScope();
        var danceTypeService = scope.ServiceProvider.GetRequiredService<IDanceTypeService>();

        // Act
        var result = await Functions.GetDanceTypes(danceTypeService, TestContext.Current.CancellationToken);

        // Assert
        result.Value.ShouldBe([FakeDanceTypeService.FakeDanceType]);
    }
}
```

## `Presentation/EndpointsTests.cs`

```csharp
using System.Text.Json;

namespace <Solution>.API.UnitTests.Presentation;

/// <summary>Runs the full HTTP pipeline in memory through <see cref="<Solution>ApplicationFactory"/>.</summary>
public class EndpointsTests : IClassFixture<<Solution>ApplicationFactory>
{
    private readonly HttpClient _client;

    public EndpointsTests(<Solution>ApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GettingDanceTypesReturnsSwingJazzAndSalsa()
    {
        // Act
        var json = await _client.GetStringAsync("dance-types", TestContext.Current.CancellationToken);

        // Assert
        using var document = JsonDocument.Parse(json);
        var names = document.RootElement.EnumerateArray()
            .Select(x => x.GetProperty("name").GetString());

        names.ShouldBe(["Swing", "Jazz", "Salsa"]);
    }

    [Fact]
    public async Task GettingDanceTypesFromTheUIOriginIsAllowedByCors()
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, "dance-types");
        request.Headers.Add("Origin", <Solution>ApplicationFactory.AllowedOrigin);

        using var response = await _client.SendAsync(request, TestContext.Current.CancellationToken);

        response.Headers.GetValues("Access-Control-Allow-Origin").ShouldBe([<Solution>ApplicationFactory.AllowedOrigin]);
    }
}
```

## Solution, container layout

```
dotnet new sln -n <Solution>.API --format slnx
dotnet sln <Solution>.API.slnx add <Solution>.API/<Solution>.API.csproj
dotnet sln <Solution>.API.slnx add <Solution>.API.UnitTests/<Solution>.API.UnitTests.csproj
```

## Solution, standalone layout

```
dotnet new sln -n <Solution> --format slnx
dotnet sln <Solution>.slnx add src/<Solution>.API/<Solution>.API.csproj
dotnet sln <Solution>.slnx add tests/<Solution>.API.UnitTests/<Solution>.API.UnitTests.csproj
```

