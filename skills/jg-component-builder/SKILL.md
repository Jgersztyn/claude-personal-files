---
name: jg-component-builder
description: Turn a finished HTML mock page (such as one written by the ux-design-researcher agent, "the RXer") into real UI code built from a component library — MudBlazor (Blazor) or MaterialUI (React). Maps each region of the mock to the library's own components at the project's installed version, moves the mock's CSS tokens into the theme, wires every state, and reports what could not be matched. Use when the user has an HTML mock or prototype and wants it built for real, and especially when the user references "build this mock", "convert the mock", "component builder", or "turn the HTML into MudBlazor / MaterialUI".
---

# JG Component Builder

Builds real UI from one HTML mock. The mock is the specification; this
skill translates it into the project's component library without
redesigning it. This skill is self-contained — the standard is stated
inline.

---

## When to apply this skill

- The user points at an HTML mock (usually `ux-research/<slug>/mocks/<n>-<name>.html`)
  and asks for it to be built in MudBlazor or MaterialUI.
- The user asks to "convert", "port" or "build" a prototype into a
  Blazor or React project that uses one of those libraries.

---

## Hard rules (never skip)

These are non-negotiable. If something here conflicts with the rest
of the document, the hard rule wins.

1. **One named mock is the input.** If the request names no mock, or
   several, ask which one. Never design a screen from scratch here —
   that is the RXer's job.
2. **The target library is named or detected, never assumed.** Use the
   library the request names; otherwise the one the project already
   references. If it is neither MudBlazor nor MaterialUI, stop and say
   so.
3. **Check the docs before using a component.** For every component
   and parameter, read the library's documentation for the project's
   installed version. Never write a component API from memory.
4. **The mock is the spec.** Keep its layout, content, states and
   behaviour. Do not redesign it. Where the library cannot match the
   mock, use the library's nearest standard behaviour and list the
   difference under Deviations.
5. **Reuse before adding.** Use the project's existing components,
   layout, theme and services wherever one does the job. Duplicate
   none.
6. **No new package without asking.** Name it and the reason, and
   wait for a yes.
7. **No invented data.** Every value shown and every action gets a
   named source — an existing service, endpoint or model — or is
   listed as new work. Never invent an endpoint.
8. **Theme values, not raw values.** Colours, spacing and type come
   from the theme. A raw hex or pixel value in a component is a
   defect.
9. **Verify with the project's own build.** Run the build the project
   already uses. Do not start a dev server unless asked.
10. **C# follows `jg-code-style`.** That includes leaving the
    `Persistance/` and `Utilties/` folder spellings alone.

---

## Area 1 — Read the mock

Read the whole HTML file before touching the project, and write down:

- **Regions** — the page's structural parts (top bar, main area, side
  panel, footer bar) and how they sit at each width.
- **Controls** — every button, input, slider, list and toggle, with
  its label and what it does in the mock's script.
- **States** — every state the mock can show (default, loading,
  empty, error, playing / stopped, panel open / closed).
- **Tokens** — the CSS custom properties on `:root`: colours, spacing,
  radii, type sizes.
- **Requirements** — if `research.md` sits beside the `mocks/` folder,
  read its `REQ-n` list. Every one must survive the translation.

The mock's "Inspired by" footer and its reference images are
background. They are not part of the build.

---

## Area 2 — Detect the library and the existing system

1. Find the library and version: search `**/*.csproj` for `MudBlazor`
   and `**/package.json` for `@mui/material` (skip `node_modules`,
   `bin`, `obj`).
2. Find what already exists and will be reused: the theme, the shared
   layout, the navigation, sibling screens, and the services and
   models the new screen will touch.
3. Decide where the new files go, following the project's existing
   folder layout.

---

## Area 3 — Map the mock to components

Write a map of every region and control to a library component
before writing code. These are starting points only; confirm each
against the docs for the installed version (hard rule 3).

| In the mock | MudBlazor | MaterialUI |
|---|---|---|
| Top bar | `MudAppBar` | `AppBar` |
| Side panel | `MudDrawer` | `Drawer` |
| Button, toggle button | `MudButton`, `MudIconButton` | `Button`, `IconButton` |
| Range input | `MudSlider` | `Slider` |
| Search with suggestions | `MudAutocomplete` | `Autocomplete` |
| Text field | `MudTextField` | `TextField` |
| List of items | `MudList` | `List` |
| Card | `MudCard` | `Card` |

- A region with no library equivalent (a map, a chart, a canvas) is a
  plain element or an existing project component, wrapped by the
  library's layout.
- Prefer a component's own parameters over custom CSS. Custom CSS is
  the last resort and is listed under Deviations.

---

## Area 4 — Theme and tokens

- Match each mock token to an existing theme value first.
- A token with no match is proposed as a theme addition (the
  project's `MudTheme`, or its MaterialUI theme object) — never
  pasted into a component.
- If the project ships more than one theme (for example dark), the
  screen must work in each.

---

## Area 5 — States and data

- Build every state from Area 1. A state the mock shows and the code
  cannot reach is a defect.
- Replace the mock's sample data with the named source for each
  value (hard rule 7).
- Keep the mock's labels word for word unless the project already
  has a term for the same thing.

---

## Area 6 — What to report

End with:

- **Built from:** the mock's path, the library and its version.
- **Component map:** the Area 3 map as built.
- **Files:** each file added or changed.
- **Deviations:** each place the result differs from the mock, and
  why.
- **New work:** data sources, theme values or packages that do not
  exist yet.
- **Build:** the command run and its result.

---

## Not covered here

- **Research, reference images and HTML mocks.** The
  `ux-design-researcher` agent produces these.
- **Auditing the built screen.** The `ux-auditor` agent does this,
  against a running page.
- **Other component libraries.** The process transfers; the component
  map does not.
- **Backend work.** New endpoints and services are listed under New
  work, not built here.

---

## Further Reading

- MudBlazor documentation: https://mudblazor.com/
- MaterialUI documentation: https://mui.com/material-ui/
- `../../skills/jg-code-style/SKILL.md` (relative to this skill's
  directory) for the C# in any Blazor component.

This skill has no companion reference yet. If these pages are
unavailable, the skill remains complete; the references are
supplementary background only.

---

## How to apply this standard in practice

1. **No mock named, or more than one** → ask which.
2. **Read the mock first** — regions, controls, states, tokens.
3. **Find the library, its version and what the project already
   has.**
4. **Write the component map**, checking each component in the docs.
5. **Map tokens to the theme** before writing any markup.
6. **Build every state**, with a named data source for each value.
7. **Run the project's build.**
8. **Report** the map, files, deviations and new work.
9. **When unsure**, the sections above are the authoritative source.
