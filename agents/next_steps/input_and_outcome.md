# Input and Outcome — UX design agents

- **Status:** Starting point — not yet built. Stored here until JG decides to
  build it; every part is expected to be iterated on.
- **Logged:** 2026-11-10

## Purpose

Take a user-defined concept for something to be built in a UI, together with
the business requirement behind it and the expected outcome, and produce
**full image mocks and complete HTML/CSS and/or Razor** of the UI/UX — a mock
webpage that can be opened in a browser and seen, and code a developer can
read, understand, and put into a project.

This is a different job from today's `ux-design-researcher`, which researches
and audits. It will be split across **two or more agents** (possibly three or
four as the work grows); the researcher's research, inspiration, comparison,
and checklist steps feed the design agent(s).

## Decisions

Recorded 2026-11-10. These replace the original open questions.

| Topic | Decision |
|---|---|
| **Number of agents** | Two at least, possibly three or four. This process does not go into `ux-design-researcher`. |
| **Completeness** | Razor, HTML, and CSS are as complete as possible — working pages and components, not static sketches. |
| **Viewing** | The mock must be a webpage JG can open in a browser and see. |
| **Playwright** | Fine to depend on Playwright to produce results (rendering, screenshots, self-checks). |
| **Writing files** | The agent writes to folders approved in the Claude session — normal permission prompts decide where. |
| **Inspiration & brainstorming** | Web research is used for brainstorming, not only inspiration. **Open inspiration for every idea**, by default, to start with. |
| **Input format** | Free-form; does **not** follow `jg-user-stories`. |
| **Repeatability** | Only when the task asks for it. By default the agent explores freely. |

## Input

What the user provides. The first three are required; the agent states
assumptions for any optional item that is missing (it cannot ask).

| Field | Required | Description | Example |
|---|---|---|---|
| **Concept** | Yes | What needs to be created in the UI. | "A sign-in panel offering Google, Microsoft, and email sign-in." |
| **Business requirement** | Yes | Why it is needed — the business rule or need it serves. | "Customers must be able to sign in with their existing work accounts to reduce password resets." |
| **Expected outcome** | Yes | What success looks like once it is built. | "A user picks a provider and is signed in within two clicks; errors explain what to do next." |
| Audience | No | Who uses it, on what devices. | "Field staff, mostly on phones." |
| Platform & stack | No | Target output and component library. Detected from the project when not given. | "Blazor Server, MudBlazor 7." |
| Existing system | No | Screens, tokens, or brand rules the result must match. | `src/Styles/tokens.css`, screenshots of sibling pages |
| Content & data | No | Real labels, copy, and sample data. | Provider list, error messages |
| States | No | States that must be shown. Defaults to all of: default, loading, empty, error, success, disabled. | — |
| Constraints | No | Anything ruled out. | "No pop-up windows for sign-in." |
| Repeatable | No | Ask for repeatable output (fixed rules, same result each run). Off unless stated. | "Make it repeatable." |

## Outcome

HTML/CSS (or Razor) is the source of truth; the image mocks are rendered from
it, so the images and the code always match.

1. **Ideas** — several distinct design directions from brainstorming, each
   with its own inspiration (see the process below).
2. **Mock webpage** — for the chosen idea (or each idea, if asked), a
   self-contained `.html` file that opens directly in a browser:
   - Complete and working: real layout, every required state reachable
     (e.g. a state switcher), working interactions where they matter.
   - Semantic HTML (`<button>`, `<label>`, `<nav>`), readable class names,
     short comments marking each region.
   - CSS with every colour, size, and spacing value as a CSS custom property,
     named after the project's tokens where they exist.
   - Real content from the input, never lorem ipsum.
3. **Image mocks** — the mock rendered with Playwright and screenshotted at
   phone, tablet, and desktop widths (375×812, 768×1024, 1280×800), once per
   state.
4. **Razor version** — when the stack is Blazor, a complete `.razor`
   component in the detected library (e.g. `MudButton`, `MudTextField`):
   parameters, event callbacks, state handling, and code-behind where it fits
   the project's conventions.
5. **Handoff notes** — a short document that:
   - Traces each part of the business requirement and expected outcome to the
     UI element that satisfies it.
   - Lists the tokens and components used, and any new ones introduced.
   - Lists assumptions made about missing input.
   - Credits the inspiration each idea drew on.
6. **Self-check** — the researcher's Audit checklist run against the rendered
   mock, with Blocking accessibility failures fixed before returning.

All files go to a folder approved in the session, e.g.
`ux-mocks/<concept>/`.

## Proposed process

1. **Read the input** and restate the concept, requirement, and outcome in
   one sentence each. Record assumptions for missing optional fields.
2. **Detect the stack and existing system** (component library, tokens,
   sibling screens).
3. **Brainstorm** — search the web broadly (design galleries, design systems,
   real products, articles) to generate several distinct ideas. Each idea
   gets open inspiration: no site or image caps beyond common sense, and no
   fixed ranking unless the task asks for repeatable output.
4. **Choose** — pick the idea that best meets the business requirement and
   expected outcome, and say why. If the task asks for repeatable output, use
   the researcher's Comparison-mode criteria and ranking rules instead.
5. **Build** the mock webpage for every required state.
6. **Render and self-check** — screenshot with Playwright, run the Audit
   checklist and measurement script on the mock, fix, and repeat until no
   Blocking failures remain.
7. **Translate to Razor** when the stack is Blazor.
8. **Write the handoff notes** and return the folder path and a summary.

## Possible agent split

A first sketch, to be revised as the agents are built:

| Agent | Job |
|---|---|
| `ux-design-researcher` (exists) | Research, inspiration, audits, comparisons. |
| UX brainstormer | Turns the input into several ideas, each with open inspiration. |
| UX mock builder | Builds the mock webpage, renders the images, runs the self-check. |
| Razor translator | Converts the chosen mock into complete Razor in the project's library and conventions. |

Two agents (researcher + designer) is the minimum; the brainstormer and Razor
translator can be split out later if the designer grows too large.

## Notes for later

- **Inspiration limits differ.** The researcher caps inspiration at 10
  images and 6 sites; this process asks for open inspiration per idea. The
  design agent(s) need their own rules, not the researcher's.
- **Login and CAPTCHA handoffs** (IMP-01, IMP-02 in `improvements.md`) would
  matter more here, since open brainstorming reaches more gated sites.
- **Copyright** — inspiration is credited and never copied; the mock uses its
  own assets.
