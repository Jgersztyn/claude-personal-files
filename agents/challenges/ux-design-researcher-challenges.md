# Challenges — ux-design-researcher

Tracks blockers, limitations, and unverified assumptions in
[`../ux_design_researcher.md`](../ux_design_researcher.md), so improvements can
be measured against them.

## How to use this log

- **Add** a row to the index and an entry below it. IDs are never reused.
- **Sources of new entries:** the `## Blockers encountered` section at the end
  of every agent report, and anything found while editing the agent.
- **Update, don't delete.** When something changes, change its status and add
  a dated line to its History. Resolved entries stay as a record.

| Field | Values |
|---|---|
| **Type** | `Blocker` — stops a feature working · `Limitation` — works, with reduced capability · `Unverified` — assumed, not yet tested · `Risk` — could cause wrong or harmful output · `Decision` — open choice for JG |
| **Status** | `Open` · `Mitigated` (workaround in place) · `Resolved` · `Won't fix` (by design) |

## Index

| ID | Title | Type | Status |
|---|---|---|---|
| CH-01 | Measurement script and Tier 1 never executed | Unverified | Open |
| CH-02 | Built-in WebSearch: no engine choice, text results only | Limitation | Mitigated |
| CH-03 | Google search blocked in the browser | Blocker | Won't fix |
| CH-04 | No Brave Search / Google Search API configured | Limitation | Open |
| CH-05 | Bing / DuckDuckGo image search tolerance untested | Unverified | Open |
| CH-06 | Tier 2 fallback cannot render pages | Limitation | Mitigated |
| CH-07 | WebFetch output is model-summarised | Limitation | Mitigated |
| CH-08 | Login-gated inspiration sites (Mobbin, Refero, Page Flows) | Decision | Open |
| CH-09 | Pinterest: sign-up wall, bot blocking, scraping terms | Limitation | Mitigated |
| CH-10 | Inspiration site list and access notes unverified | Unverified | Open |
| CH-11 | Inspiration results are not repeatable | Limitation | Mitigated |
| CH-12 | Inspiration images are others' copyrighted work | Risk | Mitigated |
| CH-13 | Model output is not deterministic | Limitation | Mitigated |
| CH-14 | Measurement script blind spots | Limitation | Mitigated |
| CH-15 | Agent cannot ask the user questions | Limitation | Mitigated |
| CH-16 | Model value `opus[1m]` not in the documented list | Unverified | Resolved |
| CH-17 | `mcp__playwright__*` wildcard in `tools` unverified | Unverified | Mitigated |
| CH-18 | Deployment to `~/.claude/agents/` not recorded | Decision | Open |
| CH-19 | Subfolders of `agents/` would load as agents | Risk | Open |
| CH-20 | Agent capped at 500 lines | Decision | Open |
| CH-21 | Tier 2 `curl` command fails: download folder never created | Blocker | Resolved |
| CH-22 | Windows temp path differs between Git Bash and `Read` | Unverified | Mitigated |
| CH-23 | Tier 1 assumes the MCP server is named `playwright` | Unverified | Open |
| CH-24 | Permission prompts may stall a run | Limitation | Open |
| CH-25 | Is the Playwright browser window visible (headed)? | Unverified | Open |
| CH-26 | Do logins persist between runs? | Unverified | Open |
| CH-27 | User may miss a handoff during a background run | Limitation | Open |
| CH-28 | Handoff wait budget | Decision | Open |
| CH-29 | Repeat CAPTCHAs on the same site | Decision | Open |

---

## CH-01 — Measurement script and Tier 1 never executed

- **Type / Status:** Unverified · Open
- **Detail:** The `browser_evaluate` measurement script and every Playwright
  step have never run. The Linux machine's Playwright MCP failed to start:
  `Chromium distribution 'chrome' is not found at /opt/google/chrome/chrome`.
- **Workaround:** The agent's "Pending: Windows verification" section. Include
  **"Running on Windows"** in the first Windows task and the report opens with
  a pass/fail on Tier 1 and the script.
- **Resolves when:** One Windows run reports Tier 1 loaded and the script
  returned plausible numbers. Then remove the agent's pending section.
- **History:**
  - 2026-11-10 — Logged. Linux test failed on missing Chrome.

## CH-02 — Built-in WebSearch: no engine choice, text results only

- **Type / Status:** Limitation · Mitigated
- **Detail:** `WebSearch` uses a fixed backend that cannot be changed, and
  returns titles, URLs, and snippets — no images. It can be limited to
  specific domains.
- **Workaround:** Image search through Playwright on Bing or DuckDuckGo
  (Tier 1 only). In Tier 2, image discovery is limited to images listed on
  pages found through `WebSearch`.
- **Resolves when:** An image-capable search API is added (see CH-04).
- **History:**
  - 2026-11-10 — Logged.

## CH-03 — Google search blocked in the browser

- **Type / Status:** Blocker · Won't fix
- **Detail:** Google frequently shows a CAPTCHA to automated browsers. The
  agent must never solve or bypass a CAPTCHA, so it is told not to use Google
  search in the browser.
- **Workaround:** Bing and DuckDuckGo image search; `WebSearch`.
- **Resolves when:** Not intended to. A Google Programmable Search API key
  (CH-04) is the legitimate route to Google results.
- **History:**
  - 2026-11-10 — Logged.

## CH-04 — No Brave Search / Google Search API configured

- **Type / Status:** Limitation · Open
- **Detail:** Brave Search has an official API and MCP server; Google offers
  a paid Programmable Search API. Either would give the agent reliable,
  engine-specific (and image) search. Neither is configured. Because the agent
  inherits tools rather than listing them, a new MCP server would be picked up
  without editing the agent.
- **Resolves when:** An API key is obtained and the MCP server configured on
  each machine the agent runs on; the agent's search guidance updated to
  prefer it.
- **History:**
  - 2026-11-10 — Logged.

## CH-05 — Bing / DuckDuckGo image search tolerance untested

- **Type / Status:** Unverified · Open
- **Detail:** The agent assumes Bing and DuckDuckGo image search work in an
  automated browser without a CAPTCHA. This has not been tested, and could
  change at any time.
- **Resolves when:** Confirmed on a Windows run; record any challenge seen.
- **History:**
  - 2026-11-10 — Logged.

## CH-06 — Tier 2 fallback cannot render pages

- **Type / Status:** Limitation · Mitigated
- **Detail:** Without Playwright, the agent cannot render JavaScript or take
  screenshots. Single-page apps, Blazor documentation sites (e.g. MudBlazor's),
  and most galleries return little. Contrast, target size, focus, reflow, and
  text size become `Not measured`.
- **Workaround:** `Not measured — no browser` instead of guessing; component
  docs read from the library's public repository; images downloaded with
  `curl` / `curl.exe` and viewed with `Read`.
- **Resolves when:** Playwright is available on every machine the agent runs
  on (see CH-01).
- **History:**
  - 2026-11-10 — Logged.

## CH-07 — WebFetch output is model-summarised

- **Type / Status:** Limitation · Mitigated
- **Detail:** `WebFetch` returns a model's summary of a page, not the raw
  HTML. Lists of image URLs or exact copy may be incomplete or paraphrased.
- **Workaround:** Tier 1 is preferred for anything exact; Tier 2 is the
  fallback only.
- **History:**
  - 2026-11-10 — Logged.

## CH-08 — Login-gated inspiration sites (Mobbin, Refero, Page Flows)

- **Type / Status:** Decision · Open
- **Detail:** The best sources of real, shipped app screens need an account
  or subscription. The agent's hard rule is never to log in, so it uses only
  their public pages and reports the wall under Blockers encountered.
- **Options for JG:**
  1. Keep the rule; JG supplies screenshots from these sites as local inputs.
  2. Allow a persistent Playwright browser profile in which JG logs in by
     hand once, and relax the no-login rule for named sites only.
- **History:**
  - 2026-11-10 — Logged. Option 1 is the current behaviour by default.

## CH-09 — Pinterest: sign-up wall, bot blocking, scraping terms

- **Type / Status:** Limitation · Mitigated
- **Detail:** Pinterest shows a sign-up wall after a few logged-out results,
  blocks bots, and its terms restrict automated collection. `WebFetch` gets
  almost nothing because the site renders with JavaScript. Pins are often
  low-resolution, unsourced reposts.
- **Workaround:** Light use only (6 sites, 2 searches per site, first page of
  results, 10 images in total); follow each pin to its original source and
  cite that; stop at the wall.
- **History:**
  - 2026-11-10 — Logged.

## CH-10 — Inspiration site list and access notes unverified

- **Type / Status:** Unverified · Open
- **Detail:** The 20 sites in the agent's Inspiration table, and their notes
  ("public", "login or paywall", "live code"), were written from general
  knowledge as of 2026-11 and not checked site by site. Sites change
  ownership, add paywalls, or shut down.
- **Resolves when:** Each site is checked once on Windows; update the
  agent's table and add a line per site to this entry's History.
- **History:**
  - 2026-11-10 — Logged.

## CH-11 — Inspiration results are not repeatable

- **Type / Status:** Limitation · Mitigated
- **Detail:** Gallery and search results change daily, so the Inspiration
  section will differ between runs even for the same task.
- **Workaround:** Every query, site, and date is recorded in the report.
  Inspiration is never evidence and cannot decide a ranking, so the audit and
  comparison results stay repeatable.
- **History:**
  - 2026-11-10 — Logged.

## CH-12 — Inspiration images are others' copyrighted work

- **Type / Status:** Risk · Mitigated
- **Detail:** Dribbble shots, Behance projects, and gallery screenshots belong
  to their creators.
- **Workaround:** Presented as reference only, with original source cited; the
  agent never recommends copying assets; no bulk downloading.
- **History:**
  - 2026-11-10 — Logged.

## CH-13 — Model output is not deterministic

- **Type / Status:** Limitation · Mitigated
- **Detail:** Agent frontmatter has no temperature setting; two runs can
  differ.
- **Workaround:** Repeatability comes from the agent's rules: a fixed
  checklist with IDs, measured thresholds, severities set per check, fixed fix
  rules, fixed ranking rules, fixed viewports, and fixed report formats.
- **Resolves when:** Two runs on the same page and the same day produce the
  same checklist statuses. Record the result here when tested.
- **History:**
  - 2026-11-10 — Logged.

## CH-14 — Measurement script blind spots

- **Type / Status:** Limitation · Mitigated
- **Detail:**
  - Text over background images or gradients cannot be measured
    (`unmeasuredContrast`).
  - Semi-transparent backgrounds are treated as opaque, so ratios over them
    are approximate.
  - Colours in non-`rgb()` formats (e.g. `oklch()`, `color()`) are skipped.
  - Inline links are exempted from the target-size check only when
    `display: inline`.
  - Control and icon contrast (A11Y-02, CMP-03) is judged from screenshots,
    not computed.
- **Workaround:** Unmeasured items are reported as `Not measured`, never
  guessed.
- **Resolves when:** The script is extended (e.g. by injecting the axe-core
  accessibility engine), after CH-01 confirms the basic script works.
- **History:**
  - 2026-11-10 — Logged.

## CH-15 — Agent cannot ask the user questions

- **Type / Status:** Limitation · Mitigated
- **Detail:** Subagents do not get the question tool; they run alone and
  return one report.
- **Workaround:** Hard rule 6 — state assumptions in the report and proceed.
  The calling session can rerun with corrected input.
- **History:**
  - 2026-11-10 — Logged.

## CH-16 — Model value `opus[1m]` not in the documented list

- **Type / Status:** Unverified · Resolved
- **Detail:** The original agent used `model: opus[1m]`, which is not among
  the documented values (`sonnet`, `opus`, `haiku`, `fable`, a full model ID,
  or `inherit`).
- **History:**
  - 2026-11-10 — Changed to `model: opus`. Revisit only if the 1M-token
    context is needed.

## CH-17 — `mcp__playwright__*` wildcard in `tools` unverified

- **Type / Status:** Unverified · Mitigated
- **Detail:** An earlier draft listed `mcp__playwright__*` in `tools`.
  Wildcard support there was not confirmed.
- **Workaround:** The agent uses `disallowedTools: [Edit, Write,
  NotebookEdit]` instead, so it inherits whatever browser and search tools
  each machine has configured.
- **History:**
  - 2026-11-10 — Logged.

## CH-18 — Deployment to `~/.claude/agents/` not recorded

- **Type / Status:** Decision · Open
- **Detail:** Claude Code loads agents from `~/.claude/agents/` (user) or a
  project's `.claude/agents/`. This repo does not record how its files get
  there, on Linux or on Windows.
- **Resolves when:** JG chooses a mechanism (copy, symlink, script) and it is
  documented in `CLAUDE.md`.
- **History:**
  - 2026-11-10 — Logged.
  - 2026-11-10 — Options reviewed. There is no setting that registers an
    agent from an arbitrary file path; agents are found only in
    `~/.claude/agents/`, a project's `.claude/agents/`, an installed plugin,
    or inline JSON via `--agents`. Options: (1) copy the file; (2) link it
    (symlink or Windows hard link — whether Claude Code follows links there
    is unverified); (3) package this repo as a Claude Code plugin and install
    it on each device; (4) ad hoc, ask Claude to read the file and use its
    body as a general-purpose subagent's prompt — frontmatter (model, tool
    limits) and auto-delegation are lost.

## CH-19 — Subfolders of `agents/` would load as agents

- **Type / Status:** Risk · Open
- **Detail:** Claude Code scans an agents directory's subfolders recursively.
  If this repo's whole `agents/` folder is copied or symlinked into
  `~/.claude/agents/`, then any draft agent files in `next_steps/` (files
  with agent frontmatter) load as real agents, and drafts sharing a `name`
  load only once. This log and the `next_steps/` documents would also be
  scanned (no frontmatter, so not expected to load as agents).
- **Resolves when:** Deployment (CH-18) copies only `agents/*.md`, or the
  subfolders move outside `agents/`.
- **History:**
  - 2026-11-10 — Logged. Also tracked in `../next_steps/improvements.md`. JG's
    decision: keep `temp/` and `challenges/` in place for now.
  - 2026-11-10 — `temp/` renamed to `next_steps/`; this log renamed to
    `ux-design-researcher-challenges.md`. Both folders stay under `agents/`.

## CH-20 — Agent capped at 500 lines

- **Type / Status:** Decision · Open
- **Detail:** JG set a limit of 500 lines for `ux_design_researcher.md`. The
  body loads into the agent's context on every run, so length costs
  attention and tokens. JG may change this limit later.
- **What was condensed (535 → 494 lines):** prose only — the description,
  the intro, the hard-rule wording, component-library detection, Tier 2
  steps, writing fixes, the comparison procedure, and the inspiration
  "group order" list (folded into one line) and "promoting to a candidate"
  (folded into the limits list). No checks, criteria, thresholds, sites,
  limits, or report sections were removed; the measurement script is
  unchanged.
- **If more room is needed:** the measurement script (~40 lines) and the two
  report templates (~100 lines) are the largest blocks. Options: move the
  script or templates to a companion reference file (as the skills do), or
  raise the limit.
- **History:**
  - 2026-11-10 — Logged. Condensed to 494 lines.
  - 2026-11-10 — Now 496 lines after CH-21/CH-22 fixes. Proposed IMP-01 and
    IMP-02 (`../next_steps/improvements.md`) need roughly 25–35 more lines, so
    this limit must be revisited before they are built.

## CH-21 — Tier 2 `curl` command fails: download folder never created

- **Type / Status:** Blocker · Resolved
- **Detail:** The Tier 2 download command writes to `.../ux-research/<name>`
  but nothing creates `ux-research/` first, so `curl` fails on the first
  download on every platform.
- **Resolves when:** `--create-dirs` is added to the command (supported by
  `curl` and `curl.exe`).
- **History:**
  - 2026-11-10 — Found during Windows-readiness review.
  - 2026-11-10 — Fixed: `--create-dirs` added to the Tier 2 command.

## CH-22 — Windows temp path differs between Git Bash and `Read`

- **Type / Status:** Unverified · Mitigated
- **Detail:** On Windows, Claude Code's Bash tool runs Git Bash, where
  `${TMPDIR:-/tmp}` is a Unix-style path. The `Read` tool may need the Windows
  form (`C:\Users\...\AppData\Local\Temp\...`) to open the downloaded image.
- **Resolves when:** A Windows Tier 2 run downloads an image and `Read`
  opens it.
- **History:**
  - 2026-11-10 — Found during Windows-readiness review.
  - 2026-11-10 — Mitigated: the agent now always uses PowerShell and
    `$env:TEMP` on Windows, and falls back to Bash with `cygpath -w` only when
    PowerShell is unavailable. Still untested on Windows.

## CH-23 — Tier 1 assumes the MCP server is named `playwright`

- **Type / Status:** Unverified · Open
- **Detail:** MCP tool names take the server's configured name as a prefix.
  The agent looks for `mcp__playwright__*`; a server registered under another
  name produces different tool names, and the agent may fall back to Tier 2
  without noticing Playwright is present.
- **Resolves when:** Confirmed with `/mcp` on Windows that the server is named
  `playwright`, or the agent is told to look for any `browser_navigate` tool
  regardless of prefix.
- **History:**
  - 2026-11-10 — Found during Windows-readiness review.

## CH-24 — Permission prompts may stall a run

- **Type / Status:** Limitation · Open
- **Detail:** Playwright tools, `WebFetch` (asked per domain), and `curl`
  may each prompt for permission. An Inspiration run can touch 6 or more
  domains, so a run can pause repeatedly waiting for approval.
- **Resolves when:** The needed tools and domains are allowed in Claude Code
  settings on each machine, or the prompts are judged acceptable.
- **History:**
  - 2026-11-10 — Found during Windows-readiness review.

## CH-25 — Is the Playwright browser window visible (headed)?

- **Type / Status:** Unverified · Open
- **Detail:** The login and CAPTCHA handoffs (IMP-01, IMP-02 in
  `../next_steps/improvements.md`) show their prompt inside the browser window. That
  only works if Playwright MCP runs headed, not with `--headless`.
- **Resolves when:** Confirmed on Windows that a browser window appears when
  the agent navigates.
- **History:**
  - 2026-11-10 — Logged from IMP-01/IMP-02 open questions.

## CH-26 — Do logins persist between runs?

- **Type / Status:** Unverified · Open
- **Detail:** With a persistent browser profile, the user logs in to each site
  once and later runs reuse the session. With an isolated profile, every run
  asks again. The Playwright MCP profile setting on Windows is unknown.
- **Resolves when:** Log in to one site, start a new run, and check whether
  the site still shows as logged in.
- **History:**
  - 2026-11-10 — Logged from IMP-01 open questions.

## CH-27 — User may miss a handoff during a background run

- **Type / Status:** Limitation · Open
- **Detail:** If the agent runs in the background, a browser window asking
  for a login or CAPTCHA may go unnoticed until the 3-minute timeout. A
  Windows toast notification from PowerShell is a possible addition, untested.
- **Resolves when:** A notification method is chosen and tested, or the
  timeout alone is judged acceptable.
- **History:**
  - 2026-11-10 — Logged from IMP-01 open questions.

## CH-28 — Handoff wait budget

- **Type / Status:** Decision · Open
- **Detail:** Each handoff waits up to 3 minutes. Proposed caps: at most 2
  login handoffs and 3 CAPTCHA handoffs per run, so a run waits at most 15
  minutes. Walls beyond the cap are skipped automatically.
- **Options for JG:** accept the proposed caps, change them, or use a single
  total wait budget per run instead.
- **History:**
  - 2026-11-10 — Logged from IMP-01/IMP-02 open questions.

## CH-29 — Repeat CAPTCHAs on the same site

- **Type / Status:** Decision · Open
- **Detail:** A site may challenge again after the user solved its CAPTCHA.
  Proposed: skip that site for the rest of the run rather than ask again.
- **Options for JG:** accept, or allow one repeat per site within the wait
  budget (CH-28).
- **History:**
  - 2026-11-10 — Logged from IMP-02 open questions.
