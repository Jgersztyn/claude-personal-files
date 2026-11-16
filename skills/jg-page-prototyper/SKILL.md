---
name: jg-page-prototyper
description: Orchestrate HTML prototypes for one whole page by splitting it into pieces and giving each piece to its own run of the ux-design-researcher agent ("the RXer"). Asks which galleries to search, runs one shell run to fix 2 to 4 design directions, writes a read-only shared design file per direction, runs up to 4 workers that each return a fragment per direction, then assembles one full-page HTML prototype per direction and checks for clashes. Runs in the main session, because it asks the user questions. Use when the user wants mocks or prototypes for a full page or screen rather than a couple of controls, and especially when the user references "prototype this page", "page prototyper", "mock the whole page", or "split this page across agents".
---

# JG Page Prototyper

Produces full-page HTML prototypes from several narrow RXer runs. The
RXer stays a worker that handles a few items; this skill splits the
page, keeps the workers consistent, and puts the pieces together. This
skill is self-contained — the standard is stated inline.

---

## When to apply this skill

- The user asks for mocks or prototypes of a whole page or screen.
- A request to the RXer covers more than 4 items on a page.
- A request for a couple of items needs no orchestration: ask the
  sources question (Area 1), then pass it to one RXer run.

---

## Hard rules (never skip)

These are non-negotiable. If something here conflicts with the rest
of the document, the hard rule wins.

1. **Run in the main session.** This skill asks the user questions,
   and a subagent cannot. Never hand the whole skill to an agent.
2. **One page, at most 4 workers.** The shell run is not counted. A
   request beyond that gets questions back, not a bigger run.
3. **Ask the sources question once**, unless the request already says
   which sites to use or avoid.
4. **Directions are fixed before any worker starts.** Workers never
   invent a direction.
5. **No two runs write the same file.** Shared design files are
   written by this skill and are read-only to workers. Each worker
   writes only inside its own folder.
6. **Shared files do not change once a worker has started.** A token
   a worker asks for is noted, not added mid-run.
7. **One run at a time.** The runs share one Playwright browser, and
   two agents driving it at once would navigate over each other.
   Running workers in parallel is untested; do not try it unasked.
8. **HTML only.** Nothing is built, compiled, served, rendered or
   screenshotted, by this skill or by any run it starts.
9. **Do not redesign a worker's fragment.** Fix mechanical clashes
   only (Area 6). List design clashes for JG.
10. **Nothing private is written.** No credential, cookie, token or
    account detail goes into any file.

---

## Area 1 — Scope and questions

1. **Check the scope.** More than one page, or a page that needs more
   than 4 pieces: ask the user which page or which pieces to take
   first, and stop until answered.
2. **Ask the sources question**, once: which of Pinterest, Dribbble
   and Behance to search. Skip it if the request already says. Other
   research (image search, live-code sites, real products) always
   runs and is not asked about.
3. **Logins, only if the user wants a walled site searched.** Before
   any run: open the site's login page in the Playwright browser, let
   the user sign in, and watch only the page address. Cap each wait
   under two minutes. Confirm by loading a search and checking that
   results show with no wall. Take no screenshot while they sign in.

---

## Area 2 — Split the page

- Write the page brief: the job, and every requirement as `REQ-n`.
- Split the page into **2 to 4 pieces**. A piece is a few items that
  sit together and are used together (a timeline: Play/Stop, slider,
  time label). Give each a short slot name (`timeline`, `topbar`).
- Every `REQ-n` belongs to exactly one piece, or to the shell.
- Save this as `brief.md` in the page folder.

```
ux-research/<page-slug>/
  brief.md               brief, split, directions, clash notes
  shell/                 the shell run's output folder
  shared/<direction>.html
  <slot>/                one output folder per worker
  pages/<direction>.html
```

---

## Area 3 — The shell run

Start one RXer run with a task message of this shape:

```
Shell run. Page: <the job and the page-level requirements>.
Slots to leave empty: <slot names, with what each will hold>.
Sites: <the answer to the sources question>.
Save every file you create under <page folder>/shell/ and nowhere else.
```

It does the page-level visual research and returns 2 to 4 page
shells. Each shell is one design direction. This research runs once;
workers do not repeat it.

If the `ux-design-researcher` agent is not registered, start a
general-purpose agent and tell it to read
`agents/ux_design_researcher/AGENT.md` and follow it as its
instructions.

---

## Area 4 — Shared design files

For each shell, write `shared/<direction>.html`:

- the shell's page skeleton, with each slot as
  `<div data-slot="<name>">` and its size;
- every colour, type and spacing value as a CSS custom property on
  `:root`;
- a comment at the top naming the direction in one line, and listing
  the slots and the custom properties.

Record the directions in `brief.md`. From here the shared files are
frozen (hard rule 6).

---

## Area 5 — Worker runs

Start one RXer run per piece, one after another (hard rule 7):

```
Worker run. Slot: <slot name>. Items: <the piece's items and REQ-n>.
Shared design files (read-only): <each shared file path>.
Sites: <the answer to the sources question>.
Save every file you create under <page folder>/<slot>/ and nowhere else.
```

Each worker researches patterns for its own items and returns one
fragment per direction, in `<slot>/fragments/<direction>.html`.

---

## Area 6 — Assemble and check

For each direction, copy the shared file to `pages/<direction>.html`
and place each worker's fragment into its slot. Then read each
assembled file — do not render it — and check:

| Check | If it fails |
|---|---|
| Every class and id in a fragment starts with its slot name | Fix: add the prefix |
| No id appears twice in the page | Fix: prefix it |
| A fragment uses only the shared file's custom properties | Fix: swap in the nearest shared value, and note it |
| A script leaks a global name | Fix: wrap it in a function |
| A fragment does not fit its slot's size | List for JG |
| The same thing is labelled differently in two fragments | List for JG |
| Two fragments solve the same job in conflicting ways | List for JG |
| A `REQ-n` is missing from a page | List for JG |

Write every fix and every listed clash into `brief.md`.

---

## Area 7 — What to report

- **Pages:** each `pages/<direction>.html`, with its direction in one
  line.
- **Split:** the pieces, and which `REQ-n` each holds.
- **Clashes:** fixed, and listed for JG.
- **Token requests:** values workers asked for that the shared files
  lacked.
- **Logins needed** and **Blockers**, gathered from every run, with
  any `BOT DETECTED:` line first.

---

## Not covered here

- **A couple of items on a page.** One RXer run does that.
- **More than one page, or more than 4 workers.** Out of scope for
  now: ask the user to narrow the request.
- **Choosing between the directions.** That is JG's decision.
- **Building the chosen page in MudBlazor or MaterialUI.** The
  `jg-component-builder` skill does that, from one assembled page.
- **Auditing.** The `ux-auditor` agent does that, on a UI that
  exists.

---

## Further Reading

- `../../agents/ux_design_researcher/AGENT.md` (relative to this
  skill's directory): the worker's own rules, including its run
  kinds.

This skill has no companion reference yet. If that file is
unavailable, the skill remains complete; the reference is
supplementary background only.

---

## How to apply this standard in practice

1. **A couple of items?** Ask the sources question and start one RXer
   run. Stop here.
2. **More than one page, or more than 4 pieces?** Ask the user to
   narrow it.
3. **Ask the sources question**, and do any login hand-off.
4. **Write the brief and the split.**
5. **Shell run** → 2 to 4 directions.
6. **Write the shared design files**, then freeze them.
7. **Worker runs**, one at a time.
8. **Assemble one page per direction**, check, and fix mechanical
   clashes only.
9. **Report** pages, clashes, token requests, logins and blockers.
10. **When unsure**, the sections above are the authoritative source.
