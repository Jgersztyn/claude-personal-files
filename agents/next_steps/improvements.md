# Improvements

Work in progress. Planned improvements to the agents in this folder's parent.

## CH-19 — Subfolders of `agents/` would load as agents

- **Agent:** `ux-design-researcher` (and any future agent in `agents/`)
- **Logged:** 2026-11-10 · full entry in
  [`../challenges/ux-design-researcher-challenges.md`](../challenges/ux-design-researcher-challenges.md#ch-19--subfolders-of-agents-would-load-as-agents)
- **Problem:** Claude Code scans an agents directory's subfolders
  recursively. If the whole `agents/` folder is copied or symlinked into
  `~/.claude/agents/`, any draft agent files in `next_steps/` (files with
  agent frontmatter) load as real agents, and drafts sharing a `name` load
  only once. `challenges/` and this file would also be scanned (no
  frontmatter, so not expected to load as agents).
- **Constraint:** `next_steps/` (formerly `temp/`) and `challenges/` stay
  under `agents/` for now — not deleted or moved out.
- **Improvement:** When deployment is set up (CH-18), copy only
  `agents/*.md`, not the subfolders.

## IMP-01 — Hand login walls to the user, with a timeout

- **Agent:** `ux-design-researcher`
- **Logged:** 2026-11-10 · Status: Proposed
- **Relates to:** CH-08 (login-gated sites), CH-09 (Pinterest), CH-24
  (permission prompts)
- **Goal:** When a site needs a login (Mobbin, Refero, Page Flows, Pinterest),
  pause, let the user log in by hand, then continue. If the user does not
  respond within **3 minutes**, give up on that site and move on.
- **Why it has to happen in the browser:** subagents cannot ask the user
  questions — they have no question tool and their reasoning is not shown
  while they run. The Playwright browser window is the only thing the user
  sees mid-run, so the "popup" is shown there.
- **Proposed flow:**
  1. The agent hits a login wall on a site.
  2. It injects an overlay into the page with `browser_evaluate`:
     *"ux-design-researcher needs you to log in to <site>. Log in in this
     window, then click **Continue**. Click **Skip** to move on. Skipping
     automatically in 3:00."* — with a visible countdown.
  3. The buttons set a flag on the page (e.g. `window.__uxHandoff =
     'continue' | 'skip'`). The agent polls it every ~15 seconds with
     `browser_evaluate` / `browser_wait_for`. The overlay is re-injected if
     the login redirects to another page.
  4. **Continue** → the agent reloads the original page and resumes.
     **Skip** or **3 minutes with no response** → recorded under Blockers
     encountered, and the agent moves to the next site.
- **Trigger to turn it off:** if the task message contains **"Skip logins"**,
  the agent behaves as today — treat the wall as a blocker and move on, with
  no overlay and no wait.
- **Rules to keep:**
  - The agent never types, sees, or stores credentials. It takes no
    screenshots or snapshots while the overlay is up.
  - The user logs in; the agent only waits. This replaces hard rule "Never
    log in" with "Never enter credentials yourself".
  - Never submit real data or change account settings after login.
- **Open questions** (logged as CH-25 to CH-28 and CH-20 in
  `../challenges/ux-design-researcher-challenges.md`):
  - **Is the Playwright browser visible?** The flow needs Playwright MCP
    running headed (not `--headless`). Confirm on Windows.
  - **Does the login persist?** With a persistent browser profile the user
    logs in once per site, not every run. Confirm the Playwright MCP profile
    setting on Windows.
  - **Will the user notice?** If the agent runs in the background, a window
    appearing may be missed. Consider a Windows toast notification from
    PowerShell as well — untested.
  - **Wait budget:** several walls × 3 minutes can stall a run. Proposed cap:
    at most 2 login handoffs per run; later walls are skipped automatically.
  - **Line budget (CH-20):** the agent is at 496 of 500 lines. IMP-01 and
    IMP-02 together need roughly 25–35 lines; something must move to a
    companion file or the limit must change.

## IMP-02 — Hand CAPTCHAs to the user, with a timeout and fallback route

- **Agent:** `ux-design-researcher`
- **Logged:** 2026-11-10 · Status: Proposed
- **Relates to:** CH-03 (Google CAPTCHA, currently Won't fix), CH-05
  (Bing/DuckDuckGo tolerance)
- **Goal:** When a CAPTCHA appears, ask the user to solve it in the browser
  window. If no response within **3 minutes**, continue by another route.
- **Proposed flow:** the same overlay and polling as IMP-01, with the text
  *"Please solve the check in this window, then click Continue."*
- **Fallback route when skipped or timed out**, in order:
  1. The same query on the next search engine (Google → Bing → DuckDuckGo).
  2. `WebSearch` limited to the site's domain, then Tier 2 for the page.
  3. The next site in the same inspiration group.
  4. Record under Blockers encountered.
- **Trigger to turn it off:** **"Skip CAPTCHAs"** in the task message goes
  straight to the fallback route with no overlay. **"No user prompts"**
  turns off both IMP-01 and IMP-02.
- **Rules to keep:**
  - The agent never attempts to solve a CAPTCHA itself, and never uses a
    solving service or any other bypass — only the user solves it.
  - Hard rule wording changes from "never solve a CAPTCHA" to "never solve or
    bypass a CAPTCHA yourself; you may hand it to the user".
  - Some sites prohibit automated access even when a human clears the check;
    respect that, and keep the existing per-site limits.
- **Effect on CH-03:** Google in the browser becomes possible with the user's
  help, so CH-03 could move from Won't fix to Mitigated.
- **Open questions** (logged as CH-28 and CH-29 in
  `../challenges/ux-design-researcher-challenges.md`):
  - **Wait budget:** proposed cap of 3 CAPTCHA handoffs per run; shared
    across IMP-01 and IMP-02, total waiting would be at most 15 minutes.
  - **Repeat CAPTCHAs:** if the same site challenges again after the user
    solved it, skip it for the rest of the run rather than asking again.

## IMP-03 — "Use Tier 2" trigger phrase

- **Agent:** `ux-design-researcher`
- **Logged:** 2026-11-10 · Status: **Done** — added to the agent 2026-11-10
- **Relates to:** CH-06 (Tier 2 limits), CH-22 (Windows temp path)
- **Goal:** Let the user force the fetch/download fallback even when
  Playwright is available, so Tier 2 can be tested on demand.
- **Why:** The agent picks Tier 1 whenever Playwright tools exist. The only way
  to test Tier 2 today is to ask it to "skip the browser", which it has no
  rule for and may not follow reliably.
- **Proposed change** — one line in the agent's "Choosing a browsing method"
  section:
  *If the task message contains **"Use Tier 2"**, skip Tier 1 entirely, even
  if Playwright tools are available, and record "Tier 2 (forced)" in the
  report.*
- **Line budget:** +2 lines (496 → 498), within the 500-line limit (CH-20).
