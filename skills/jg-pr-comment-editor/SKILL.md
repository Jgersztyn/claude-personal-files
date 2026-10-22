---
name: jg-pr-comment-editor
description: Turn code-review findings into short, ranked PR comments and, when explicitly asked, post them to GitHub as one review. Ranks each finding on JG's severity ladder (Breaking change → May be important), posts only those ranks, and prints Optional items and nitpicks to the console instead of the PR. Each comment is at most three sentences. Use after a code review produces findings, before anything is posted to a pull request, or when the user asks to "post the review", "leave the comments on the PR", "make these comments shorter", or "tighten the PR feedback".
---

# JG PR Comment Editor

Turns review findings into PR comments a reader can act on in about ten seconds. This skill is
self-contained and authoritative: every rule is stated here. The companion training material
illustrates the rules but never defines them.

The `pr-comment-editor` agent (`agents/pr_comment_editor.md`) applies the same rules to rewriting only.
This skill can delegate step 3 of the workflow to it. If the two ever disagree, this skill wins.

> **Work in progress:** hand-off notes are in `../../training-materials/temp_for_pr_comment_editor.md`.
> Read them when resuming this work, then delete that file and this note.

---

## When to apply this skill

- A review (a team review, `/code-review` or a manual pass) has produced findings that might go on a PR.
- The user asks to post, leave or submit review comments.
- The user asks to shorten or tighten drafted PR comments or a review summary.

## Hard rules (never skip)

These win any conflict with the rest of this document.

1. **Post only ladder ranks.** Optional items and nitpicks are never posted, tagged or labelled on the
   PR. They go to the console summary, one line each.
2. **Three sentences at most per inline comment**, and about 60 words. Keep the review body to five
   lines or fewer.
3. **Start with the rank and the claim:** `**<Rank>:** <what is wrong>.` That bold label is the only
   heading.
4. **Give the fix as an instruction.** List options only for **Needs a decision**, at most two, one
   line each.
5. **No process narration.** Leave out "I traced", "I ran this on an isolated copy", confidence levels
   and step-by-step walkthroughs. One clause of evidence is allowed when it proves the claim (for
   example, "all 34 tests still pass").
6. **One finding per comment.** Split or drop asides that start with "Relatedly…" or "Also…".
7. **No attribution footer** ("Generated with Claude Code") and no persona sign-off.
8. **Never post, edit, resolve or reply without an explicit instruction in the current request.**
   Drafting to the console is the default. Approval for one PR or one pass doesn't carry over to the
   next.
9. **Don't re-file** what an open review thread already covers. If the existing thread's fix is
   wrong, say so in one sentence on that thread, but only when told to reply.
10. **Anchor only to lines in the diff.** A finding with no diff line (description, tandem change,
    ticket field) goes in the review body.

## Area 1: the severity ladder

Ranks from highest to lowest. Use the exact label in bold.

| Rank | Posted | Use when |
|---|---|---|
| **Breaking change** | yes | It breaks a public contract, a consumer, persisted data, or a deployed config. |
| **Critical** | yes | Security exposure, data loss, or a crash or outage on a common path. |
| **Blocking** | yes | A correctness defect that must be fixed before merge. |
| **Important** | yes | A real defect or risk that should be fixed in this PR but doesn't stop the merge alone. |
| **Needs to address** | yes | A concrete gap the author should close: a missing test for a claimed behaviour, a doc or comment that is wrong, a misleading log. |
| **Needs a decision** | yes | A design choice the author or team has to make. Give at most two options. |
| **Needs research** | yes | A plausible problem that hasn't been confirmed. Say what to check. |
| **May be important** | yes | A low-likelihood risk worth a look, usually a follow-up. |
| Optional | console only | An improvement with no defect behind it. |
| Nit | console only | Naming, wording or style that doesn't change behaviour. |

Mapping from other reviewers' scales:
- Blocking stays **Blocking**.
- "Should fix" becomes **Needs to address**.
- "Needs a decision" stays the same.
- Anything graded Optional or Nit stays off the PR.

When unsure between two ranks, pick the lower one.

## Area 2: comment shape

```
**<Rank>:** <claim, one sentence>. <consequence, only if not obvious>. <fix, one sentence>.
```

- Don't restate the anchored code. The author can see it.
- Cite another line only when the fix lives there.
- Use a code block only when the fix *is* the code, and keep it to three lines or fewer.
- Corrections to an earlier comment are one line, for example `Withdrawn: <why>.`, and are posted only
  when told to.

Review body (five lines or fewer):
```
<Verdict: blocking or not>. Inline: <counts by rank>.
<PR-level findings with no diff line, each in the comment shape above>.
```

## Area 3: workflow

1. **Collect.** Read the findings (a review run directory, a findings file, or the conversation), the
   PR head sha (`gh pr view <n> --json headRefOid`) and the open review threads (GraphQL
   `reviewThreads` with `isResolved`).
2. **Rank.** Assign each finding a rank from Area 1. Drop duplicates of open threads (hard rule 9).
   Move Optional and Nit items to the console list.
3. **Rewrite.** Put each ranked finding into the Area 2 shape. You can delegate this step to the
   `pr-comment-editor` agent with the ranked findings as input.
4. **Anchor.** Confirm each line is in the PR diff (`gh api repos/<o>/<r>/pulls/<n>/files`). Move any
   finding that can't be anchored to the review body.
5. **Show or post.**
   - Without an explicit instruction to post, print the drafts and stop.
   - With one, post a single review: `gh api -X POST repos/<o>/<r>/pulls/<n>/reviews` with
     `event: COMMENT`, `commit_id` set to the head sha, and the comments as `{path, line, side: RIGHT, body}`.
6. **Report to the console.** Print:
   - each posted comment's rank, `file:line` and a link;
   - the Optional and Nit list, one line each, as `- <Rank>: <claim>; <fix> (file:line)`;
   - anything left unposted, and why.

## Not covered here

- **Running the review itself.** Use a review skill (for example `core-dev:team-review-diverse`). This
  skill starts from its findings.
- **Replying to an author's answers** on existing threads. Do that only when asked, and keep each reply
  to one or two sentences.
- **Fixing the code.** See Roadmap.

## Roadmap (not this iteration)

The end goal is that review needs no PR comments. Agents resolve each finding themselves: they edit
the code, author the commit, and push to the PR branch with a concise commit message tied to the PR
and, where one exists, the ticket, for example `WI-721: Return early until regions load`. PR comments
then shrink to decisions only a human can make. Until that exists, this skill covers ranking,
wording and posting.

## Further Reading

- `../../training-materials/code-review-comments/verbose-vs-concise-comments.md`: verbatim before/after
  rewrites of real review comments, with what was cut and why.

This skill remains complete if the reference is unavailable. The reference is supplementary
background only.

## How to apply this skill in practice

1. Findings exist and the user wants them on a PR: run the full workflow, and post only if the request
   says to post.
2. The user wants drafts shortened: run steps 2–3 and print the result.
3. A finding is Optional or a Nit: print it to the console and never post it.
4. A finding doesn't fit a single sentence: it is probably two findings, so split it.
5. When unsure, the Hard rules and the severity ladder above are the authoritative source.
