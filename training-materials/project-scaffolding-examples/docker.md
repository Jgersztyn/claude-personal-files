# Docker examples

Copied code from the project-scaffolding template, as proven on 2026-10-23. The template itself records the decisions and rules; these are full example files for reference. `<Solution>` is the solution name in dotted PascalCase, and `<solution>` is the same name lowercased.

## API `Dockerfile` (in the API project)

```dockerfile
# syntax=docker/dockerfile:1
# Build context is src/<Solution>.API, the folder that holds global.json and the shared props files.
# From that folder: docker build -f <Solution>.API/Dockerfile .
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore needs the SDK pin, the target framework and the central package versions, not only the csproj
COPY global.json Directory.Build.props Directory.Packages.props ./
COPY <Solution>.API/<Solution>.API.csproj <Solution>.API/
RUN dotnet restore <Solution>.API/<Solution>.API.csproj

COPY <Solution>.API/ <Solution>.API/
RUN dotnet publish <Solution>.API/<Solution>.API.csproj -c Release -o /app/publish --no-restore /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .

# The base image listens on 8080 (ASPNETCORE_HTTP_PORTS) and provides the non-root APP_UID user
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "<Solution>.API.dll"]
```

## API `.dockerignore` (in `<AppRoot>`)

```
**/bin/
**/obj/
**/.vs/
**/TestResults/
**/.idea/
**/.vscode/
**/*.user

# Git-ignored, but .gitignore does not bound a build context; keep developer overrides out of the image
**/appsettings.Local.json
```

## UI `Dockerfile` (in the Vite app)

```dockerfile
# syntax=docker/dockerfile:1
# Build context is src/<Solution>.UI, the UI's container folder, to match the API.
# From that folder: docker build -f <Solution>.UI/Dockerfile .
FROM node:24-alpine AS build
WORKDIR /src

COPY <Solution>.UI/package.json <Solution>.UI/package-lock.json ./
RUN npm ci

COPY <Solution>.UI/ ./
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.30-alpine AS final
COPY <Solution>.UI/nginx.conf /etc/nginx/conf.d/default.conf

# A fresh root keeps the base image's sample pages out of the site
COPY --from=build /src/dist /usr/share/nginx/ui
EXPOSE 8080
```

## `nginx.conf` (in the Vite app)

```nginx
server {
    listen 8080;
    root /usr/share/nginx/ui;

    # index.html names the fingerprinted bundles, so a cached copy would pin browsers to an old build
    location = /index.html {
        add_header Cache-Control no-cache;
    }

    # Vite fingerprints everything under assets/, and a missing file must 404 rather than return index.html
    location /assets/ {
        add_header Cache-Control "max-age=31536000, immutable";
        try_files $uri =404;
    }

    # Any other path is a client-side route
    location / {
        add_header Cache-Control no-cache;
        try_files $uri /index.html;
    }
}
```

## UI `.dockerignore` (in the UI container)

```
**/node_modules/
**/dist/
.vscode/
<Solution>.UI.ComponentTests/

# Vite reads .env.local files at build time; keep developer overrides out of the image
**/*.local
```

## `docker-compose.yml` (repo root)

```yaml
# Runs the API and the UI in containers: docker compose up --build
# Ports bind to 127.0.0.1 only, because the API runs in Development with Scalar exposed
services:
  api:
    build:
      context: src/<Solution>.API
      dockerfile: <Solution>.API/Dockerfile
    ports:
      - "127.0.0.1:5185:8080"
    environment:
      ASPNETCORE_ENVIRONMENT: Development
      # Index 0 is the Vite dev server from appsettings.Development.json; this adds the ui container
      CorsConfig__AllowedOrigins__1: http://localhost:8080

  ui:
    build:
      context: src/<Solution>.UI
      dockerfile: <Solution>.UI/Dockerfile
    ports:
      - "127.0.0.1:8080:8080"
```

