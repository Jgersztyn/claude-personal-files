# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A personal library of **Claude Code assets** — skills, agents and personas
encoding JG's (Jason Gersztyn) working standards. It contains no application
source, no build system, no test suite, no CI, and no package manifest. Every file
is Markdown except the persona runners under `personas/` (PowerShell, JSON config
and an avatar image); see "Personas" below.

"Correct" here means *the documented standard is unambiguous and self-consistent*,
not *the code compiles*. Review changes as an editor would, not as a compiler.

## Commands

Git is the only required tooling. Two checks are worth running after editing any
skill or agent (both verified against this repo). They need Python 3, and the
frontmatter check also needs PyYAML (`pip install pyyaml`):

```bash
# Frontmatter parses and the `name` field is present
python -c "
import yaml,re,glob
for f in glob.glob('skills/*/SKILL.md')+glob.glob('agents/*.md'):
    d=yaml.safe_load(re.match(r'^---\n(.*?)\n---\n',open(f,encoding='utf-8').read(),re.S).group(1))
    print(f,'->',d['name'])"

# Companion-reference links still resolve
python -c "
import re,os,glob
for f in (glob.glob('skills/*/SKILL.md')+glob.glob('agents/*.md')
          +glob.glob('code-samples/*.md')
          +glob.glob('personas/**/*.md',recursive=True)
          +glob.glob('training-materials/**/*.md',recursive=True)):
    for m in re.findall(r'\.\./\.\./[\w/.-]+\.md', open(f,encoding='utf-8').read()):
        t=os.path.normpath(os.path.join(os.path.dirname(f),m))
        print(('OK  ' if os.path.exists(t) else 'DEAD'),f,'->',m)"
```

After editing a persona's runner or config, check that the script parses and the
JSON is valid (PowerShell; each script should report `0` parse errors):

```powershell
foreach ($f in 'sam.ps1','sam-schedule.ps1') { $e=$null; [void][Management.Automation.Language.Parser]::ParseFile("$PWD\personas\sam\$f",[ref]$null,[ref]$e); "$f $($e.Count)" }
Get-ChildItem personas\sam\*.json | ForEach-Object { Get-Content -Raw $_ | ConvertFrom-Json | Out-Null; "OK $($_.Name)" }
```

Then `.\sam.ps1 -Pr <PR url> -PromptOnly` (from `personas\sam\`, with a
`config.json`) prints the prompt Sam would get without cloning or running anything.

## Architecture: the skill + companion-reference split

This is the one structural decision that spans multiple files, and it is
deliberate. Each skill is paired with a supporting file that lives in a
**separate top-level directory**, never inside the skill folder:

| Skill | Companion reference | Holds |
|---|---|---|
| `skills/jg-code-style/` | `code-samples/jg-code-samples-reference.md` | Generic C# snippets |
| `skills/jg-user-stories/` | `training-materials/user-stories/strong-examples.md` | Verbatim Jira stories |
| `skills/jg-linqpad-scripts/` | `code-samples/jg-linqpad-samples-reference.md` | Generic LINQPad scripts |
| `skills/jg-pr-comment-editor/` | `training-materials/code-review-comments/verbose-vs-concise-comments.md` | Generic review comments, before/after |

The contract between the two halves:

- **The skill is self-contained and authoritative.** Every rule is stated inline.
  Each skill says explicitly that it "remains complete" if the reference is
  unavailable — the reference is supplementary background only.
- **The reference is isolated and generic.** `code-samples/` and
  `training-materials/code-review-comments/` carry no project, repo, people or
  domain names; identifiers are genericised.
- **Linking is one-way-ish and relative**: skills point out via
  `../../<dir>/<file>.md` from a `## Further Reading` section. Moving either half
  breaks the link — run the link check above.

Consequence: when a rule changes, edit the **skill**, not the reference. The
reference illustrates; it never defines. Do not migrate a companion file into its
skill directory to "tidy up" — the separation is the design.

## The skill template

The skills share most of this skeleton. Match it when adding another:

1. YAML frontmatter — `name` (matching the directory) and a long `description`
   ending with the phrases that should trigger it (e.g. *"my coding style"*).
2. `## When to apply this skill`
3. `## Hard rules (never skip)` — numbered, and explicitly stated to **win any
   conflict with the rest of the document**.
4. Body sections — numbered `## Area N — ...` for code style and LINQPad
   scripts, field tables for user stories.
5. `## Not covered here` — states the out-of-scope cases so the skill is not
   force-fitted (e.g. bugs, spikes and epics are not four-field stories).
   `jg-user-stories` and `jg-linqpad-scripts` — `jg-code-style` instead uses
   `## Optional / Tool-Specific (do NOT standardize)` to bound scope.
6. `## Further Reading` — external links plus the companion reference, with the
   "skill remains complete without it" disclaimer.
7. `## How to apply this ... in practice` — a numbered trigger→action list ending
   with "when unsure, the section above is the authoritative source."

## Personas

A persona is an assistant that runs on its own, outside an interactive session,
with a runner script that drives `claude -p`. There is one so far:

- **`personas/sam/`** is Sam, JG's PR review persona. It finds PRs where you're
  requested as a reviewer, reviews each in a throwaway worktree, and saves a draft
  or posts it as its own GitHub App. On later pushes it does follow-ups (only
  what changed since its last review) and answers replies in its own threads.
  `README.md` covers setup and use, and `TODO.md` the open decisions. `sam.ps1` is
  the runner, and `sam-schedule.ps1` registers it as a Windows scheduled task
  (named per folder, so copies on one PC don't replace each other's task).
  `sam-system.md`, `comment-standards.md`, `sam-pr-review.md` (full review),
  `sam-pr-followup.md` (follow-ups and replies) and `sam-codex-followup.md` (the
  Codex second pass) are the prompts. `review-schema.json` is Sam's output
  contract.
- **Sam here is the generic copy of JG's working Sam,** which lives outside this
  repo and develops first. New features are brought across from it in batches,
  and every batch gets the same generic treatment (see "Personas stay generic"
  below). Never edit the working copy from this repo.
- **`training-materials/sam/parked-pr-comments-skill-2026-11-04/`** is a parked
  variant of Sam's prompt files that loads `jg-pr-comment-editor` in-session
  instead of carrying its own comment standards. It is meant to be copied over the
  live files, so it mirrors every live prompt, `README.md` and `TODO.md` except
  for the comment-writing lines. When you
  edit a live Sam file that has a parked copy, make the same edit there.

How Sam ties into the rest of the repo:

- **`comment-standards.md` adapts `jg-pr-comment-editor`.** It's a self-contained
  copy with deliberate differences: category tags, a severity scale, posted
  Optional findings, a separate minor-notes list, and warmer reply rules. When the skill's rules change, review Sam's file
  and the parked variant too. Neither updates automatically.
- **The review step is configured, not hard-coded.** `reviewSkill` in Sam's
  `config.json` has three parts:
  - `tiers` picks the review skill by the PR's changed lines (`maxChangedLines`,
    `name`, `reviewers`, `reviewerModel`).
  - `instructions` holds extra headless lines for the skill.
  - `scaffold` is the run-directory layout the skill expects.

  An empty `name`, or a skill that isn't installed, means Sam's built-in
  multi-lens review. `sam.ps1` builds the step and fills `{{review_step}}` in both
  `sam-pr-review.md` and `sam-pr-followup.md`. Keep the prompts free of any one
  plugin's skill names; they belong in config.

## Load-bearing conventions

- **`Persistance/` and `Utilties/` are misspelled on purpose.** They are JG's
  established folder convention. Never silently correct them here or in any
  project this repo's guidance is applied to; `jg-code-style` hard rule 5 names
  this explicitly.
- **The user-story training material is reproduced verbatim, flaws included.**
  The Jira examples are unchanged real tickets. Known defects (a placeholder
  acceptance criterion, a non-standard field, a missing ticket key) are
  documented in the file's "Reading notes" caveats rather than fixed. Do not
  clean up those examples — extend the caveats if you find another flaw.
- **The review-comment training material is never verbatim.** This repo is
  public, so `training-materials/code-review-comments/` holds only generic
  reconstructions and freshly written examples: no names, repos, PR numbers,
  private identifiers or domain vocabulary, and no reviewer's own sentences.
  Add new before/after pairs the same way. `self-review-examples/` holds full
  self-reviews rebuilt the same way in a neutral online-store domain. They're
  deliberately not linked from `jg-pr-comment-editor`, to keep the skill lean.
  Add new ones there under the same rules.
- **Skills are prefixed `jg-`**; the `name` field equals the directory name.
- **Agents** live at `agents/<file>.md`. The file name is free-form, but the
  frontmatter `name` must be lowercase/numbers/hyphens only, so it may legitimately
  differ from the file name (`ux_design_researcher.md` → `ux-design-researcher`).
- **Personas stay generic and carry no live config.** Each persona folder's
  `config.json` is git-ignored and holds the real repos, App ID and key path. Only
  `config.example.json`, with placeholders, is committed. No organization, repo,
  PR number, App ID, app name or colleague goes into a persona's committed files.
  Example URLs use `<owner>/<repo>`. Private keys never enter the folder: Sam
  won't start a review while a `.pem` is in it.
- **Sam's schema fields are a contract.** `notes_for_jg` (private notes),
  `thread_replies` and `extra_minor_notes`, like every field `sam.ps1` reads, are
  named in `review-schema.json`, the prompts and `sam.ps1`. Rename one in all of
  them or in none.

## Deployment

Not recorded in this repo. The layout mirrors Claude Code's own
`skills/<name>/SKILL.md` and `agents/<name>.md` conventions, but nothing here
documents how these files reach `~/.claude/`. Ask before assuming a mechanism.

Personas aren't deployed to `~/.claude/`. Sam runs in place from its own folder
(`.\sam.ps1`) and keeps its clones, worktrees and drafts there. The skills Sam
loads in-session (its `reviewSkill`, or `jg-pr-comment-editor` in the parked
variant) must be installed for your user, because Sam's session loads only user
settings.
