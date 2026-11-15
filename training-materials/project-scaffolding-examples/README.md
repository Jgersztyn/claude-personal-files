# Project scaffolding examples

These are full example files for `../../project-templates/new-project-scaffolding.md`. They were moved out of the template on 2026-10-23, when it was condensed into a document of decisions and rules. They come from TheDanceDatabase, the app the template was built with, and they passed that project's build, tests, reviews and Docker run.

They are reference material, not part of the template. Claude generates each project's code from the template's rules and the jg-code-style skill. Use these files only to check a detail. Where an example and the template disagree, the template wins. This folder may be removed later.

| File | Contents |
| --- | --- |
| `repo.md` | `.gitignore` addition, `CODEOWNERS` |
| `ui.md` | Vite scaffold commands, Prettier and ESLint config, `.gitattributes`, VS Code settings, test packages |
| `api.md` | Build files, csproj, `Program.cs`, DI, settings, the sample slice, the test project, solution commands |
| `docker.md` | Both Dockerfiles, `nginx.conf`, both `.dockerignore` files, `docker-compose.yml` |
