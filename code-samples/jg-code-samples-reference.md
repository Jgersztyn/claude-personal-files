# JG C# Code Samples - Generic Reference

This file is a supplementary, project-agnostic collection of brief C#
snippets illustrating JG's preferred style. It is intentionally
**isolated** from the coding-style skill - the skill stands on its own
without this file. The samples here are generic illustrations: no
project, repository, or domain names appear. Identifiers have been
genericised (`EntityMetaData`, `ReportEntryDTO`, `UploadService`, etc.).
Folder spellings `Persistance/` and `Utilties/` are deliberately
preserved because they are JG's load-bearing convention.

## Project layout

```
src/ServiceName/
├── Program.cs
├── Endpoints.cs
├── DependencyInjection.cs
├── Application/      # Interfaces, inbound models, app enums
├── Domain/           # Entities, domain enums, Configuration/
├── Infrastructure/   # I*Service impls, Persistance/ (sic)
└── Utilties/         # Cross-cutting helpers (sic)
Tests/ServiceName.UnitTests/
```

## Composition root

```csharp
[assembly: InternalsVisibleTo("ServiceName.UnitTests")]

var builder = WebApplication.CreateBuilder(args);
var configuration = builder.Configuration
    .AddEnvironmentVariables()
    .AddJsonFile("appsettings.Local.json", true, true).Build();

builder.Services.AddServices(configuration);
var app = builder.Build();
app.MapEndpoints();
app.MapHealthChecks("health-check");
app.Run();
```

## DI extension methods

```csharp
public static IServiceCollection AddServices(
    this IServiceCollection services, IConfiguration configuration)
{
    var storageConfig = new StorageConfig();
    configuration.Bind(nameof(StorageConfig), storageConfig);
    services.AddSingleton(storageConfig);
    services.AddSingleton<Func<DateTime>>(() => DateTime.UtcNow);
    services.AddScoped<IEntityOperationsService, EntityOperationsService>();
    return services;
}
```

## Endpoints + Functions

```csharp
public static class Endpoints
{
    public static WebApplication MapEndpoints(this WebApplication app)
    {
        app.MapGet("entity/{entityId}", Functions.GetEntity);
        return app;
    }
}
```

```csharp
public static class Functions
{
    public static async Task<EntityMetaData?> GetEntity(
        IEntityOperationsService metadataService, string entityId, CancellationToken ct)
        => await metadataService.GetEntity(entityId, ct);
}
```

## Constructor injection with `_camelCase` fields

```csharp
public class UploadService : IUploadService
{
    private readonly IEntityOperationsService _metadataService;
    private readonly ILogger<UploadService> _logger;

    public UploadService(IEntityOperationsService metadataService, ILogger<UploadService> logger)
    {
        _metadataService = metadataService;
        _logger = logger;
    }
}
```

## Primary constructor (alternate form)

```csharp
public class UploadService(
    IEntityOperationsService metadataService,
    ILogger<UploadService> logger,
    IOptions<UploadOptions> options,
    IDateTimeProvider dateTimeProvider) : IUploadService
{
    private readonly UploadOptions _options = options.Value;
}
```

## Service method with try/catch logging the exception type

```csharp
public async Task DeleteEntity(EntityMetaData entity, CancellationToken cancellationToken)
{
    try
    {
        await _metadataService.Remove(entity, cancellationToken);
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "An error occured when deleting entity id {0} [{ExceptionType}]",
                         entity.Id, ex.GetType().Name);
    }
}
```

## Logger calls: `LogDebug` vs `LogInformation`

```csharp
// LogDebug: trace-style breadcrumbs filterable out of dashboards
_logger.LogDebug("Processed {0} items in current batch", count);
_logger.LogDebug("Skipping entity {0}; already uploaded", entityId);

// LogInformation: milestone events an operator watches in normal ops
_logger.LogInformation("Recurring schedule registered for job {0}", jobName);
_logger.LogInformation("Entity metadata saved for id {0}", id);
```

## `Func<DateTime>` clock registration + usage

```csharp
// Composition root
services.AddSingleton<Func<DateTime>>(() => DateTime.UtcNow);

// Constructor
public EntityService(Func<DateTime> getCurrentDateTime)
{
    _getCurrentDateTime = getCurrentDateTime;
}

// Call site
var now = _getCurrentDateTime();
```

## `IDateTimeProvider` interface (alternate form)

```csharp
public interface IDateTimeProvider
{
    DateTime UtcNow { get; }
}

// Call site
var today = _dateTimeProvider.UtcNow.Date;
```

## A `record` DTO with `const string Container`

```csharp
public record LogEntryDTO(
    string Id,
    string Partition,
    DateTime CreatedOn,
    string Message)
{
    public const string Container = "log-entries";
    public const string PartitionSetup = "/partition";
}
```

## A `class` entity with `null!` defaults

```csharp
public class EntityMetaData
{
    public const string Container = "entities";
    public string Id { get; set; } = null!;
    public string Partition { get; set; } = null!;
    public string OwnerId { get; set; } = null!;
    public DateTime CreatedOn { get; set; }
    public JobStatus Status { get; set; }
}
```

## Interface with one-line `<summary>` XML doc

```csharp
public interface IEntityOperationsService
{
    /// <summary>Retrieves all active entities.</summary>
    Task<List<EntityMetaData>?> GetEntities(CancellationToken cancellationToken);

    /// <summary>Marks the entity as deleted and clears its blob reference.</summary>
    Task DeleteEntity(string entityId, CancellationToken cancellationToken);
}
```

## Two-line inline comment (acceptable upper bound)

```csharp
// The check here is actually case sensitive, an upper case category
// name, e.g. "X018" won't work
if (knownCategories.Contains(category))
{
    Process(category);
}
```

## Test class hierarchy

Base fixture wiring real DI, per-feature subclass swapping fakes, and
the `[Fact]` class:

```csharp
public class ServiceTest : IAsyncLifetime
{
    protected IServiceCollection Services { get; } = new ServiceCollection();
    public virtual Task InitializeAsync() => Task.CompletedTask;
    public Task DisposeAsync() => Task.CompletedTask;
}
```

```csharp
public class UploadServiceTest : ServiceTest
{
    public override Task InitializeAsync()
    {
        Services.RemoveAll<IUploadService>();
        Services.AddScoped<IUploadService, FakeUploadService>();
        return base.InitializeAsync();
    }
}
```

```csharp
public class UploadServiceTests : UploadServiceTest
{
    [Fact]
    public void Parse_ShouldReturnUtc_IfInputIsValid()
    {
        var result = TimestampParser.Parse("2024-01-01T00:00:00Z");
        result.Kind.ShouldBe(DateTimeKind.Utc);
    }
}
```

## Hand-written test double

```csharp
public class FakeUploadService : IUploadService
{
    public Task Upload(EntityMetaData entity, CancellationToken cancellationToken)
        => Task.CompletedTask;

    public Task<List<EntityMetaData>?> GetEntities(CancellationToken cancellationToken)
        => Task.FromResult<List<EntityMetaData>?>(new List<EntityMetaData>());
}
```

---

## Optional code samples (apply only when the project uses these tools)

### EF Core `OnModelCreating` block

```csharp
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<EntityMetaData>()
        .HasNoDiscriminator()
        .ToContainer(EntityMetaData.Container)
        .HasPartitionKey(x => x.Partition)
        .HasKey(x => new { x.Id });
}
```

### Hangfire `Enqueue<T>` chain

```csharp
// At the end of one stage, enqueue the next stage on its named queue
_backgroundJobClient.Enqueue<IUploadService>(
    "upload-queue",
    service => service.Upload(entityId, default));

[DisableConcurrentExecution(timeoutInSeconds: 70 * 60)] // 1 hour, 10 minutes
public async Task RunDailyJob(string jobName, CancellationToken cancellationToken = default) { }
```

### Service Bus handler registration

```csharp
// In AddServices
services.RegisterAzureServiceBusWorker(
    serviceBusConfig.ConnectionString, "service-name")
    .ProcessQueue(serviceBusConfig.QueueName, Functions.HandleEnqueueJob);

// Handler lives on the Functions static class next to HTTP handlers
public static async Task HandleEnqueueJob(
    RequestModel request, IBackgroundJobClient backgroundJobClient) { }
```

### Serilog + structured placeholders (when forwarding to a structured sink)

```csharp
_logger.LogInformation(
    "Starting job {JobName} at {ExecutionDate:yyyy-MM-dd}",
    SanitizeForLog(jobName), executionDate);
```
