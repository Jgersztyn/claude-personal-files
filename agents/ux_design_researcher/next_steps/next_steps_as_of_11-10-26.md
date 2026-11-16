# Next steps — as of 2026-11-10

## Pick up here

Session of 2026-11-10 rebuilt the `ux-design-researcher` agent and started
logs for its challenges and future work. **Nothing is committed — on purpose.**
JG wants to run tests first. Do not commit until JG says so.

To resume: read this file, then `../challenges/ux-design-researcher-challenges.md`
(index at the top), then whichever file the next step points to.

## Where things stand

| File | State |
|---|---|
| `agents/ux_design_researcher.md` | Modified, uncommitted. 498 lines (limit 500, CH-20). Audit + Comparison modes, Inspiration add-on, component-library detection, Playwright Tier 1 with fetch/download Tier 2, measurement script, fixed checklist and report formats, Windows verification trigger. |
| `agents/challenges/ux-design-researcher-challenges.md` | New, untracked. CH-01 to CH-29 — blockers, limitations, unverified items, decisions. |
| `agents/next_steps/improvements.md` | New, untracked. CH-19 (subfolder loading), IMP-01 (login handoff), IMP-02 (CAPTCHA handoff), IMP-03 ("Use Tier 2" trigger — done, in the agent). IMP-01/02 are proposals only. |
| `agents/next_steps/input_and_outcome.md` | New, untracked. Process for the future design agent(s): input → mock webpage, images, Razor. Decisions recorded; not built. |
| `agents/next_steps/next_steps_as_of_11-10-26.md` | This file. |

`next_steps/` (formerly `temp/`) and `challenges/` stay under `agents/` for
now (JG's decision) — do not move them out or delete them.

## Next steps

### 1. Test on Windows (JG's next session)

1. Copy **only** `agents/ux_design_researcher.md` to
   `%USERPROFILE%\.claude\agents\` (not the whole `agents/` folder — CH-19).
   Start a new Claude Code session so it loads.
2. Run `/mcp` — confirm the Playwright server is named exactly `playwright`
   (CH-23).
3. Run a first task containing **"Running on Windows"**, e.g.
   `@agent-ux-design-researcher Running on Windows — review https://<a page you know>`.
   The report opens with a Windows verification section.
4. From that run, record results against:
   - CH-01 — Tier 1 loaded, measurement script ran, numbers plausible
   - CH-25 — a browser window was visible
   - CH-05 — Bing / DuckDuckGo image search worked without a CAPTCHA
   - CH-24 — how many permission prompts appeared
5. Force a Tier 2 run with **"Use Tier 2"** in the task (IMP-03) to test
   image download and `Read` (CH-22). The report should say
   "Tier 2 (forced)".
6. Log in to one site in the Playwright browser, start a new run, and check
   whether the login persisted (CH-26).
7. Copy each run's `## Blockers encountered` lines into the challenges log.
8. If all passes, delete the agent's "Pending: Windows verification" section
   and resolve CH-01.

### 2. Decisions waiting on JG

- **Commit** — what to commit after testing, and whether `next_steps/` is
  included.
- **Deployment (CH-18)** — copy, link, or package the repo as a plugin.
  Options are listed in CH-18's history.
- **`CLAUDE.md` is out of date** — it does not describe `agents/challenges/`,
  `agents/next_steps/`, the challenges log format, or the 500-line agent limit.
  Update before or with the first commit.
- **Mobbin / logins (CH-08)**, **wait budget (CH-28)**, **repeat CAPTCHAs
  (CH-29)** — decide when building IMP-01 / IMP-02.
- **500-line limit (CH-20)** — revisit before adding anything to the agent.

### 3. Building next

- **IMP-01 / IMP-02** — login and CAPTCHA handoffs (`improvements.md`).
  Needs CH-25 and CH-26 answered first, and room under CH-20.
- **Design agent(s)** — from `input_and_outcome.md`. Two agents minimum,
  possibly four (brainstormer, mock builder, Razor translator). Decide names
  and the split first.
- **Inspiration step** — currently capped at 10 images / 6 sites in the
  researcher. The design agents get their own, open rules.

## Session notes worth keeping

- Agents run alone: they cannot ask the user questions, and only their final
  report returns. Write agent bodies as complete instructions.
- No file-path setting registers an agent — see CH-18 for the options.
- Edit local files with the Edit tool, never by publishing an artifact.
