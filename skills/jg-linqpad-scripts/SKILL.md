---
name: jg-linqpad-scripts
description: Create lightweight, minimal LINQPad scripts that isolate a feature from a larger application so it can be tested independently — including one-off lookups and data fixes run against live APIs, Cosmos DB or Table Storage. Enforces JG's script layout (configuration → variables → lean Main → workflow methods → helpers and models), focused titled `Dump()` output, an `IsDryRun` gate on anything that modifies data, Azure connections through `az login` identity instead of keys, and JG's C# formatting and naming. Use when writing, scaffolding, simplifying or reviewing LINQPad (.linq) scripts, when the user wants to test or prototype a feature outside the main app, and especially when the user references "a LINQPad script", "a linq script", "test this in LINQPad", "in LINQPad" or "my LINQPad standard".
---

# JG LINQPad Scripts

Creates LINQPad scripts that are as lightweight and simple as possible.
The purpose of a script is to isolate a feature from a larger
application and exercise it independently — test an API call, look up
a record, or apply a one-off data fix. This skill is self-contained —
the standard is stated inline.

---

## When to apply this skill

- Writing a new LINQPad script.
- Isolating a feature from a larger app to test it on its own.
- Writing a one-off lookup or data fix against a live system (HTTP
  API, Cosmos DB, Azure Table Storage, SQL).
- Simplifying or reviewing an existing LINQPad script.
- The user references "a LINQPad script" or "test this in LINQPad".

---

## Hard rules (never skip)

These are non-negotiable. If something here conflicts with the rest
of the document, the hard rule wins.

1. **Keep it lightweight.** The simplest script that does the task is
   the correct one. Add nothing that is not needed.

2. **Isolate the feature.** The script exercises one feature
   independently of the larger app's environment — no DI container,
   no host, no project references unless the user asks for them.

3. **Follow the layout, top to bottom:** configuration → variables →
   `Main()` → workflow methods → helpers and models (Area 1). Never
   reorder it.

4. **`Main()` coordinates; it does not compute.** It reads like a
   short list of steps. Any loop body, parsing, request building or
   branching beyond a guard clause belongs in a method below it.

5. **Anything that modifies data has an `IsDryRun` flag, and it
   defaults to `true`.** A dry run performs every read, computes the
   planned changes, dumps them, and sends no writes (Area 4). For
   read-only scripts the flag is omitted unless Claude flags a reason
   to add one.

6. **Output is focused.** Every `Dump()` carries a title and shows
   only what answers the task — project to the relevant fields before
   dumping. No unrelated data unless the user asks (Area 3).

7. **Connect through identity, not secrets.** Azure resources are
   reached with `DefaultAzureCredential` (signed in via `az login`)
   against an endpoint built from the account name. A connection
   string is a break-glass fallback read from an environment
   variable — never pasted into the script. A literal connection
   string is used only when the user explicitly asks for one
   (Area 2).

---

## Area 1 — Script layout

Every script uses `<Query Kind="Program">` and is laid out in this
order. Members sit at the top level of the query — do not wrap the
script in `class Program { ... }`.

| # | Section | Holds |
|---|---|---|
| 0 | Query header | LINQPad's `<Query>` XML: NuGet references and namespaces. Managed by LINQPad. |
| 1 | Description | Up to three one-line comments: what the script does, prerequisites (auth, roles), how to reverse it if it mutates. |
| 2 | Configuration | Everything the operator edits before a run: target URLs, environment, ids, inputs, `IsDryRun`. |
| 3 | Variables | Script-wide values the operator does not edit: serializer options, table names, exclusion sets, the run's UTC timestamp. |
| 4 | `Main()` | The entry point. Guard clauses, then a short sequence of calls. |
| 5 | Workflow methods | The steps `Main()` calls, in the order it calls them. |
| 6 | Helpers | Request senders, formatting, parsing and other utility functions. |
| 7 | Models | Records, classes and enums, under a `// Data models` comment. |

- **The description is at most three lines**, one sentence each. It
  says what an operator needs before pressing Run — nothing about how
  the backend works internally, how the script was researched, or
  how confident the author is. That belongs in the conversation, not
  the file.
- **No comment essays anywhere in the script.** Comments follow the
  one-line rule in Area 6 everywhere, the description included. No
  banner comments (`// =====`), no capitalised heading blocks, no
  ASCII tables or worked examples in comments, no instructions that
  repeat what a guard clause already dumps.
- **Mark the sections** with one-line comments — `// Configuration`,
  `// Variables`, `// Helpers`, `// Data models` — so the boundaries
  are visible at a glance. Workflow methods need no marker; they
  follow `Main()`.
- **Name the script for its action**: `ReassignUserOrganization.linq`,
  `LookupSavedViewsByEmail.linq`. Do not keep `V2` / `V3` copies of a
  script side by side — change the configuration instead.

---

## Area 2 — Configuration, variables and connections

- **Configuration is `static readonly`** (or `const` for literals that
  never change between runs), PascalCase, each with a one-line
  comment when the meaning is not obvious from the name.
- **Name the environment explicitly.** Keep the target URL or account
  in one field. Alternate environments may stay as a trailing
  one-line comment (`// dev: https://dev-...`); never leave several
  live alternatives scattered across the file.
- **Lift every magic value into configuration or variables.** Ids,
  license keys, exclusion lists and dates that appear in method
  bodies belong at the top. An exclusion list is a `HashSet<string>`
  checked once — never a chain of nested `if (id != "...")`.
- **Validate configuration first.** `Main()` opens with guard clauses
  that refuse to run on a blank or placeholder value, dump the reason
  with a title, and `return`:
  ```csharp
  if (string.IsNullOrWhiteSpace(TargetId))
  {
      "Set TargetId, then re-run.".Dump("Nothing to do -- TargetId is blank");
      return;
  }
  ```
### Connecting to Azure

The standard for any Azure resource (Table Storage, Blob, Cosmos DB,
Key Vault):

- **Configure the account name, derive the endpoint.** Both live in
  configuration:
  ```csharp
  const string StorageAccountName = "examplestorage";
  static readonly Uri TableEndpoint = new($"https://{StorageAccountName}.table.core.windows.net/");
  ```
- **Default: `DefaultAzureCredential`.** `new TableServiceClient(TableEndpoint, new DefaultAzureCredential())`,
  `new CosmosClient(AccountEndpoint, new DefaultAzureCredential())`.
  The operator runs `az login` once. The account also needs the
  resource's *data-plane* role (e.g. "Storage Table Data Reader") —
  subscription Owner alone does not grant data access. State the role
  in the description line for prerequisites.
- **Break-glass: a connection string from an environment variable.**
  The variable's name is a `const` in configuration
  (`const string ConnectionStringVariable = "EXAMPLE_STORAGE_CONNECTION";`).
  It is read only when the identity connection fails, so leaving it
  unset costs nothing.
- **Probe, then report.** Connect in one helper that tries the
  identity path with a minimal read, falls back to the variable, and
  — if neither works — dumps the problem and the fix and returns
  `null`, so `Main()` stops before reading anything.
- **Non-Azure credentials** (API bearer tokens, passwords) also come
  from environment variables, never from the script body.
- **Literal connection strings** only when the user explicitly asks.
  Even then, point out the identity alternative once.

### Time

- **One source of "now", in UTC.** Capture it once as a variable
  (`static readonly DateTime RunStartedUTC = DateTime.UtcNow;`) and
  use that everywhere. No `DateTime.Now`; convert to local time only
  when formatting output.

---

## Area 3 — Output with `Dump()`

The results pane is the script's only interface. Make it answer the
question the script was written for.

- **Title every dump**: `results.Dump("Missing stations")`. An
  untitled dump of a bare value is not acceptable output.
- **Project before dumping.** Select the columns that matter into an
  anonymous type; drop ids, raw payloads and nested objects nobody
  asked for:
  ```csharp
  users.Select(u => new { u.Email, u.OrganizationName, u.AssignedOn })
       .Dump($"Users in {organization.Name} ({users.Count})");
  ```
- **Dump collections once**, not item by item inside a loop. A
  per-item line is acceptable only as progress for a slow mutation.
- **End with a result.** A summary (counts of succeeded / failed /
  skipped, or the answer itself) is the last thing dumped.
- **Mutations show before and after.** Dump the state before the
  change (titled so the operator can save it for reversal), make the
  change, re-read, dump the after state and a `PASS` / `FAIL` line.
- **Errors are dumped, titled, with the exception type**:
  `$"Fetch failed [{ex.GetType().Name}]: {ex.Message}".Dump($"Error -- {code}")`.
  When a failure leaves data half-changed, title it
  `"RECOVERY NEEDED"` and say exactly how to restore.
- **No `Console.WriteLine`** and no diagnostic dumps (every URI,
  every request body) left in a finished script.

---

## Area 4 — Dry run (`IsDryRun`)

Required for any script that creates, updates or deletes data.

- **Declared in configuration, default `true`**, with a one-line
  comment: `// Preview changes without sending them; set to false only after reviewing the output`.
- **A dry run is a full rehearsal.** Run every read, build every
  payload, decide every change — then dump the planned changes as a
  single titled table (`"DRY RUN -- planned changes"`) instead of
  sending them.
- **Branch once, in `Main()`**, after the plan is built:
  ```csharp
  if (IsDryRun)
  {
      planned.Dump("DRY RUN -- planned changes");
      return;
  }
  ```
- **Guard the write chokepoint too.** Route every write through one
  helper, and have that helper refuse to send when `IsDryRun` is set.
  This catches a write path that bypassed the branch in `Main()`.
- **The summary says which mode ran**, so a dry-run result is never
  mistaken for a committed one.

**Read-only scripts** do not need the flag. Claude adds one, or
recommends it, when a read still carries risk — a large query
against production, an API whose reads have side effects (audit
entries, token revocation), or a rate-limited or metered endpoint.

---

## Area 5 — Method structure and flow

- **Workflow methods are verb-first, domain-action names** describing
  one step: `GetStations`, `BuildPayload`, `MoveUser`, `VerifyMove`.
- **Pass dependencies as parameters.** The `HttpClient`,
  `TableServiceClient` or Cosmos `Container` is created once in
  `Main()` and passed down; methods do not create their own clients.
- **One request helper per backend.** All calls to an API go through
  a single `Send<T>(client, method, route)` helper that adds headers
  (audit `x-user-id`, auth), throws with status code, reason and
  response body on failure, and enforces the dry-run guard.
- **`async Task Main()`** for anything asynchronous. Never `.Wait()`
  or `.Result`. Sequential `await` by default; add a small
  `Task.Delay` between calls when hammering an API one item at a
  time.
- **Per-item work catches and continues.** In a batch loop, catch
  around each item, dump the error with its type, count it, and move
  on. Let a failure that leaves data inconsistent stop the run.
- **Small helpers are expression-bodied** one-liners:
  `static string Literal(string value) => "'" + value.Replace("'", "''") + "'";`

---

## Area 6 — C# style carried over from `jg-code-style`

Scripts follow JG's C# formatting and naming. The architecture
material in `jg-code-style` (layering, DI, composition root, logging
via `ILogger`, test structure, one type per file) does **not** apply
to a single-file script.

**Applies:**

- **Methods under 50 lines**; `Main()` well under that.
- **Comments are one line**, explain *why* not *what*. Two lines
  only for a constraint + example pair. This applies to every comment
  in a script, the description included — a third line is a signal
  to cut, not to keep writing.
- **Always surface the exception type** — `ex.GetType().Name` in
  every dumped error.
- **Naming**: PascalCase methods, types and configuration; camelCase
  locals; **no `Async` suffix**; acronyms fully uppercase (`BaseURL`,
  `ParseJSON`, `ExportCSV`).
- **Types**: positional `record` for API responses and snapshots;
  `class` only when the script mutates the object; enums start with
  `Unknown` or `None` when there is a natural default.
- **XML `///` docs** only on methods whose contract is not obvious
  from the name (e.g., a method that returns `null` after dumping an
  error). One-line `<summary>` by default.
- **Allman braces, blank line between logical phases**, no trailing
  comma in collection initializers. Indentation follows the LINQPad
  editor setting — the editor is this file's formatter.
- **Catch `Exception ex` by default**; catch a specific type
  (`HttpRequestException`, `RequestFailedException`,
  `CosmosException`) only when the script handles it differently.

**Does not apply:** `_camelCase` fields (scripts have no injected
fields), `Func<DateTime>` clock injection (use the captured
`RunStartedUTC` instead), `CancellationToken` threading, log levels.

---

## Not covered here

- **Production tooling.** A script that will run on a schedule, be
  shared as a tool, or grow past a few hundred lines has outgrown
  LINQPad — build it as a console app or a job under `jg-code-style`.
- **`Kind="Expression"` / `Kind="Statements"` scratch queries.**
  Throwaway one-liners typed straight into the editor do not need the
  layout. The standard starts the moment a script is saved to be run
  again.
- **LINQ-to-SQL queries against a LINQPad database connection** —
  the connection, not configuration fields, supplies the target; keep
  the rest of the layout.
- **Other script languages.** The layout (configuration → variables →
  entry point → steps → helpers) and the dry-run discipline transfer
  well to Bash, PowerShell and Python, but this skill's C# rules do
  not. Apply the structure; follow that language's own idiom.

---

## Further Reading

Generic, genericised LINQPad scripts illustrating this standard
(a mutating script with a dry run, a read-only lookup, and common
review fixes):

- `../../code-samples/jg-linqpad-samples-reference.md` (relative to
  this skill's directory)

LINQPad's own documentation on `Dump()` and `Util`:

- https://www.linqpad.net/

If these pages or the samples file are unavailable, the skill remains
complete; the references are supplementary background only.

---

## How to apply this standard in practice

1. **Start with the smallest script** that does the task.
2. **Isolate before adding.** Prefer stubbing or inlining a
   dependency over pulling in more of the host app.
3. **Lay out the skeleton first** — description, `// Configuration`,
   `// Variables`, `Main()`, `// Helpers`, `// Data models` — then
   fill it in.
4. **Touching Azure?** Configure the account name, connect with
   `DefaultAzureCredential`, and add the environment-variable
   break-glass.
5. **Does the script write anything?** Add `IsDryRun = true`, build
   the plan, branch once in `Main()`, and guard the write helper.
6. **Read-only but risky?** Say so, and offer a dry-run flag or a
   row limit.
7. **Before every `Dump()`**, ask what the operator needs to see.
   Title it, project it, and drop the rest.
8. **`Main()` growing a loop or nested branch** → move it into a
   workflow method now.
9. **Reviewing an existing script** → check, in order: inline
   secrets and connection strings, dry-run gate on writes, layout order, lean `Main()`, focused
   titled output, then the C# style in Area 6.
10. **When unsure**, the sections above are the authoritative source.
