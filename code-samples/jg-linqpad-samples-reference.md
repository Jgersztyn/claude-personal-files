# JG LINQPad Script Samples - Generic Reference

This file is a supplementary, project-agnostic collection of LINQPad
scripts illustrating JG's LINQPad standard. It is intentionally
**isolated** from the `jg-linqpad-scripts` skill - the skill stands on
its own without this file. The samples are generic illustrations
distilled from real scripts: no project, repository, or domain names
appear, and identifiers have been genericised (`ExampleApi`,
`Organization`, `Entity`, etc.). The `<Query>` XML header is omitted
except in the first sample.

## Mutating script with a dry run

The canonical layout: description, configuration, variables, lean
`Main()`, workflow methods, helpers, data models.

```csharp
<Query Kind="Program">
  <Namespace>System.Net.Http</Namespace>
  <Namespace>System.Net.Http.Json</Namespace>
  <Namespace>System.Threading.Tasks</Namespace>
</Query>

// Moves one user from their current organization to TargetOrganizationId.
// The API allows one organization per user, so a move is DELETE (current) then POST (target).
// To reverse: re-run with TargetOrganizationId set to the id dumped under "BEFORE".

// Configuration

static readonly string BaseURL = "https://example-api.example.com"; // dev: https://dev-example-api.example.com

// Preview changes without sending them; set to false only after reviewing the output
static readonly bool IsDryRun = true;

static readonly string UserEmail = "";
static readonly string TargetOrganizationId = "";

// Recorded as the x-user-id audit header on every request
static readonly string InitiatedBy = "";

// Variables

static readonly DateTime RunStartedUTC = DateTime.UtcNow;

async Task Main()
{
	if (string.IsNullOrWhiteSpace(UserEmail) || string.IsNullOrWhiteSpace(TargetOrganizationId))
	{
		"Set UserEmail and TargetOrganizationId, then re-run.".Dump("Nothing to do -- configuration is blank");
		return;
	}

	using var client = new HttpClient();

	var before = await GetUserByEmail(client, UserEmail);
	before.Dump("BEFORE -- save this: original assignment");

	var currentOrgId = before.OrganizationAssignment?.OrganizationId;
	if (string.Equals(currentOrgId, TargetOrganizationId, StringComparison.OrdinalIgnoreCase))
	{
		"User is already in the target organization.".Dump("Nothing to do");
		return;
	}

	if (IsDryRun)
	{
		DumpPlannedRequests(currentOrgId, TargetOrganizationId, before.Id);
		return;
	}

	if (!await MoveUser(client, before.Id, currentOrgId, TargetOrganizationId))
		return;

	await VerifyMove(client, UserEmail, TargetOrganizationId);
}

static void DumpPlannedRequests(string currentOrgId, string targetOrgId, string userId)
{
	var delete = currentOrgId == null ? "(skipped -- user is unassigned)" : AbsoluteURI(UnassignRoute(currentOrgId, userId)).ToString();
	var post = AbsoluteURI(AssignRoute(targetOrgId, userId)).ToString();

	new { Delete = delete, Post = post }.Dump("DRY RUN -- planned requests");
}

/// <summary>Returns false when the POST fails; the caller must not verify in that case.</summary>
static async Task<bool> MoveUser(HttpClient client, string userId, string currentOrgId, string targetOrgId)
{
	if (currentOrgId != null)
		await Send<Assignment>(client, HttpMethod.Delete, UnassignRoute(currentOrgId, userId));

	try
	{
		var assigned = await Send<Assignment>(client, HttpMethod.Post, AssignRoute(targetOrgId, userId));
		assigned.Dump("Assigned to target organization");
		return true;
	}
	catch (Exception ex)
	{
		$"POST failed [{ex.GetType().Name}]: {ex.Message}. Re-run with TargetOrganizationId = '{currentOrgId}' to restore.".Dump("RECOVERY NEEDED");
		return false;
	}
}

static async Task VerifyMove(HttpClient client, string email, string targetOrgId)
{
	var after = await GetUserByEmail(client, email);
	after.Dump("AFTER");

	var passed = after.OrganizationAssignment?.OrganizationId == targetOrgId;
	(passed ? "PASS -- user is in the target organization" : "FAIL -- organization does not match").Dump("Result");
}

// Helpers

static Task<User> GetUserByEmail(HttpClient client, string email) =>
	Send<User>(client, HttpMethod.Get, $"user/{Uri.EscapeDataString(email)}");

static string UnassignRoute(string organizationId, string userId) => $"organization/{organizationId}/user/{userId}";

static string AssignRoute(string organizationId, string userId) => $"organization/{organizationId}/user/{userId}/assign";

static Uri AbsoluteURI(string route) => new(new Uri(BaseURL), route);

/// <summary>Sends one request with the audit header; throws with status and body on failure.</summary>
static async Task<T> Send<T>(HttpClient client, HttpMethod method, string route)
{
	// Second line of defence: no write leaves the script during a dry run
	if (IsDryRun && method != HttpMethod.Get)
		throw new InvalidOperationException($"Dry run: refusing to send {method} {route}");

	var request = new HttpRequestMessage(method, AbsoluteURI(route));
	request.Headers.Add("x-user-id", InitiatedBy);

	var response = await client.SendAsync(request);
	if (!response.IsSuccessStatusCode)
	{
		var body = await response.Content.ReadAsStringAsync();
		throw new HttpRequestException($"{(int)response.StatusCode} {response.ReasonPhrase} on {method} {route}: {body}");
	}

	return await response.Content.ReadFromJsonAsync<T>();
}

// Data models

public record Assignment(string Id, string UserId, string OrganizationId, DateTime AssignedOn);

public record User(string Id, string Email, Assignment OrganizationAssignment);
```

## Read-only lookup with the Azure connection standard

No `IsDryRun` - nothing is written. The client connects through
`az login` identity; a connection string is read from an environment
variable only when that fails.

```csharp
// Looks up a user's saved items from their email.
// Requires `az login` and the "Storage Table Data Reader" role on the storage account.

// Configuration

static readonly string Email = "";

const string StorageAccountName = "examplestorage";
static readonly Uri TableEndpoint = new($"https://{StorageAccountName}.table.core.windows.net/");

// Break-glass only: read when the az login identity cannot connect
const string ConnectionStringVariable = "EXAMPLE_STORAGE_CONNECTION";

// Variables

const string LookupTable = "UserLookups";
const string ItemsTable = "SavedItems";

async Task Main()
{
	var tables = await ConnectTables(LookupTable);
	if (tables == null)
		return;

	var userIds = await FindUserIds(tables, Email);
	if (userIds.Count == 0)
	{
		$"No row in {LookupTable} for \"{Email}\".".Dump("No user found");
		return;
	}

	foreach (var userId in userIds)
		await DumpSavedItems(tables, userId);
}

static async Task<List<string>> FindUserIds(TableServiceClient tables, string email)
{
	var ids = new List<string>();

	await foreach (var row in tables.GetTableClient(LookupTable).QueryAsync<TableEntity>($"Email eq {Literal(email)}"))
		ids.Add(Text(row, "UserId"));

	return ids.Distinct().ToList();
}

static async Task DumpSavedItems(TableServiceClient tables, string userId)
{
	var rows = new List<TableEntity>();

	await foreach (var row in tables.GetTableClient(ItemsTable).QueryAsync<TableEntity>($"PartitionKey eq {Literal(userId)}"))
		rows.Add(row);

	rows.Select(row => new { Name = Text(row, "Name"), Kind = Text(row, "Kind"), Saved = row.Timestamp })
		.Dump($"Saved items -- {userId} ({rows.Count})");
}

// Helpers

/// <summary>Prefers az login identity, falls back to the break-glass variable; null when neither works.</summary>
static async Task<TableServiceClient> ConnectTables(string probeTable)
{
	var identity = new TableServiceClient(TableEndpoint, new DefaultAzureCredential());
	if (await CanRead(identity, probeTable))
		return identity;

	var connectionString = Environment.GetEnvironmentVariable(ConnectionStringVariable);
	if (!string.IsNullOrWhiteSpace(connectionString))
		return new TableServiceClient(connectionString);

	new
	{
		Problem = $"Could not connect to {StorageAccountName}.",
		Fix = $"Run `az login` and confirm the Storage Table Data Reader role, or set {ConnectionStringVariable}."
	}.Dump("Failed -- nothing was read");
	return null;
}

static async Task<bool> CanRead(TableServiceClient tables, string tableName)
{
	try
	{
		await foreach (var _ in tables.GetTableClient(tableName).QueryAsync<TableEntity>(maxPerPage: 1))
			break;

		return true;
	}
	catch (Exception ex)
	{
		$"[{ex.GetType().Name}] {ex.Message.Split('\n')[0].Trim()}".Dump("Identity connection failed -- trying break-glass");
		return false;
	}
}

static string Literal(string value) => "'" + value.Replace("'", "''") + "'";

static string Text(TableEntity row, string key) => row.TryGetValue(key, out var value) ? value?.ToString() : null;
```

The same shape works for Cosmos DB:
`new CosmosClient(AccountEndpoint, new DefaultAzureCredential())`, with
a Cosmos data-plane role (e.g. "Cosmos DB Built-in Data Reader") in
place of the storage role.

## Batch update with counters and a dry-run branch

Per-item failures are caught, counted and dumped; the run continues.

```csharp
// Configuration

static readonly bool IsDryRun = true;
static readonly string OldLicenseId = "00000000-0000-0000-0000-000000000001";
static readonly string NewLicenseId = "00000000-0000-0000-0000-000000000002";

// Organizations that keep the old license
static readonly HashSet<string> ExcludedOrganizationIds = new()
{
	"00000000-0000-0000-0000-00000000000a",
	"00000000-0000-0000-0000-00000000000b"
};

async Task Main()
{
	using var client = new HttpClient();

	var organizations = await GetOrganizations(client);
	var planned = await BuildPlan(client, organizations);

	if (IsDryRun)
	{
		planned.Dump($"DRY RUN -- planned changes ({planned.Count})");
		return;
	}

	var summary = await ApplyPlan(client, planned);
	summary.Dump("Summary");
}

static async Task<Summary> ApplyPlan(HttpClient client, List<PlannedChange> planned)
{
	int succeeded = 0, failed = 0;

	foreach (var change in planned)
	{
		try
		{
			await ReassignLicense(client, change);
			succeeded++;
		}
		catch (Exception ex)
		{
			$"[{ex.GetType().Name}] {ex.Message}".Dump($"Error -- {change.OrganizationName}");
			failed++;
		}

		// Small delay to avoid overwhelming the API
		await Task.Delay(200);
	}

	return new Summary(IsDryRun ? "Dry run" : "Committed", planned.Count, succeeded, failed);
}

// Data models

public record PlannedChange(string OrganizationId, string OrganizationName, DateTime Expiration);

public record Summary(string Mode, int Planned, int Succeeded, int Failed);
```

## Common review fixes

Patterns found in real scripts and what replaces them.

| Found | Replace with |
|---|---|
| Account key or connection string with `AccountKey=` inline | `DefaultAzureCredential` against an endpoint from the account name; connection string only from an environment variable |
| Multi-paragraph header, `// =====` banners, ASCII tables in comments | Three one-line description comments at most |
| Write with no `IsDryRun`, or `IsDryRun` defaulting to `false` | `static readonly bool IsDryRun = true;` and a branch in `Main()` |
| `void Main() { RunAsync().Wait(); }` | `async Task Main()` |
| Whole script wrapped in `class Program { ... }` | Top-level members in `Kind="Program"` |
| `Console.WriteLine(...)` | `.Dump("Title")` |
| `results.Count().Dump(); foreach (var item in results) item.Dump();` | `results.Select(...).Dump($"Title ({results.Count})")` |
| `.Dump("Uri")` on every request | Remove once the script works |
| Nested `if (org.Id != "...")` chains | `ExcludedOrganizationIds.Contains(org.Id)` from configuration |
| The same GUID repeated inside method bodies | One configuration field |
| `DateTime.Now` in a method body | The captured `RunStartedUTC` |
| Unused result variable kept for debugging | Remove it, or dump it with a title |
| `GetUserByEmailAsync` | `GetUserByEmail` (no `Async` suffix) |
| `UpdateThingV3.linq` beside `UpdateThing.linq` | One script, driven by configuration |
