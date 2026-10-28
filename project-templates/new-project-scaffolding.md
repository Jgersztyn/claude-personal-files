# Project scaffolding: .NET + React

A template for new apps with a React UI, a .NET API, or both, in JG's preferred architecture. It records the decisions
and rules. Claude writes the code from them and from the jg-code-style skill. This template was created while building
TheDanceDatabase.

To use it, point Claude at this file and say what to create, for example: "Scaffold `TheFooService` with a UI and an
API using `claude-personal-files/project-templates/new-project-scaffolding.md`."

- **Paths to other `claude-personal-files` files are relative to this file.** JG keeps repos under a `Repos`/`repos`
  folder, with `claude-personal-files` beside each project.
- **Full example files** live in `../training-materials/project-scaffolding-examples/`. They are optional reference,
  and this file wins where the two disagree.
- **Last validated 2026-10-23** with create-vite 9.3 (Vite 8, React 19, TypeScript 6.0, ESLint 10), Vitest 5.0, React
  Testing Library 16.3, jsdom 30, .NET SDK 10.0.402 (ASP.NET Core 10.0, xUnit v3 4.0, Scalar 2.18), Docker 29.7 and
  Compose 5.4. Blazor is a placeholder (section 7).

## How Claude should use this file

1. **Run the intake first, in one round, before any other work.** Before asking, Claude may only read the request and
   this file, and check whether the target folder exists and which branch it is on. No version lookups, scratch
   scaffolds or file writes until the answers are in.
   - Fill in what the request states, and propose a value for each input below that it leaves out.
   - Ask everything in one AskUserQuestion call (at most 4 questions), or in one numbered message if that tool isn't
    available, in this order:
     1. **Layout.** Always ask it, even when everything else is known. Header "Layout". The options are "Create as
        container folder with projects" and "Create as standalone API layout" (section 2). Put the recommended one
        first: container for a UI plus an API, standalone for a single .NET service.
     2. **Parts.** Ask only if the request doesn't say. Multi-select: UI, API, Blazor.
     3. **API style.** Ask when the parts include, or might include, an API. Header "API style". The options are
        "Use the defaults (Recommended)" and "Choose each one" (the table in section 4).
     4. **Inputs.** Show every proposed value in the question text. Header "Inputs". The options are "Use these values
        (Recommended)" and "Change some".
   - Allow one follow-up round, and only when an answer requires it: "Choose each one" was picked, corrections weren't
     typed, or a newly added part has unasked questions.
   - Repeat the final values back, then build without waiting. Record the layout and the API style in the repo's
     `CLAUDE.md`. After the intake, ask only about a genuinely new blocker.

   | Input | Proposal when the request doesn't say |
   | --- | --- |
   | Solution name, dotted PascalCase | Derived from the product name |
   | Display name | The solution name split into words |
   | Target folder | `<repos>/<Solution>`, next to `claude-personal-files` |
   | Branch | `feature/setup_<part>` for each part |
   | Code owner | `@Jgersztyn` |
   | UI `<title>` | `<solution>.ui` (lowercased solution name) |

2. **Resolve the path placeholders** in section 2 from the layout answer, and use them everywhere.
3. **The request beats this file.** Say where they conflict, and offer to update this file.
4. **Use the latest stable versions** at scaffold time, not the ones named here. When a newer tool no longer matches a
   step, follow the step's intent, tell JG, and update this file.
5. **Keep the scaffold minimal:** one generic example (one entity, one endpoint, one component). No demo content or
   speculative packages.
6. **Run section 8 before reporting done,** and report each check's result.
7. **Don't commit or push unless asked.**

## 1. Preferences

- **Names:** `<Solution>.<Part>` in dotted PascalCase: `<Solution>.API`, `<Solution>.UI`, `<Solution>.API.UnitTests`,
  `<Solution>.UI.ComponentTests`. The UI is `.UI`, not `.Client`.
- **Branches:** `task/<snake_case>` or `feature/<snake_case>`, with PRs into `main`. UI work and API work go on separate
  branches. Repo-wide work, such as Docker or layout changes, may touch both.
- **Editors:** the UI is built in VS Code, with its settings committed in the UI container. The API is built in Visual
  Studio or Rider.
- **UI:** TypeScript only. The one JavaScript file is `eslint.config.js`. ESLint lints and Prettier formats. Files use
  LF line endings, because JG's machines run git with `core.autocrlf=true` and Prettier fails on CRLF.
- **UI tests:** Vitest with React Testing Library.
- **API:** an ASP.NET Core minimal API on the latest .NET LTS. All C# follows the jg-code-style skill
  (`../skills/jg-code-style/SKILL.md`, samples in `../code-samples/jg-code-samples-reference.md`). Read it before
  writing any C#. It owns layering, naming, logging, comments, testing and type modeling.
  - Where the skill lists an "alternative worth considering", ask about it in the intake. Don't decide it silently.
- **API tests:** xUnit v3 + Shouldly, with hand-written test doubles and no mocking library.
- **Docker:** every app gets an image, and a root `docker-compose.yml` runs them together (section 5).
- **CI/CD:** typically done through Octopus. The scaffold doesn't create the Octopus project. JG sets it up later
  (section 6).

## 2. Repository layout

### Container layout: a repo with more than one app

```
<Solution>/
├── .gitignore, CODEOWNERS, CLAUDE.md, README.md
├── docker-compose.yml
└── src/
    ├── <Solution>.API/                    # <AppRoot>: .NET app root and Docker build context
    │   ├── <Solution>.API.slnx, global.json, Directory.Build.props, Directory.Packages.props
    │   ├── .editorconfig, .dockerignore
    │   ├── <Solution>.API/                # API project, with its Dockerfile
    │   └── <Solution>.API.UnitTests/
    └── <Solution>.UI/                     # <UIRoot>: VS Code workspace and Docker build context
        ├── .vscode/, .gitattributes, .dockerignore
        ├── <Solution>.UI/                 # <UIApp>: the Vite app, with its Dockerfile and nginx.conf
        └── <Solution>.UI.ComponentTests/
```

- **Nothing app-specific at the repo root.** Only repo-wide files live there.
- **Each app's folder is self-contained.** It holds everything its build needs, so it doubles as the app's Docker build
  context.
- **Keep the `.slnx` and each `.csproj` in separate folders.** An SDK-style project compiles every `.cs` file beneath
  it, so a solution in the API project's own folder would compile the tests into the API.
- **The UI container mirrors the API's.** The app and its tests sit side by side. Settings for both (`.vscode/`,
  `.gitattributes`) live in the container.

### Standalone layout: a single independent .NET service

```
<Solution>/
├── .gitignore, .editorconfig, .dockerignore, CODEOWNERS, CLAUDE.md, README.md, docker-compose.yml
├── <Solution>.slnx, global.json, Directory.Build.props, Directory.Packages.props
├── src/<Solution>.API/                    # with its Dockerfile
└── tests/<Solution>.API.UnitTests/
```

The repo root is the app root. Lowercase `tests/` is deliberate, so don't "correct" it to jg-code-style's `Tests/`. If
a UI is added later, move to the container layout.

### Path placeholders

| Placeholder | Container | Standalone |
| --- | --- | --- |
| `<AppRoot>`: run `dotnet` here | `src/<Solution>.API/` | repo root |
| `<SolutionFile>` | `<Solution>.API.slnx` | `<Solution>.slnx` |
| `<ApiProject>`, from `<AppRoot>` | `<Solution>.API/` | `src/<Solution>.API/` |
| `<TestProject>`, from `<AppRoot>` | `<Solution>.API.UnitTests/` | `tests/<Solution>.API.UnitTests/` |
| `<UIRoot>` | `src/<Solution>.UI/` | not used |
| `<UIApp>`: run `npm` here | `src/<Solution>.UI/<Solution>.UI/` | not used |

Run `dotnet` from `<AppRoot>`. The SDK only finds `global.json` by searching upward, so a command run from elsewhere
skips the SDK pin and the test-runner setting.

### Root files

- **`.gitignore`:** run `dotnet new gitignore`. If there is an API, append `appsettings.Local.json`.
- **`CODEOWNERS`:** a global rule for the code owner.
- **`README.md`:** the display name, one sentence on the product, then a short section for each part and for Docker.
- **`CLAUDE.md`:** short. It covers:
  - what the product is;
  - a layout table (path, purpose, editor);
  - the section 1 rules that apply;
  - the commands for each part and for Docker;
  - the CI/CD status;
  - one relative reference to this file, stating only that the repo should be kept in step with it. Don't describe
    the repo by pointing at this file.

## 3. React UI

Run from `<UIApp>` unless stated otherwise.

- **Scaffold:** from `src/`, create `<UIRoot>`. Inside it, run
  `npm create vite@latest <Solution>.UI -- --template react-ts --no-interactive --eslint`, then `npm install` in
  `<UIApp>`.
  - `--eslint` is required, because create-vite 9.3+ generates Oxlint without it.
  - `--no-interactive` avoids prompts that Claude's shell can't answer. It also skips the install.
- **Strip the demo:**
  - Delete `src/App.css`, `src/index.css`, `src/assets/` and `public/icons.svg`, and drop the `index.css` import. Keep
    `public/favicon.svg`.
  - Make `App.tsx` a single `<h1>` with the display name.
  - Run `npm pkg set name=<solution>.ui`, because create-vite would write `<solution>-ui`. Set `<title>` to the
    intake's value.
- **Prettier:** run `npm install -D --save-exact prettier` (even minor releases change output) and `npm install -D
  eslint-config-prettier`.
  - `.prettierignore` lists `dist`, `node_modules` and `coverage`.
  - `.prettierrc` is the decision, so use it exactly:
    ```json
    { "semi": true, "singleQuote": true, "trailingComma": "all", "printWidth": 100 }
    ```
- **ESLint:** a flat config.
  - It extends `@eslint/js` recommended, `typescript-eslint` recommended, `react-hooks` `configs.flat.recommended` and
    `react-refresh` `configs.vite()`.
  - It ignores `dist`, and uses browser globals.
  - `eslint-config-prettier/flat` stays the **last** entry.
  - Check that `npm ls` shows no invalid peers. If create-vite's TypeScript is newer than `typescript-eslint` supports,
    ask JG before downgrading it. After a major version bump, check each plugin's export shape.
  - `react-refresh/only-export-components` is an error, so a file can't export both a component and a helper.
- **Scripts:** add `format` (`prettier --write .`) and `format:check` (`prettier --check .`). Leave the generated ones.
- **Line endings:** `<UIRoot>/.gitattributes` holds `* text=auto eol=lf`, so the app and the tests check out as LF.
- **VS Code:** put `.vscode/` in `<UIRoot>`, the workspace.
  - `settings.json` turns on format on save with Prettier as the default formatter, and
    `"source.fixAll.eslint": "explicit"` on save.
  - It also sets `"eslint.workingDirectories": [{ "mode": "auto" }]`, so ESLint runs from `<UIApp>`.
  - `extensions.json` recommends `dbaeumer.vscode-eslint` and `esbenp.prettier-vscode`.
  - No `.gitignore` rule matches `<UIRoot>/.vscode/`, so don't add un-ignore lines.
- **Component tests:**
  - In `<UIApp>`, run `npm install -D vitest @testing-library/react @testing-library/dom @testing-library/jest-dom
    jsdom`.
  - Create `../<Solution>.UI.ComponentTests/App.test.ts` as an empty placeholder.
  - When the config is written, it must reach outside `<UIApp>`. It needs `server.fs.allow: ['..']` and
    `resolve.dedupe` listing `react`, `react-dom`, `@testing-library/react`, `@testing-library/jest-dom` and `vitest`,
    plus `environment: 'jsdom'` and the React plugin. Without the first two, the test files aren't loaded, and their
    imports don't resolve to `<UIApp>/node_modules`.
  - ESLint, Prettier and `tsc -b` don't cover the test folder until it is wired up with the config.
- **Docs:**
  - Run `npm run format`.
  - Rewrite the generated README. Keep the intro, saying it is "linted by ESLint and formatted by Prettier", and add
    sections for Scripts, Linting and formatting, VS Code, Testing and Docker.
  - Run `npm run format` again.
- **Not included:** routing, state and data fetching. The API's CORS origins must include the Vite dev URL
  (`http://localhost:5173`).

## 4. .NET API

Run from `<AppRoot>`. Generate the code from these rules and jg-code-style.

### Structure

- **Layers:**
  - `Application/` holds the `I*Service` interfaces and request models.
  - `Domain/` holds `Models/`, `Enums/` and `Configuration/` POCOs.
  - `Infrastructure/` holds the implementations.
  - `Presentation/` holds `Endpoints.cs`, with a `MapEndpoints` extension, and `Functions.cs`, a static class of
    handler bodies. They are two files because the skill allows one public type per file.
- **Only create the layers the project needs.** On a new repo, ask whether to use `Persistance`/`Utilties` (the skill's
  deliberate spellings) or the corrected ones.
- **Composition root:** a top-level `Program.cs` that calls two grouped extensions, both in `DependencyInjection.cs` at
  the project root. `AddServices` registers the clock and the application services. `AddPresentation` registers
  OpenAPI, ProblemDetails, health checks, JSON and CORS.
  - `Program.cs` carries `[assembly: InternalsVisibleTo("<Solution>.API.UnitTests")]`.
- **Pipeline:** `UseExceptionHandler`, `UseStatusCodePages`, OpenAPI and Scalar in Development only,
  `UseHttpsRedirection`, `UseCors`, `MapEndpoints`, and `MapHealthChecks("health-check")`.
- **Starting slice:**
  - One entity (singular name, a positional `record`) and an enum whose first member is `Unknown`.
  - One service that returns a few static records and logs one `LogDebug` breadcrumb, under a `// TODO:` to replace
    them with a persisted store.
  - One `GET` endpoint that returns `TypedResults`, so OpenAPI gets the response type.
  - Enums serialize by name (`JsonStringEnumConverter`).
- **CORS:** a `CorsConfig` POCO with `AllowedOrigins` (`string[]`), bound once at startup into a default policy with
  `AllowAnyMethod` and `AllowAnyHeader`. Use `IOptions` plus `IConfigureOptions<CorsOptions>` only if live reload
  matters.
  - `appsettings.json` has an empty list, so production allows nothing until an env var such as
    `CorsConfig__AllowedOrigins__0` sets it.
  - `appsettings.Development.json` adds the Vite dev URL and sets the `<Solution>` log level to `Debug`.
  - Arrays merge by index across settings files.
- **`launchSettings.json`:** `http` and `https` profiles on a port pair no other local project uses, with `launchUrl`
  set to `scalar`. Add a `<Solution>.API.http` file for the endpoint and the health check.

### API style choices (asked in the intake)

| Decision | Default | Alternative |
| --- | --- | --- |
| Clock | `TimeProvider.System` | `Func<DateTime>` (skill default) |
| Constructors | Explicit, with `_camelCase` fields | Primary constructors |
| Config POCOs | `configuration.Bind` + singleton | `IOptions<T>` |
| `MapEndpoints` target | `WebApplication` | `IEndpointRouteBuilder` (more idiomatic in .NET 10; JG hasn't decided) |

Settled, so not asked: named log placeholders, and one `Endpoints.cs` + `Functions.cs` until a second feature arrives.
Then split into one `Map<Feature>Endpoints` per feature.

### Build files

- **`global.json`** pins a real SDK version, because `dotnet` rejects `10.0.x`. It must opt into
  Microsoft.Testing.Platform (MTP), because xUnit v3 4.x runs only on MTP, and the .NET 10 SDK otherwise fails with
  "Testing with VSTest target is no longer supported":
  ```json
  {
    "sdk": { "version": "10.0.400", "rollForward": "latestFeature" },
    "test": { "runner": "Microsoft.Testing.Platform" }
  }
  ```
- **`Directory.Build.props`:** `TargetFramework`, `Nullable` and `ImplicitUsings` for every project.
- **`Directory.Packages.props`:** central package management. Projects reference packages without a version. Use
  PowerShell's `ConvertFrom-Json` on `dotnet package search <id> --exact-match --format json` to find the latest
  versions, because Python isn't installed.
- **`.editorconfig`:** scoped to `*.cs` and the project files, so the UI keeps its own tooling. It sets 4-space
  indents (2 for project files), Allman braces, file-scoped namespaces, PascalCase for private static readonly fields
  and `_camelCase` for other private fields. These rules are IDE-only. Ask before turning on
  `EnforceCodeStyleInBuild` or `TreatWarningsAsErrors`.
- **Don't scaffold with `dotnet new webapi` in the repo.** Every file it creates gets replaced. Use a scratch folder to
  see the current template defaults.

### Local settings

`appsettings.Local.json` holds machine-specific overrides. It is git-ignored, read in Development only, and never
shipped. Environment variables and command-line args must still win, so re-add them after it:

```csharp
if (builder.Environment.IsDevelopment())
{
    builder.Configuration
        .AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true)
        .AddEnvironmentVariables()
        .AddCommandLine(args);
}
```

The API csproj sets `<InvariantGlobalization>true</InvariantGlobalization>`. It also has
`<Content Update="appsettings.Local.json" CopyToOutputDirectory="Never" CopyToPublishDirectory="Never" />`, because the
Web SDK's `**\*.json` glob would otherwise publish the file. Never add the file unconditionally after `CreateBuilder`:
that overrides env vars and ships the file.

### Test project

- **Packages:** `Microsoft.AspNetCore.Mvc.Testing`, `Shouldly` and `xunit.v3`, in a csproj with `OutputType` `Exe` and
  `IsTestProject` `true`, `IsPackable` `false`, and a project reference to the API. Add global `<Using>` entries for
  `Shouldly` and `Xunit`.
  - Leave out `Microsoft.NET.Test.Sdk`, `xunit.runner.visualstudio` and `coverlet.collector`. They are VSTest packages.
  - Run the tests with `dotnet test --solution <SolutionFile>`.
- **Files:**
  - `<Solution>Test` is the base fixture. It builds `AddServices` from in-memory configuration.
  - `<Solution>ApplicationFactory` is a `WebApplicationFactory<Program>` for HTTP tests. It works with top-level
    statements, because .NET 10 generates a public `Program`.
  - Fakes go in `TestDoubles/`.
  - Each feature gets a fixture that swaps in fakes, and a test class that inherits it.
  - Pipeline tests go in `Presentation/EndpointsTests.cs`.
- **Swap fakes in a `ConfigureServices()` hook that runs before the provider is built.** jg-code-style Area 12's
  pattern swaps them in `InitializeAsync` after the build, which leaves the real services in place.
- **Base fixture:**
  - Build the provider with `ValidateScopes = true` and `ValidateOnBuild = true`.
  - Resolve services through `CreateAsyncScope()`.
  - `IAsyncLifetime` returns `ValueTask` in xUnit v3.
  - Pass `TestContext.Current.CancellationToken`.
- **Factory:**
  - Use the `Testing` environment, so developer-local settings are never read.
  - Pin the CORS origin with `UseSetting("CorsConfig:AllowedOrigins:0", ...)`.
  - Keep scope validation on.
- **Exactly three example tests:**
  - A handler unit test that uses a fake.
  - A full-pipeline GET of the endpoint.
  - A CORS test that asserts `Access-Control-Allow-Origin` with `GetValues`, which throws when the header is missing.
- **Worth adding later:**
  - The enum serializes by name.
  - An unknown origin gets no CORS header.
  - The health body is `Healthy`, not just a 200.
  - An unknown route returns a 404 problem+json.
  - `openapi/v1.json` returns 404 outside Development.
  - The unhandled-exception path returns a 500 problem+json.
- **Solution:** `dotnet new sln --format slnx`, then `dotnet sln add` for both projects. The standalone layout gets
  `/src/` and `/tests/` solution folders automatically.

### Docs and not included

- **README:** an API section with the folder tree, a note that `dotnet` runs from `<AppRoot>`, the run and test
  commands, one line per layer, and the `appsettings.Local.json` rule.
- **`CLAUDE.md`:** the same commands, and the jg-code-style rule.
- **Not included:** persistence (EF Core or Cosmos), authentication and logging sinks (Serilog or Datadog). Add them per
  jg-code-style's "Optional / Tool-Specific" section.

## 5. Docker

- **Build context:** each app's folder (`<AppRoot>`, `<UIRoot>`). The Dockerfile sits in the project it builds, and
  compose names it relative to the context.
  - Write each Dockerfile's opening comment as "from the context folder: `docker build -f <Project>/Dockerfile .`".
    `-f` resolves against the current directory, not against the context.
- **`.dockerignore` at each context root.** `.gitignore` doesn't bound a build context. Patterns match from the
  context root, so prefix every pattern with `**/`. A bare `bin/` would miss `<Solution>.API/bin/`.
  - API: `**/bin/`, `**/obj/`, `**/.vs/`, `**/.idea/`, `**/.vscode/`, `**/TestResults/`, `**/*.user` (MSBuild imports
    `.csproj.user` during publish) and `**/appsettings.Local.json`.
  - UI: `**/node_modules/` (it holds Windows-native binaries), `**/dist/`, `.vscode/`, the ComponentTests folder, and
    `**/*.local` (Vite reads `.env.local` at build time).
- **Images:** the latest stable tags, pinned to a major (Node, .NET) or a major.minor (nginx). Node is the current LTS
  that matches JG's local `node --version`. nginx is on the stable (even-numbered) line. Containers listen on 8080 as a
  non-root user.
- **Keep it plain:** no healthchecks, private feeds, secrets or Visual Studio `.dcproj` until a project needs one.
- **API image:** `dotnet/sdk` builds it and `dotnet/aspnet` runs it, with `USER $APP_UID`.
  - Copy `global.json`, `Directory.Build.props`, `Directory.Packages.props` and the csproj first, then restore, then
    copy the source. Without those files, restore has no target framework or package versions.
  - Publish the project, not the `.slnx`, with `--no-restore /p:UseAppHost=false`.
  - The SDK image must satisfy `global.json`'s pin. "A compatible .NET SDK was not found" means the image is older than
    the pin.
- **UI image:** copy `package.json` and `package-lock.json`, run `npm ci`, then copy the source and run
  `npm run build`, so a type error fails the image. `nginx-unprivileged` serves
  `dist/` from a fresh root, so the base image's sample pages are left out. `nginx.conf` sets:
  - `index.html` and client routes (`try_files $uri /index.html`) to `Cache-Control: no-cache`;
  - `/assets/` to `max-age=31536000, immutable`, with `try_files $uri =404`.
- **Compose:** one service per app.
  - Bind ports to `127.0.0.1`.
  - The API reuses its `launchSettings` HTTP port and the UI uses 8080, so the Vite dev server keeps 5173. The API
    container and `dotnet run` can't run at the same time.
  - The API runs in Development locally. It adds the UI container's origin at `CorsConfig__AllowedOrigins__1`, because
    index 0 is the Vite URL from `appsettings.Development.json`.
  - No `depends_on` until the UI calls the API at startup. Add one then, or an nginx proxy for `/api`.
- **Standalone layout:** not yet built. The context is the repo root, with `.dockerignore` at the root and the
  Dockerfile in `src/<Solution>.API/`. Copy and restore paths gain the `src/<Solution>.API/` prefix. Compose uses
  `context: .`. Run the section 8 Docker checks the first time, then update this line.
- **Docs:** add a Docker section to the README and to `CLAUDE.md`, with `docker compose up --build`,
  `docker compose down`, the URLs, and the shared-port note.

## 6. CI/CD (Octopus)

CI/CD is typically done through Octopus Deploy. The scaffold doesn't create the Octopus project or any pipeline file,
because JG creates the project later.

- Record "CI/CD will run through Octopus. No Octopus project exists yet." in `CLAUDE.md`.
- Don't add GitHub Actions, Azure Pipelines or other CI files unless asked.
- The scaffold leaves the pipeline ready to use each Dockerfile, the UI's `format:check`, `lint` and `build`, and
  `dotnet test --solution <SolutionFile>`.
- Once the Octopus project exists, record its name and what it deploys here and in `CLAUDE.md`.

## 7. Blazor (future)

Not written yet. A Blazor app gets its own `src/<Solution>.<Part>/` container. jg-code-style covers Razor: relax the
`_camelCase` rule for component fields, and use code-behind partials. Ask the layout question in the intake for it too.

## 8. Final verification (run before reporting done)

**UI**, from `<UIApp>`:

- `npm ci` and `npm ls` are clean.
- `npm run lint` exits 0. It must fail on a throwaway `.tsx` that calls a hook conditionally
  (`react-hooks/rules-of-hooks`). Delete the file afterwards.
- `npm run format:check` and `npm run build` pass.
- `npm run dev` renders the heading.
- From `<UIRoot>`:
  - `git check-ignore -v .vscode/settings.json` prints nothing.
  - `git check-attr eol <Solution>.UI.ComponentTests/App.test.ts` reports `lf`.

**API**, from `<AppRoot>`:

- **Layout:** the build files sit where the chosen layout puts them.
- **Clean build:** delete `bin/` and `obj/`, then `dotnet build <SolutionFile>` reports 0 warnings and 0 errors.
- **Tests:** `dotnet test --solution <SolutionFile>` passes.
- **Mutation checks:** commenting out the fake swap fails the handler test, and commenting out `app.UseCors()` fails the
  CORS test. Restore both.
- **Run it:** `dotnet run --project <ApiProject> --launch-profile http`, then check:
  - the endpoint returns JSON with enums as names;
  - `/health-check` returns `Healthy`;
  - `/openapi/v1.json` is 200, and `/scalar` is 200 after the redirect;
  - the allowed origin gets `Access-Control-Allow-Origin`, and an unknown origin doesn't;
  - a `dbug:` line appears;
  - stop the process afterwards.
- **Local settings:** use a throwaway `appsettings.Local.json` that sets the `<Solution>` log level to `Information`.
  - The tests still pass.
  - `dotnet publish` output doesn't contain the file.
  - A Development run hides the `dbug:` line.
  - `Logging__LogLevel__<Solution>=Debug` brings the line back.
  - Delete the file afterwards.

**Docker**, from the repo root, with the ports free:

- `docker compose build` and `docker compose up -d` succeed.
- **API:** it repeats the run checks above, and `docker compose exec api id` shows a non-root uid.
- **UI:**
  - `/` returns `index.html` with `no-cache`;
  - a client route returns 200;
  - `/assets/missing.js` returns 404.
- The UI origin and the Vite origin both pass CORS.
- Each Dockerfile's opening-comment `docker build` command runs as written.
- `docker compose down` cleans up.

**Repo:** no demo content is left. `git status` shows no `bin/`, `obj/`, `dist/`, `node_modules/` or `TestResults/`. A
UI-only or API-only branch touches nothing in the other app's folder.
`CLAUDE.md` and the READMEs match what was built.

## 9. Gotchas

- **CRLF breaks Prettier** on Windows with `core.autocrlf=true`. That's why `.gitattributes` exists.
- **The Vite `.gitignore` re-ignores `.vscode/*`.** Keep `.vscode/` in `<UIRoot>`, not in `<UIApp>`.
- **A `?.` before an assertion can't fail.** `x?.Prop.ShouldBe(y)` skips the assertion when `x` is null. Use
  `x.ShouldNotBeNull().Prop.ShouldBe(y)`.
- **Git Bash's `sed -i` rewrites CRLF files as LF,** so every line shows as changed. Use the Edit tool, or re-apply
  CRLF with `sed -i -e 's/\r\?$/\r/'`.
- **Git Bash rewrites container paths** in `docker compose exec api ls /app`. Prefix the command with
  `MSYS_NO_PATHCONV=1`.
- **Moving folders:**
  - A case-only rename on Windows takes two steps (`mv Tests tmp && mv tmp tests`).
  - `git mv` fails with "source directory is empty" once a folder has already been moved. Use `git add -A` to record
    the renames.
  - Close VS Code, Visual Studio and `npm run dev` first. Visual Studio otherwise recreates `obj/` at the old paths.
- **Expected log noise:** the HTTP-only `http` profile and the container both log "Failed to determine the https port
  for redirect".
