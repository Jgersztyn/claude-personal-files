---
name: jg-pr-comment-editor
description: Turn code-review findings into PR comments that read like a senior human reviewer wrote them (short, plain, unlabelled) and, only when explicitly asked, post them to GitHub as one review. Keeps each finding's severity grade, or ranks it on JG's ladder (Breaking change → May be important), posts only those ranks, carries severity in the wording and the review body instead of labels, and prints Optional items and nitpicks to the console instead of the PR. Most comments are one or two short sentences of 10 to 25 words, and the ceiling is three sentences and 40 words (60 for a design change). Use after a code review produces findings, before anything is posted to a pull request, or when the user asks to "post the review", "leave the comments on the PR", "make these comments shorter", "tighten the PR feedback", or says the review "reads like AI".
---

# JG PR Comment Editor

Turns review findings into PR comments an author can act on in a few seconds, written the way a
respected human reviewer writes them. This skill is self-contained and authoritative: every rule is
stated here. The companion training material illustrates the rules but never defines them.

The `pr-comment-editor` agent (`agents/pr_comment_editor.md`) applies the same rules to rewriting
only. This skill can delegate step 3 of the workflow to it. If the two ever disagree, this skill wins.

**Why the rules look like this.** They come from a study of more than 500 review comments by one
senior human reviewer whose feedback authors act on, compared with AI-drafted comments on one PR that
were judged too verbose. The reviewer's typical comment is one sentence of 13 words with no label. The
AI comments ran about 150 words each, every one opened with a bold rank, and half narrated how the
finding was found. The two AI passes drew no reply, reaction or fix.

---

## When to apply this skill

- A review (a team review, `/code-review` or a manual pass) has produced findings that might go on a PR.
- The user asks to post, leave or submit review comments.
- The user asks to shorten or tighten drafted PR comments or a review summary, or says they read
  like AI.

## Hard rules (never skip)

These win any conflict with the rest of this document.

1. **Never post, edit, resolve or reply without an explicit instruction in the current request.**
   Drafting to the console is the default. Approval for one PR or one pass doesn't carry over to the
   next. Post only through this skill, never through another tool's own posting mode (for example
   `/code-review --comment`).
2. **Post only ladder ranks.** Optional items and nits are never posted, tagged or labelled on the PR.
   They go to the console summary, one line each.
3. **No labels on the PR.** No bold, rank names, headings, severity codes, or "Suggested fix:" and
   "Example:" sections. The rank is for triage and the console report only. Severity is carried by the
   wording (Area 1) and the review body (Area 4).
4. **Inline comments are short.** Most are one or two short sentences of 10 to 25 words. The ceiling
   is three sentences and 40 words. Count words by splitting on spaces; a backticked identifier is one
   word. A code block of five lines or fewer may follow when the fix is code, and it doesn't count. A
   design change may run to 60 words in up to five short sentences.
5. **Lead with the problem, a question, the replacement, or an instruction** ("please …"). Name code
   in backticks and never restate what the anchored code does.
6. **Say what to do.** Give the replacement, an instruction, or one question that carries the scenario
   or the alternative. Leave the fix implied only when naming the problem names the fix ("Unused.",
   "Redundant null check."). Never post a bare "why?".
7. **No AI tells in inline comments** (Area 3).
8. **One finding per comment.** Write a repeated finding once, in full, ending "Same for the others."
   or naming the one other site. Anchor another site only when it needs a different fix. An aside
   ("Relatedly…", "Also…") that is a finding in its own right is ranked on its own: its own input
   grade if it has one, otherwise ranked as an ungraded finding. It is then posted or sent to the
   console by that rank. Otherwise drop it.
9. **The review body is five lines or fewer** (Area 4).
10. **Verify, then post once.** Post one batched review per pass, never a stream of single comments
    or a correcting second pass. A later correction is a one-line reply, posted only when told to.
11. **Don't re-file** what an open review thread already covers, meaning it asks for the same change,
    even to add a new fact. Match by content, not line numbers. If a thread covers only part of a
    finding, post the rest. Put a new fact in the console report as a candidate reply, posted only when
    told to reply. Do the same when your finding is graded more severe than the thread treats it. A
    candidate reply is the new fact or the higher severity plus the ask, in the comment shape.
12. **Anchor only to lines in the diff.** A finding with no diff line (description, tandem change,
    ticket field) goes in the review body.
13. **The review event is `COMMENT`** unless the request names `APPROVE` or `REQUEST_CHANGES`. Never
    post `APPROVE` while a must-fix finding stands. One stands when the input or an open thread grades
    it Breaking change, Critical or Blocking, including one dropped as a duplicate. Print why, and stop.
    If you think a lower-graded finding could block, don't post anything until the user answers
    (step 6).
14. **Critique the code, never the author,** their experience or their tools.

## Area 1: the severity ladder

Ranks from highest to lowest. The rank decides whether a finding is posted and where it is listed. It
never appears in the posted text; the wording carries it.

| Rank | Posted | Use when | How the wording carries it |
|---|---|---|---|
| **Breaking change** | yes | It breaks a public contract, a consumer, persisted data, or a deployed config. | State the break and who it hits; "please … before merge". Listed in the body. |
| **Critical** | yes | Security exposure, data loss, or a crash or outage on a common path. | State the failure plainly; "please … before merge". Listed in the body. |
| **Blocking** | yes | A correctness defect that must be fixed before merge. | Claim, then "please …" or "needs to …". Listed in the body. |
| **Important** | yes | A real defect or risk that should be fixed in this PR but doesn't stop the merge alone. | Claim, then "please …" or "we should …". |
| **Needs to address** | yes | A concrete gap the author should close: a missing test for a claimed behaviour, a doc or comment that is wrong, a misleading log or name. | Claim, then the replacement or one instruction. |
| **Needs a decision** | yes | A design choice the author or team has to make. | The problem, then one question that names the choice: "Can we …?" or "Either X or Y?". Never a menu. |
| **Needs research** | yes | A plausible problem that hasn't been confirmed. | A question that carries the scenario: "What happens if two requests …?" |
| **May be important** | yes | A real but unlikely risk worth a look, usually a follow-up. | One hedged line: "Probably fine, but … Worth a ticket?" |
| Optional | console only | An improvement with no defect behind it. | Console line only. |
| Nit | console only | Naming, wording or style that doesn't change behaviour or mislead. | Console line only. |

Firmness lives in the verb:
- **Must change:** "please …", "needs to …", "… before merge".
- **Should change:** "we should …", "can we …?", the replacement offered as a question
  ("How about `OrderLookup`?").
- **Your call:** "probably fine, but …", "fine if intentional", "up to you", "fine to leave for now".
  Use these only for the posted ranks that genuinely leave the choice open, mostly **May be
  important**.

Firm wording gets acted on; hedged wording mostly doesn't. Don't hedge a finding you ranked
Important or higher.

**Keep the input's grades.** This skill rewords findings; it doesn't re-judge them. Keep the rank or
grade each finding arrives with, and rank only ungraded findings. If a grade looks wrong, say so in
the console report rather than changing it. If you think a lower-graded finding could block, step 6
asks the user before anything is posted; until then the verdict follows the kept grades and open
threads (Area 4). Mapping from
other reviewers' scales:
- Blocking stays **Blocking**.
- "Should fix" becomes **Needs to address**.
- "Needs a decision" stays the same.
- Anything graded Optional or Nit stays off the PR, even if a ladder definition might fit it.
- Decorations such as "(non-blocking)", "(follow-up)" or "P2" aren't grades. Drop them, and say "in
  a follow-up PR" in words if the timing matters. A grade that maps to nothing counts as ungraded,
  with a console note.

When unsure between two ranks, pick the lower one. Optional and Nit sit below May be important. List
findings highest rank first, then in diff order.

## Area 2: comment shape

Default form, one or two sentences:

```
<problem, naming the code>. <fix, or one question that carries the scenario or alternative>.
```

- **Open with the substance.** The most common opener is a plain observation ("`Save` isn't
  awaited, so failures vanish."). Next is a question. An instruction or the replacement itself also
  works ("`OrderLookup`?"). No greeting, no preamble, no label.
- **One reason clause, only if the author can't infer it:** "since…", "so…", "because…". A named
  principle in one to three words ("magic number", "stringly typed", "Chesterton's fence") stands in
  for an argument; don't explain it.
- **Evidence is one clause at most:**
  - a count ("There are three TODOs in this file.");
  - the one other place the fix lives ("The guard above has one.");
  - one link;
  - what the code cost you as a reader, when that is true of the code as written ("I had to read
    this twice to see why the cache is cleared here."). That is a reaction to the code, not process
    narration. Use it sparingly: at most one comment per review.

  Never test runs, traces, mutation results or confidence statements.
- **Give the replacement when one exists:** a name in backticks, or one line of code. Use a code
  block only when the fix *is* the code, five lines or fewer. No `suggestion` blocks.
- **Ask when the answer is the author's intent, lies outside the diff, or is a judgement call.** Put
  the scenario or the alternative in the question, so one reply settles it. Never ask about something
  you could check in the diff.
- **Verified or not.** For an ungraded finding, state a verified defect, and phrase an unverified one
  as a question (**Needs research**) or, if it is unlikely, as a hedged line (**May be important**).
  A graded finding keeps its grade and that rank's wording. If it admits it wasn't verified, say so
  in the console report.
- **For a wrong comment or doc, say what is wrong and where the content belongs.** Don't write
  replacement prose. If the same sentence also appears in the PR description, say so in the same
  comment rather than filing it twice.
- **For code this PR didn't change,** say so after the problem: "`RetryCount` is never read.
  Pre-existing, so no change needed in this PR." Better still, leave it for a ticket.
- **For a behaviour change,** one before-and-after clause is fine ("The old loop stopped at the
  first error."). That isn't history.
- **Use the code's and the PR's own terms.** Don't coin new ones.
- **A design change may run long only to give its shape** (hard rule 4). Order: claim, reason,
  shape. Keep each sentence under about 15 words.

Corrections and replies are in Area 5.

## Area 3: AI tells to strip

These are what make a review read as machine-written. Human reviewers whose comments get acted on use
almost none of them: no human comment in the study opened with bold text, while about 60% of the
AI-written comments in the same codebases did. Check every inline comment and candidate reply against
this list before showing or posting it. Area 4 covers the review body.

| Tell | Instead |
|---|---|
| Bold anywhere: a bold title, a bold rank label (`**Should fix:** …`) | Start with the problem in plain words. |
| Severity codes and decorations: P1/P2, "(blocking)", "(non-blocking)", "(follow-up)" | Firm or hedged wording (Area 1). |
| Headings, tables, badges, `<details>` blocks, horizontal rules | Plain sentences. |
| A headline sentence that the body then restates | Say it once. |
| Sub-sections: "Suggested fix:", "Example:", "Evidence", "Impact", "Why it matters" | One sentence, or the replacement name. |
| More than one paragraph (a code block aside), bullet lists, "(1)…(2)…" enumerations | One paragraph of one or two sentences. |
| Option menus: (a)/(b), "Options:", "Alternatively…" | One question; at most "Either X or Y?". |
| "Consider …" openers | Name the replacement, or ask "Why not X?". |
| Lists of line numbers or `file:line` references, commit SHAs | At most one pointer to the place the fix lives. |
| Three or more backticked identifiers in one comment | Name the one or two that matter. |
| Process narration: "I traced…", "ran on a copy", "mutants", "second pass", "N reviewers" | Leave it out. |
| Test-run evidence: "all 41 tests still pass", "reproduced it" | The consequence for the user of the code. |
| Explicit confidence: "high confidence", "I'm 80% sure", "may potentially" | State it (verified) or ask it (unverified). The "your call" hedges in Area 1 are fine. |
| Consequence chains ("so…, which…, because…") and generic "a future reader might…" | One concrete consequence, or none. |
| History: "this was added when…", "previously", internal finding IDs | Describe the code as it is now. One before-and-after clause for a behaviour change is fine. |
| Coined terms the code doesn't use ("the gate", "the fill path") | The code's own names, in backticks. |
| Replacement prose for comments or docs | Say what's wrong with them and where the content belongs. |
| "Relatedly…" and "Also…" asides | Its own finding, ranked on its own, or drop it (hard rule 8). |
| Praise sandwiches, generic praise ("Great PR!"), thanks, greetings | At most one specific praise line, in the body (Area 4). |
| Sign-offs, persona names, "Generated with…" footers, collapsed prompt blocks | Never. |
| "Withdrawn" or "Edit:" blocks added to a posted comment | A one-line reply (Area 5). |
| Em dashes, semicolons, parentheticals, emoji | Short plain sentences. |

## Area 4: review body and event

The body is five lines or fewer (hard rule 9), and one line is usual. In order:

```
<verdict>
<one line per PR-level finding with no diff line, in the Area 2 shape>.
```

- **The verdict is one line.**
  - When something must be fixed, the must-fix line is the verdict. It names only the Breaking
    change, Critical and Blocking items, as two-to-five-word noun phrases: "Needs fixing before
    merge: the SQL injection in `Search` and the missing rollback."
  - Otherwise: "Nothing blocking." or "Nothing blocking, a few things to fix."
  - The verdict covers every standing must-fix finding (hard rule 13), including ones only other
    reviewers' open threads raise: "Nothing blocking beyond the open thread on the write loop." or
    "Nothing blocking beyond the open threads on the write loop and the cache key." Never write
    "Nothing blocking" over one.
- **Optional lines,** used only while the body stays within five lines:
  - a theme that recurs across the PR, in one line, when it replaces several inline comments;
  - what wasn't reviewed, when it matters ("Didn't review the migration scripts.");
  - one praise line, only if the findings name a concrete strength ("Good call moving the retries
    into `RetryPolicy`."). Never generic praise, and never thanks for the PR.
- **If the body would pass five lines,** drop the optional lines first, then merge PR-level findings
  into one line. Never drop the verdict or a must-fix item.
- **`COMMENT` and `REQUEST_CHANGES` always carry the verdict line,** because the verdict is where
  severity lives. GitHub itself accepts an empty body on a `COMMENT` review that has inline comments
  (tested on 2026-10-22), so this is the skill's rule, not the API's. Only an `APPROVE` body may be
  empty.
- **Never** counts by rank, mention of the console list, process (passes, reviewers, tools, runs), a
  sign-off or a footer. Area 3 applies to every line except the must-fix list.

Review event: `COMMENT` unless the request names another (hard rule 13). When the user does choose:
- `REQUEST_CHANGES` means "I want another look", and fits any must-fix verdict, however short.
- `APPROVE` means everything posted is optional to act on. Say so in the body: "Nothing blocking.
  Fix or merge as you like."

The body must agree with the event.

## Area 5: workflow

1. **Collect.** Read the findings (a review run directory, a findings file, or the conversation,
   including PR-level items in earlier review summaries), the PR state and head sha
   (`gh pr view <n> --json state,headRefOid`), and the open review threads (GraphQL `reviewThreads`
   with `isResolved`). If the PR is merged or closed, stop and say so.
2. **Triage.**
   - Use each finding's latest wording. Drop findings their own reviewer withdrew; if a withdrawal
     keeps a remnant with its own grade, treat the remnant as a finding.
   - Drop findings the current head no longer supports.
   - Drop duplicates of open threads (hard rule 11), and note any that are must-fix (hard rule 13).
   - Keep each finding's grade and rank the ungraded ones (Area 1).
   - Move Optional and Nit items to the console list.
3. **Rewrite.** Put each ranked finding into the Area 2 shape. You can delegate this step to the
   `pr-comment-editor` agent with the ranked findings, the intended event and any standing must-fix
   threads as input.
4. **Merge repeats and anchor.** Fold repeated findings into one comment (hard rule 8). Confirm each
   line is in the PR diff (`gh api --paginate repos/<o>/<r>/pulls/<n>/files`). Move any finding that
   can't be anchored to the review body.
5. **Check.** Count the words in every inline comment against hard rule 4 and read each one against
   Area 3. Check the body against Area 4. Rewrite anything that fails.
6. **Show or post.**
   - Without an explicit instruction to post, print the drafts and the step 7 report, then stop.
   - With one, check hard rule 13 first. If you think any lower-graded finding could block, print it
     and ask before posting. Then post a single review,
     `gh api -X POST repos/<o>/<r>/pulls/<n>/reviews`, with `event`, `commit_id` set to the head
     sha, the body, and the comments as `{path, line, side, body}`, where `side` is `RIGHT`, or
     `LEFT` for a deleted line.
7. **Report to the console.** Console lines are not PR text, so Area 3 doesn't apply to them. Print:
   - each comment's rank, `file:line` and word count, plus a link once posted;
   - the Optional and Nit list, one short line each, as `- <Rank>: <claim>; <fix> (file:line)`,
     using `(PR description)` for items with no file;
   - candidate replies to open threads (hard rule 11), written to the reply rules below, because they
     may become PR text;
   - standing must-fix findings raised only in other reviewers' threads;
   - any grade you think is wrong, and any graded finding that admits it wasn't verified;
   - anything left unposted, and why.

**Replies and corrections** (only when told to post them):
- **Concede in a few words** when the author shows a fact: "Fair enough." / "Right, I missed that."
- **Hold in one sentence** when a contract or design rule is at stake, naming the rule: "A value that
  can be null needs a nullable type."
- **Defer explicitly** otherwise: "Not how I'd test it, but your call."
- **Correct yourself** in a new one-line reply that starts "Actually, …". Never edit a posted comment
  into a "Withdrawn" block.
- No thanks and no recap. Don't reply to "Done" or "Fixed", and don't resolve the author's threads.

## Not covered here

- **Running the review itself.** Use a review skill or `/code-review`. This skill starts from its
  findings, and never adds findings of its own.
- **Comments in code.** This skill shapes review comments, not code comments or docs.
- **Fixing the code.** See Roadmap.

## Roadmap (not this iteration)

The end goal is that review needs no PR comments. Agents resolve each finding themselves: they edit
the code, author the commit, and push to the PR branch with a concise commit message tied to the PR
and, where one exists, the ticket, for example `TICKET-123: Return early until the cache loads`. PR
comments then shrink to decisions only a human can make. Until that exists, this skill covers ranking,
wording and posting.

## Further Reading

- `../../training-materials/code-review-comments/verbose-vs-concise-comments.md`: generic
  before/after rewrites of AI-drafted review comments, the reference reviewer's style in numbers, and
  examples of each comment type.

This skill remains complete if the reference is unavailable. The reference is supplementary
background only.

## How to apply this skill in practice

1. Findings exist and the user wants them on a PR: run the full workflow, and post only if the request
   says to post.
2. The user wants drafts shortened: run steps 2–5 and print the result.
3. A finding is Optional or a Nit: print it to the console and never post it.
4. A comment won't fit the limit: it is probably two findings, or it is carrying narration. Split it
   or cut it.
5. A comment has a label, a heading or a "Suggested fix" section: delete the scaffolding and keep the
   one sentence that says what to change.
6. When unsure, the Hard rules and the severity ladder above are the authoritative source.
