# Temp: hand-off notes for the PR comment editor work

Temporary. Once you've read this and picked the work back up, delete this file, along with the
"Work in progress" note near the top of `skills/jg-pr-comment-editor/SKILL.md` and
`agents/pr_comment_editor.md`.

## Why this exists

On 2026-10-21, Claude ran two review passes on Climavision/Athena PR #373, eight reviewers each
(`core-dev:team-review-diverse`), and posted them as GitHub reviews 5605187592 and 5605371088. JG
found the comments too verbose: 150–260 words each, with walkthroughs, option menus and evidence
dumps. The target is a few sentences per comment. These assets enforce that.

## What was built (all untracked, nothing committed)

| File | Role |
|---|---|
| `skills/jg-pr-comment-editor/SKILL.md` | Authoritative. Covers the severity ladder, hard rules, comment shape, and the workflow (collect → rank → rewrite → anchor → show or post → console report). |
| `agents/pr_comment_editor.md` | Rewrite only, with no GitHub access. Returns a fixed format: PR comments, review body, a console-only list, and notes. The skill can delegate its step 3 to it. |
| `training-materials/code-review-comments/verbose-vs-concise-comments.md` | Companion reference. Six verbatim comments from #373 paired with rewrites, generated from what was actually posted. |
| `CLAUDE.md` (repo root) | One row added to the companion-reference table. |

## Decisions JG made

- **Build both the skill and the agent**, to see which works better or whether they work best
  together.
- **Post only the higher ranks:**
  - Breaking change
  - Critical
  - Blocking
  - Important
  - Needs to address
  - Needs a decision
  - Needs research
  - May be important
- **Optional items and nitpicks go to the console only**, never posted or tagged on the PR. This is
  for the first iteration.
- **Comment length:** three sentences at most, about 60 words. The review body is five lines or
  fewer. No "Generated with Claude Code" footer.
- **Never post, edit or reply on a PR without an explicit instruction** in the current request.
- **End goal, not this iteration:** no PR comments at all. Agents fix the findings, commit and push
  with concise messages tied to the PR or ticket, for example `WI-721: …`.

## Open items / next steps

1. **Dry run.** Feed the #373 findings through the skill with console output only and no posting.
   Compare the skill alone against the skill delegating to the agent. The findings are summarized in
   the take-1 and take-2 reviews on PR #373.
2. **Deployment.** How these files reach `~/.claude/` isn't recorded anywhere. Ask JG.
3. **Check the ladder's wording and order** with JG, especially where "Needs to address" sits against
   "Needs a decision".
4. **Link check gap.** The repo's link check (in `CLAUDE.md`) only matches `../../` paths, so it misses
   the agent's `../training-materials/...` link.
5. **More training material.** Add more before/after pairs as JG supplies examples.
6. **Roadmap.** Start on the fix-and-commit agent (see "End goal" above).
7. **Commit.** Nothing in `claude-personal-files` is committed yet. `skills/jg-task-organizer/` was
   already untracked before this work and isn't part of it.

## Related state outside this repo

- Claude memory (project `C--Repos-3-Athena`): `pr-comments-must-be-short.md` records the same rules.
- PR #373: don't touch it again without JG's say-so. Seven of Claude's take-1 comments were edited
  with marked second-pass corrections. No replies were made to the author's threads.
