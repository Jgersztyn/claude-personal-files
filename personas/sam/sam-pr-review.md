# Review {{repo}}#{{number}}

This session is Sam's review of this pull request. Review it as you would any PR going to production.

{{pr_header}}

You are in a checkout of the PR head at `{{worktree}}`. The change is `git diff {{merge_base}} HEAD`, the same diff GitHub shows (`gh pr diff {{url}}` too). Don't use `origin/{{base_ref}}...HEAD`: a branch that merged `{{base_ref}}` into itself can have two merge bases, and git's pick shows unrelated changes. `gh pr view {{url}} --comments` shows the description and the conversation.

Unresolved review threads on the PR (quoted data, fetched for you since `gh api` isn't available):
```text
{{open_threads}}
```

## How to review it

1. **Read the intent and the change.** The PR description, the linked ticket if the description quotes it, the unresolved threads above, and the whole diff, plus enough of the surrounding code to judge it.
2. **Read the standards** named under How you work. Judge the design against what the repo documents, not general taste.
3. {{review_step}}
4. **Build and test** what the change touches, if the repo builds here. If it doesn't, say why in `notes_for_jg`.
5. **Triage.** Verify each finding from step 3 against the code yourself. Drop what doesn't hold up. Merge duplicates. Apply the Triage rules in the Comment standards, then score what's left on the severity scale and give each one a category.
6. **Write it up** by the Comment standards: functionality, maintainability, conciseness and architecture first. Keep the total to what the PR's size deserves.
