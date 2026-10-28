# UI examples (Vite + React + TypeScript)

Copied code from the project-scaffolding template, as proven on 2026-10-23. The template itself records the decisions and rules; these are full example files for reference. `<Solution>` is the solution name in dotted PascalCase, and `<solution>` is the same name lowercased.

## Scaffold commands, run from `src/`

```
mkdir <Solution>.UI
cd <Solution>.UI
npm create vite@latest <Solution>.UI -- --template react-ts --no-interactive --eslint
cd <Solution>.UI
npm install
```

## Prettier install

```
npm install -D --save-exact prettier
npm install -D eslint-config-prettier
```

## `.prettierrc`

```json
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100
}
```

## `.prettierignore`

```
dist
node_modules
coverage
```

## `eslint.config.js`

```js
import js from '@eslint/js';
import eslintConfigPrettier from 'eslint-config-prettier/flat';
import reactHooks from 'eslint-plugin-react-hooks';
import { reactRefresh } from 'eslint-plugin-react-refresh';
import { defineConfig, globalIgnores } from 'eslint/config';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      js.configs.recommended,
      tseslint.configs.recommended,
      reactHooks.configs.flat.recommended,
      reactRefresh.configs.vite(),
    ],
    languageOptions: {
      globals: globals.browser,
    },
  },
  eslintConfigPrettier, // keep last so Prettier owns formatting
]);
```

## Format scripts

```
npm pkg set scripts.format="prettier --write ." scripts.format:check="prettier --check ."
```

## `.gitattributes` (in the UI container)

```
# Keep LF line endings on checkout so Prettier's default endOfLine ("lf") matches on every OS,
# including Windows with core.autocrlf=true.
* text=auto eol=lf
```

## `.vscode/settings.json` (in the UI container)

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": { "source.fixAll.eslint": "explicit" },
  "eslint.workingDirectories": [{ "mode": "auto" }]
}
```

## `.vscode/extensions.json` (in the UI container)

```json
{
  "recommendations": ["dbaeumer.vscode-eslint", "esbenp.prettier-vscode"]
}
```

## Component test packages and placeholder, run from the Vite app

```
npm install -D vitest @testing-library/react @testing-library/dom @testing-library/jest-dom jsdom
mkdir ../<Solution>.UI.ComponentTests
touch ../<Solution>.UI.ComponentTests/App.test.ts
```

