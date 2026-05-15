---
name: jg-code-style
description: Apply JG's preferred C# .NET coding style — vertical-slice / onion layering (Application / Domain / Infrastructure), explicit constructor injection with `_camelCase` private fields, methods strictly under 50 lines, one-line inline comments, XML `///` docs on interfaces, Grafana-aware log levels, single UTC clock source. Use when writing, reviewing, or restructuring C# service code, and especially when the user references "my coding style", "JG's style", or asks for code that matches their established C# style.
---

# JG Code Style

Applies JG's preferred C# .NET service-code conventions. This skill is
self-contained — every rule is explained inline. Use it as the
authoritative source when writing, reviewing, or restructuring C# code
that should match this style.

---

## When to apply this skill

- Writing or modifying C# code in a `.cs` file.
- Designing a new service / project layout.
- Reviewing existing code for style alignment.

---

## Hard rules (never skip)

These are non-negotiable. If something here conflicts with the rest
of the document, the hard rule wins.

1. **Methods stay under 50 lines** (including up to ~10 lines of
   inline comments). If a method is creeping past 50, extract a
   private helper. The only exception is a complex orchestrator
   that passes a deliberate review: phases truly sequential and
   tightly coupled, extracting helpers would produce single-call
   methods, and `// Phase N:` comments mark each section.

2. **Inline comments are ONE line.** Two lines only when absolutely
   necessary (e.g., constraint + example pair). Reaching for a
   third line is a refactor signal — rename, extract, or move the
   text to a `<summary>`.

3. **Always log the exception type.** In every catch, include
   `ex.GetType().Name` in the message body so it stays visible in
   flat log views (Grafana panels, console output):
   ```csharp
   _logger.LogError(ex, "Operation failed [{ExceptionType}]: {Id}",
                    ex.GetType().Name, id);
   ```

4. **Single source of truth for "now", in UTC.** Each service has
   exactly one registered clock dependency. No `DateTime.UtcNow` /
   `DateTime.Now` scattered in service bodies. Convert to local
   time only at the edge (presentation / formatting / UI).

5. **Existing repos: match the local conventions.** Don't modernize
   on sight, and never auto-correct the deliberate folder spellings
   `Persistance` and `Utilties` when they are already established
   in the repo.

---

## Area 1 — Architectural Layering

Vertical-slice / onion architecture. Each service folder contains:

- **`Application/`** — Interfaces (`I*Service`), inbound request
  models, application-only enums (`JobStatus`, `JobType`).
- **`Domain/`** — Persisted entities, domain enums, configuration
  POCOs under `Configuration/`.
- **`Infrastructure/`** — Implementations of `Application/I*Service`,
  EF contexts under `Persistance/` (deliberate spelling), integration
  helpers under `Helpers/`.
- **Presentation** — `Endpoints.cs` + a `Functions` static class
  for APIs; Razor for UI; message-bus handlers when present. Omit
  if not needed.
- **`Utilties/`** (deliberate spelling) — cross-cutting helpers:
  constants, file helpers, recurring-job registration.

**Rule of dependency direction:** Infrastructure implements
interfaces declared in Application. Never the reverse.

**Slice-by-feature**: a service-per-use-case under `Infrastructure/`,
each registered against its `I*Service` interface in Application.
Only include the layers the project actually needs — a worker
service with no UI uses its API as the presentation layer; a
library may omit presentation entirely.

---

## Area 2 — Naming

- **Interfaces** prefixed `I`. Every service has a matching
  interface even with only one implementation.
- **Implementation class name = interface name minus the `I`**.
- **Private fields** in services: `_camelCase` with leading
  underscore (`_logger`, `_metadataService`, `_getCurrentDateTime`).
- **Methods**: PascalCase. **No `Async` suffix** on `Task`-returning
  methods. Verb-first, domain-action names — no `Do` / `Run` /
  `Execute` filler.
- **Locals**: `camelCase`, no underscore.
- **Acronyms stay fully uppercase** in identifiers: `DTO`, `JSON`,
  `CSV`, `URL`, `HPC`, `SMS`.
- **Enums**: first member is `Unknown` or `None` when there's a
  natural default. Members with digit-leading names use a leading
  underscore (`_00z`, `_06z`).
- **`DTO` suffix** only when the type is also a persisted document
  (e.g., `LogEntryDTO`, `ReportEntryDTO`). Plain request models
  have no suffix (`EntityCreationRequest`, `LogEntry`).
- **Constants**: PascalCase `static readonly` or `const`
  (`BlobContainerName`, `Container`, `PartitionSetup`).
- **File-level**: filename matches the type name. One public type
  per file; small companion types only when single-use.

---

## Area 3 — File Structure & Module Boundaries

- **File-scoped namespaces** (`namespace X;`) for new files. Some
  older files use block-scoped — leave them alone.
- **`[assembly: InternalsVisibleTo("...UnitTests")]`** at the top
  of `Program.cs` for test access. Don't make things public for
  testability.
- **`#region`** acceptable for splitting a class along sub-features
  (e.g., a `RetrievalService` with `#region File Ingest` and
  `#region Maintenance Records`). Don't overuse.
- **Folder spellings** `Persistance` and `Utilties` are load-bearing
  in existing repos (folder names match namespaces). Match them
  exactly. The corrected spellings (`Persistence`, `Utilities`)
  are an alternative worth considering on a brand-new repo — confirm
  before adopting.

---

## Area 4 — Program / Composition Root

- **Top-level statements** in `Program.cs`. No `Main` method.
- **Two-or-three grouped DI extensions** on `IServiceCollection`:
  - `AddServices(this IServiceCollection, IConfiguration)` —
    primary bootstrap (logging + scoped service registrations).
  - One extension per significant infrastructure concern
    (`AddCosmosServices`, `AddServer`, etc.) so the root reads
    as a short list of named groups.
- **Config POCOs** in `Domain/Configuration/` bound via
  `configuration.Bind(nameof(T), instance)` and registered as
  singletons. `IOptions<T>` is an alternative worth considering on
  a new project.
- **Endpoints** registered via `MapEndpoints(this WebApplication app)`
  in `Endpoints.cs`, sitting next to a `Functions` static class
  whose static methods are the handler bodies.
- **Health check** mapped at `/health-check`.

---

## Area 5 — Function / Method Structure

- **Hard cap: 50 lines** (see Hard Rule 1).
- **Typical target: 10–40 lines.**
- **Explicit constructor with `_camelCase` field assigns**:
  ```csharp
  public Foo(IBar bar, ILogger<Foo> logger)
  {
      _bar = bar;
      _logger = logger;
  }
  ```
  Primary constructors are an alternative worth considering on a
  new project, especially with many dependencies.
- **`CancellationToken` is always the LAST parameter.** Do not
  default it on service interfaces. Defaulting it on background-job
  entry points is acceptable at framework boundaries that need
  the no-arg path.
- **Static private helpers** when they don't need instance state.
- **Private instance helpers** when they use injected dependencies.

---

## Area 6 — Async / Concurrency

- `async`/`await` throughout. Never `.Result` / `.Wait()`.
- **Thread `CancellationToken`** to async calls — especially
  `SaveChangesAsync(ct)` and `*Async` LINQ operators.
- **Sequential awaits by default.** Introduce `Task.WhenAll` only
  when explicitly needed; favor simple linear flows.

---

## Area 7 — Error Handling

- **Default catch type: `Exception ex`.** This is the baseline shape.
- **Use more specific exception types when they meaningfully scope
  the failure**, especially around I/O:
  - `IOException`, `FileNotFoundException`,
    `UnauthorizedAccessException` for file system.
  - `RequestFailedException` for Azure SDK calls.
  - `HttpRequestException`, `TimeoutException` for HTTP.
  - `DbUpdateException` for EF Core writes.
  Catch the specific type when you can act on it differently
  (different log message, different fallback). Otherwise fall back
  to the bare `Exception` baseline. Specific types give Grafana
  queryable categories.
- **Always log the exception type** (see Hard Rule 3):
  ```csharp
  catch (Exception ex)
  {
      _logger.LogError(ex, "An error occured when deleting entity {0} [{ExceptionType}]",
                       entity.Id, ex.GetType().Name);
  }
  ```
  `LogError(ex, ...)` attaches the full exception to the log scope;
  the `{ExceptionType}` token surfaces the type name in flat views.
- **Catch at the slice boundary**, not deep in helpers.
- **Default: log + swallow** — operation proceeds with sibling work.
  **Use log + rethrow** when a retry/failure framework is upstream
  (background-job runner, message bus, transactional caller).
- **`occured` (sic)** is the established spelling in log messages —
  match it where it already exists.
- **No custom exception types. No result/either monads.**
- **Null-tolerant updates**: `if (entity != null) { mutate; await
  SaveChangesAsync(ct); }` rather than throwing on missing records.

---

## Area 8 — Logging (Grafana-aware)

- **Inject `ILogger<T>`** via DI. Never use static loggers in
  services.
- **Pick the level by who needs to see the line in Grafana:**
  - **`LogDebug`** — DEFAULT for informational / trace breadcrumbs:
    "starting", "processed N items", "uploaded blob", "skipping
    because already exists". Filterable out of normal dashboards.
  - **`LogInformation`** — milestone events an operator watches in
    a dashboard: "job completed", "recurring schedule registered",
    "deployment ready". Anything you'd want a human to see during
    healthy operation.
  - **`LogWarning`** — recoverable degradations: partial download,
    retry attempted, record skipped with reason.
  - **`LogError`** — exception-bearing failures. Always pair with
    the caught exception and `ex.GetType().Name` (Hard Rule 3).
  - **`LogCritical`** — rare. "Service can't continue" only.
- **Placeholders**: prefer **named structured placeholders** —
  `_logger.LogInformation("Entity saved {EntityId}", id);`
  Named placeholders preserve field names in structured-log
  backends (Grafana, Datadog, Seq), which is a substantive
  improvement when logs are forwarded to a structured sink.
  Positional `{0}`, `{1}` is acceptable in existing files that
  already use it — don't churn for the sake of it.
- **Sanitize user-controlled input before logging it** —
  `SanitizeForLog(value)` to strip control characters / CR-LF.
  Adopt without hesitation any time external strings flow into
  log calls. It's a security guardrail, not a stylistic choice.

---

## Area 9 — Comments & Documentation

- **Hard Rule 2: inline comments are ONE line.** Two lines only
  when absolutely necessary.
- **Default: explain WHY, not WHAT.** Concise wording — strip
  filler ("note that", "we want to", "this is just"). The code
  shows the *what*; the comment justifies it.
  - One-line examples:
    `// Current year is used as the partition key`
    `// This job must always take priority over other jobs`
  - Acceptable two-line example (constraint + example pair):
    ```csharp
    // The check here is actually case sensitive, an upper case
    // entity code, e.g. "V018" won't work
    ```
  Anything longer than this is a refactor signal.
- **XML doc comments (`///`) are part of the standard.** Use them on:
  - **Every method declared on an interface** — interfaces are
    the contracts callers see.
  - **Every non-trivial public method on a service implementation**.
  - **Public types with non-obvious purpose** (configuration POCOs,
    DTOs with non-self-evident fields).
  Keep them concise — single-line `<summary>` is the default:
  ```csharp
  /// <summary>Retrieves all active entities.</summary>
  Task<List<EntityMetaData>?> GetEntities(CancellationToken cancellationToken);
  ```
  Add `<param>` and `<returns>` only when the name doesn't already
  carry the meaning. **Empty `<param>` placeholders are clutter** —
  fill them with a useful sentence or omit them entirely.
- **Section / phase markers** inside long orchestrators:
  - `#region`-style for sub-features within a class.
  - Inline `// Task 2:` / `// Phase N:` comments for phases within
    a single method. Reserved for the rare orchestrators that pass
    the >50-line review.
- **`// TODO:`** for unfinished work — short description inline,
  no date or initials.
- **Named-argument call-site comments** on a single line:
  `skipExisting: true,   // Skip already processed records for idempotency`
- **Commented-out code is sometimes intentional** — documents a
  path considered and rejected. Don't delete on sight.
- **Typos in existing code** (`occured`, `Persistance`, `Utilties`,
  `attempng`) are retained where they appear. Don't auto-correct.

---

## Area 10 — Time / Clock Injection

- **Single source of truth for "now"** (Hard Rule 4). Each service
  has exactly one registered clock dependency that returns UTC.
  Every method that needs the current time goes through that one
  dependency. No `DateTime.UtcNow` / `DateTime.Now` calls scattered
  in service bodies.
- **UTC at the source, convert at the edge.** The clock returns UTC.
  Conversion to a local time zone or a different representation
  happens at the last possible moment — presentation layer, log
  enrichment, UI rendering — *never* inside business logic.
- **Default shape: `Func<DateTime>`** singleton:
  ```csharp
  services.AddSingleton<Func<DateTime>>(() => DateTime.UtcNow);
  ```
  Constructor parameter `Func<DateTime> getCurrentDateTime`, stored
  as `_getCurrentDateTime`, called as `_getCurrentDateTime()`.
- **Alternative worth considering: `IDateTimeProvider` interface**:
  ```csharp
  public interface IDateTimeProvider { DateTime UtcNow { get; } }
  ```
  More discoverable in IntelliSense, easier to extend.
- **Whichever shape you pick, the rule is the same**: one
  registration, UTC, every consumer goes through it.

---

## Area 11 — Imports / Usings

- **`ImplicitUsings` enabled** in the csproj. Don't list BCL
  namespaces that implicit usings already cover.
- **`Nullable` enabled** everywhere except legacy projects that
  predate it.
- **Group order is loose** — external packages first, internal
  project namespaces after. Within each group, order is the order
  things were added. Don't reorder existing files unless asked.
- **Test projects** expose globals via csproj `<Using Include="..." />`
  for `Shouldly` and `Xunit` so test files don't repeat them.

---

## Area 12 — Testing

- **Framework**: xUnit + Shouldly. No mocking libraries.
- **Layout**: `Tests/<ProjectName>.UnitTests/` alongside `src/`.
  Each subject under test gets its own folder.
- **Test doubles**: hand-written stub classes implementing the
  interface, under `Tests/.../TestDoubles/`.
- **Test class hierarchy**:
  - `<Project>Test` base implementing `IAsyncLifetime` wires the
    real DI container with an in-memory `IConfiguration` so the
    test container looks like production.
  - Per-feature subclass overrides `InitializeAsync` to swap real
    services for fakes:
    `Services.RemoveAll<T>(); Services.AddScoped<T, FakeT>();`
  - `[Fact]`-bearing class subclasses the feature fixture and
    pulls dependencies via `Provider.GetRequiredService<T>()`.
- **Test naming**:
  - Pure-function unit tests: `MethodName_ShouldDoX_IfCondition`
    (e.g., `ParseTimestamp_ShouldReturnCorrectValue_WhenInputIsValid`).
  - End-to-end / UI: behavior-narrative
    (`AddingTwoNumbersProducesCorrectResult`,
    `DivideByZeroProducesHelpfulMessage`).
- **AAA comments** (`// Arrange`, `// Act`, `// Assert`) on the
  first test in a file; omit on subsequent tests where the pattern
  is obvious.
- **Assertions**: Shouldly fluent — `result.ShouldBe(expected);`,
  `Should.Throw<T>(() => ...);`.
- **One concept per test** — one `.ShouldBe(...)` per `[Fact]` is
  the target.

---

## Area 13 — Domain Type Modeling

- **`class`** for mutable entities and request models. Required
  reference props default to `= null!;`.
- **`record`** (positional) for immutable DTOs / snapshots.
- **`sealed record`** for owned value objects used in exactly one
  place.
- **Config**: plain POCO classes with `{ get; set; } = string.Empty;`
  defaults — not records.
- **Enums** for closed sets. First member is `Unknown` or `None`
  when there's a natural default.
- **Container / partition metadata** travels with the persisted type
  as `const string Container` / `const string PartitionSetup`.

---

## Area 14 — Formatting

Delegate to `.editorconfig` / `dotnet format` for whitespace.
What the code shows:

- 4-space indentation.
- Opening braces on a new line (Allman).
- Blank line between logical phases inside methods.
- No trailing comma in collection initializers.

---

## Optional / Tool-Specific (do NOT standardize)

The following patterns appear with specific tools. **Apply only
when the project actually uses them.**

- **Hangfire** (background-job runner) — named queues per stage,
  service-to-service `Enqueue<INext>` chains,
  `[DisableConcurrentExecution]`, `StartRecurringJobs` extension.
  Pair with log-and-rethrow.
- **Azure Service Bus** — `MinimalAzureServiceBus.Core` package;
  handler is a static method on the `Functions` class alongside
  HTTP handlers.
- **EF Core + Cosmos DB** — `AddDbContextFactory<T>` + scoped
  interface passthrough. Container name as `const string Container`
  on the entity. Read-modify-save CRUD shape.
- **Dapr** — sidecar component YAMLs under `Dapr/Components/`,
  `DaprClient` scoped, `UseCloudEvents` + `MapSubscribeHandler`
  in the pipeline.
- **Serilog + DataDog** — Serilog logger built in `Program.cs` /
  `AddServer`; console sink always, DataDog often commented out
  for local dev.

If the project doesn't use one of these, ignore the corresponding
section entirely. Don't introduce them just because they're listed
here.

---

## Further Reading

Supplementary references on vertical-slice / onion architecture:

- https://www.jimmybogard.com/vertical-slice-architecture/
- https://www.milanjovanovic.tech/blog/vertical-slice-architecture

If these pages are unavailable, the skill remains complete; the
references are supplementary background only.

---

## How to apply this style in practice

1. **Read the room first.** Open a representative file in the
   target project to confirm the local conventions before
   defaulting to this skill. Match what's there.
2. **Use the right baseline**:
   - Existing repo with established conventions → match the repo.
   - Brand-new project → apply the defaults in this skill, and
     surface the "alternative worth considering" options
     (named log placeholders, `SanitizeForLog`, primary
     constructors, `IDateTimeProvider`, corrected folder
     spellings) for the user to choose.
   - UI / Razor project → relax the underscore convention on
     component fields, use code-behind partials.
3. **Method approaching 50 lines** → extract a private helper now.
4. **Inline comment reaching for a third line** → rename, extract,
   or move to a `<summary>` — don't grow the comment.
5. **Adding a try/catch** → choose a specific exception type if you
   can act on it; otherwise `Exception ex`. Always include
   `ex.GetType().Name` in the message.
6. **Adding a log line** → pick the level by Grafana audience.
   Default trace breadcrumbs to `LogDebug`, milestones to
   `LogInformation`.
7. **Adding time logic** → route through the single injected clock,
   keep UTC inside the service, convert only at the edge.
8. **Adding a public method** → write a one-line `<summary>` doc
   comment, especially on interfaces.
9. **Designing a new service** → start with the
   Application / Domain / Infrastructure folder triad. Only add
   layers the project actually needs.
10. **When unsure about any specific rule**, consult the relevant
    Area section in this skill — it is the authoritative source.
