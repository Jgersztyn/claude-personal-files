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
- **Logged:** 2026-11-10 · Reworked 2026-11-15 · Status: Tried by hand, not
  yet written into a skill or agent
- **Relates to:** CH-08 (login-gated sites), CH-09 (Pinterest), CH-26 (login
  persistence), CH-28 (wait budget)
- **Goal:** Let the user sign in to walled sites (Pinterest, CodePen, Mobbin,
  Refero) so the agent can search them, without the agent ever handling a
  credential.
- **Where it runs:** in the **calling session, before the agent starts**. The
  agent itself still stops at a wall and lists it under Logins needed.
- **Flow**, as it worked on 2026-11-15 (Linux, Pinterest):
  1. The calling session opens the site's login page in the Playwright
     browser and tells the user to sign in there.
  2. It watches **only the page address** until it leaves the login path. It
     takes no screenshot or snapshot while the user signs in.
  3. Each wait is capped **under two minutes**. A wait of 120 seconds or more
     gets moved to the background by the harness.
  4. An address change is not proof. The session confirms by loading a search
     on the site and checking that results show with no wall.
  5. Not confirmed in time → the site stays under Logins needed and the run
     goes ahead without it.
- **Things to expect:**
  - Signing in with Google can open an extra verification tab, so a hand-off
    can involve more than one tab.
  - The login carried into the next agent run in the same session. Whether it
    survives a restart is untested (CH-26).
- **Rules to keep:**
  - Nobody but the user types, sees, or stores a credential.
  - Once signed in, the agent follows its signed-in rule (hard rule 14):
    capture the design only, never account chrome, and never save, like,
    follow or comment.
- **Open questions:**
  - Where the hand-off steps live: a skill, or a note for the calling
    session. Not decided.
  - How many hand-offs per run (CH-28).
- **Superseded design (2026-11-10):** the agent injected an overlay into the
  page mid-run, with Continue and Skip buttons, a 3-minute countdown, and
  polling of a page flag. Dropped because the hand-off before the run needs
  no overlay and no change to the agent. Its open questions were logged as
  CH-25 to CH-28.

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
