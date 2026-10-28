# Repo root examples

Copied code from the project-scaffolding template, as proven on 2026-10-23. The template itself records the decisions and rules; these are full example files for reference.

## `.gitignore` addition (append after `dotnet new gitignore` when the project has an API)

```
# Machine-specific API settings
appsettings.Local.json
```

## `CODEOWNERS`

```
# Describe code owners for the <Display name> repository
# This will require approval of the owner(s) for all PR's into the main branch

# Global rule:
*           @Jgersztyn
```
