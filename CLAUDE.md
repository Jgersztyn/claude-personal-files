# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A personal library of **Claude Code assets** — skills and agents encoding JG's
(Jason Gersztyn) working standards. It contains no application source, no build
system, no test suite, no CI, and no package manifest. Every file is Markdown.

"Correct" here means *the documented standard is unambiguous and self-consistent*,
not *the code compiles*. Review changes as an editor would, not as a compiler.

## Commands

Git is the only required tooling. Two checks are worth running after editing any
skill or agent (both verified against this repo):

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
          +glob.glob('training-materials/**/*.md',recursive=True)):
    for m in re.findall(r'\.\./\.\./[\w/.-]+\.md', open(f,encoding='utf-8').read()):
        t=os.path.normpath(os.path.join(os.path.dirname(f),m))
        print(('OK  ' if os.path.exists(t) else 'DEAD'),f,'->',m)"
```

## Architecture: the skill + companion-reference split

This is the one structural decision that spans multiple files, and it is
deliberate. Each skill is paired with a supporting file that lives in a
**separate top-level directory**, never inside the skill folder:

| Skill | Companion reference | Holds |
|---|---|---|
| `skills/jg-code-style/` | `code-samples/jg-code-samples-reference.md` | Generic C# snippets |
| `skills/jg-user-stories/` | `training-materials/user-stories/strong-examples.md` | Verbatim Jira stories |

The contract between the two halves:

- **The skill is self-contained and authoritative.** Every rule is stated inline.
  Each skill says explicitly that it "remains complete" if the reference is
  unavailable — the reference is supplementary background only.
- **The reference is isolated and generic.** `code-samples/` carries no project,
  repo, or domain names; identifiers are genericised.
- **Linking is one-way-ish and relative**: skills point out via
  `../../<dir>/<file>.md` from a `## Further Reading` section. Moving either half
  breaks the link — run the link check above.

Consequence: when a rule changes, edit the **skill**, not the reference. The
reference illustrates; it never defines. Do not migrate a companion file into its
skill directory to "tidy up" — the separation is the design.

## The skill template

Both skills share most of this skeleton. Match it when adding a third:

1. YAML frontmatter — `name` (matching the directory) and a long `description`
   ending with the phrases that should trigger it (e.g. *"my coding style"*).
2. `## When to apply this skill`
3. `## Hard rules (never skip)` — numbered, and explicitly stated to **win any
   conflict with the rest of the document**.
4. Body sections — numbered `## Area N — ...` for code style, field tables for
   user stories.
5. `## Not covered here` — states the out-of-scope cases so the skill is not
   force-fitted (e.g. bugs, spikes and epics are not four-field stories).
   `jg-user-stories` only — `jg-code-style` instead uses
   `## Optional / Tool-Specific (do NOT standardize)` to bound scope.
6. `## Further Reading` — external links plus the companion reference, with the
   "skill remains complete without it" disclaimer.
7. `## How to apply this ... in practice` — a numbered trigger→action list ending
   with "when unsure, the section above is the authoritative source."

## Load-bearing conventions

- **`Persistance/` and `Utilties/` are misspelled on purpose.** They are JG's
  established folder convention. Never silently correct them here or in any
  project this repo's guidance is applied to; `jg-code-style` hard rule 5 names
  this explicitly.
- **Training material is reproduced verbatim, flaws included.** The Jira examples
  are unchanged real tickets. Known defects (a placeholder acceptance criterion,
  a non-standard field, a missing ticket key) are documented in the file's
  "Reading notes" caveats rather than fixed. Do not clean up the examples —
  extend the caveats if you find another flaw.
- **Skills are prefixed `jg-`**; the `name` field equals the directory name.
- **Agents** live at `agents/<file>.md`. The file name is free-form, but the
  frontmatter `name` must be lowercase/numbers/hyphens only, so it may legitimately
  differ from the file name (`ux_design_researcher.md` → `ux-design-researcher`).

## Deployment

Not recorded in this repo. The layout mirrors Claude Code's own
`skills/<name>/SKILL.md` and `agents/<name>.md` conventions, but nothing here
documents how these files reach `~/.claude/`. Ask before assuming a mechanism.
