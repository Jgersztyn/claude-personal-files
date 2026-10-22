# PR comments: before and after

Training material for `skills/jg-pr-comment-editor` and `agents/pr_comment_editor.md`. The skill is
authoritative; this file only illustrates it. Back to the skill:
[`../../skills/jg-pr-comment-editor/SKILL.md`](../../skills/jg-pr-comment-editor/SKILL.md).

## Reading notes

- **Source.** A study of one senior human reviewer, "the reference reviewer": more than 500
  thread-opening review comments and about 100 review summaries across about 160 PRs in more than 40
  repositories. The comparison set is 18 AI-drafted inline comments on one PR, judged too verbose by
  a dev lead: 17 from two review passes posted 16 minutes apart, plus 1 from an earlier approval. It
  also includes AI review-bot comments from the same codebases.
- **Everything here is generic.** The examples in sections 2 to 4 are written fresh for this file,
  and the "After" texts are short rewrites of the AI drafts. None is a quotation of any reviewer.
  Names, identifiers, file paths, line numbers, ticket keys and domain details are neutral (orders,
  catalogs, categories). The "Before" texts
  reconstruct the AI drafts with all of those changed. Some of the drafts' own AI phrasing is kept to
  show their shape, but no person's words are. Unlike the user-story examples, nothing in this file
  reproduces a person's words or any private identifier. Add new pairs the same way.
- **Word counts** split on whitespace, markdown included, and count prose only, not code blocks.

## 1. The reference style in numbers

| Measure | Reference reviewer (545 comments) | AI drafts (18 comments, as finally edited) |
|---|---|---|
| Median words per comment | 13 | about 150 |
| Median sentences | 1 | 10 |
| One sentence | 50% | 0% |
| Over 40 words | 9% | 100% |
| Opens with bold or a rank label | 0% | 100% |
| Any plain label (`nit:`, `future:`) | 9% | n/a |
| Asks a question | about 20% | 0% |
| "Suggested fix:" section | 0% | 67% |
| Line-number references | about 1% | 78% |
| Process narration ("I traced", "mutants", "second pass") | 0% | 50% |
| Opens with praise | 10% | 0% |
| Review body | median 12 words; none counts by rank | 209 and 257 words; counts by rank |
| What happened next | 45% of threads got a reply; 64% led to a code change | the 17 from the two passes drew no reply, reaction or fix |

On the same evening, another reviewer's two comments on that PR, also AI-drafted and 43 and 90 words
long, went unanswered too. So the silence alone isn't evidence about length. The rest of the table is.

How the reference reviewer carries severity without labels:
- **The review event.** Request changes means "I want another look", even for small things. Approve
  means everything left is optional.
- **The review body.** A verdict in a few words, and, when something blocks, a short list of what to
  fix.
- **The verb.** "please …", "needs to …" and "before merge" for must-fix; "can we …?" and "how
  about …?" for suggestions; "fine if intentional" and "fine to leave for now" for
  take-it-or-leave-it.
  In one sample, 8 of 9 firm comments were acted on, against 2 of 8 hedged ones.

Other human reviewers in the same codebases write the same way: median 12 words, about a quarter of
comments are questions, and none open with bold text. About 60% of the AI-written comments in those
codebases did.

## 2. Comment types

Each example below follows the skill's rules for a posted comment. The count after it is its word
count. Some kinds of finding (comment trimming, most naming, style and small simplifications) are
usually graded Optional or Nit, and then they only reach the console. Their examples show the
wording for when the input grades them higher.

**Problem plus fix**
- "Only `OrderService` calls this, so it can come off the interface." (11)
- "`OrderContext` is non-nullable, so this null check can go. Same for the others." (13)
- "Expose this as `string[]` so callers can't `Add` to it." (10)
- "`options` is non-nullable, so the compiler already guarantees it. The runtime null check can
  go." (15)

**A misleading name**
- "`IsValid` only checks the format, so callers will treat expired orders as valid. Please rename it
  `HasValidFormat`." (17)

**Stated firmly**
- "Please move off the preview package version before merge." (9)
- "Please put the HTTP calls behind an injected `IOrderClient`. As written, a unit test would need a
  live server." (19)
- "This breaks the single-file export. Please handle that case before merge." (11)

**Questions that carry the scenario or the alternative**
- "What happens if two requests create an order at the same moment? Both could read the same next
  number." (19)
- "Missing a `return;` after this guard? The guard above has one." (11)
- "These types already exist in `Common.Messaging`. Can we use those instead of a copy?" (14)
- "Could the standard compression library do this instead of the hand-written loop?" (12)

**A test that proves less than it claims**
- "This test checks the retry, not the caching its name promises. Please rename it
  `Get_ShouldRetry_IfPreviousCallFailed`." (15)

**A behaviour change with an exit**
- "This no longer stops at the first error the way the old loop did. Fine if that's intended." (18)

**Reader experience as evidence** (sparingly: at most one per review)
- "I had to read this twice to see why the cache is cleared here. Can the clear move into
  `Refresh`?" (20)

**Code comments and docs: what's wrong and where it belongs**
- "Please drop the expiry detail from this comment. It belongs to the cache and will go stale when the
  cache changes." (21)
- "This explains why the code changed, which belongs in the commit message. Please trim it to what the
  code does." (20)

**A fix that is code** (the code block doesn't count toward the word limit)
- "The range check is pure logic, but it can only be tested through the file system. Pull it into a
  static method a unit test can call:" (27)

  ```csharp
  public static bool IsInRange(DateOnly date, DateOnly from, DateOnly to)
      => date >= from && date <= to;
  ```

**A repeated finding**
- First site: "`OrderContext` is non-nullable, so this null check can go. Same for the others." (13)
- Another site, only when it needs a different fix: "This one can go too, but keep the log line." (10)

**Code the PR didn't change**
- "`RetryCount` is never read. Pre-existing, so no change needed in this PR." (12)

## 3. Review bodies

Line one is always the verdict.
- "Needs fixing before merge: the SQL injection in `Search` and the missing rollback." (with
  Request changes; the must-fix line is the verdict)
- "Nothing blocking, a few things to fix." (with Comment)
- "Nothing blocking beyond the open thread on the write loop." (another reviewer's thread holds the
  only blocker)
- "Nothing blocking. Fix or merge as you like." (with Approve, and only when no must-fix finding
  stands)
- "Didn't review the migration scripts." (an optional line)
- "Good call moving the clock behind `FakeClock`." (the one specific praise line, also optional)

None of them counts comments by rank, restates the inline comments, or describes how the review was
done.

## 4. Replies and corrections

- Conceding a fact: "Fair enough." / "Right, I missed that. The first assignment to `_currentId` is
  still redundant, though."
- Holding a principle: "A value that can be null needs a nullable type."
- Deferring: "Not how I'd test it, but your call."
- Correcting yourself: "Actually, the logger names that field for you, so this is fine."

## 5. AI drafts, before and after

All seven come from one PR: a catalog table that follows a page-level `Category` variable shared
between widgets. Ranks are on the skill's current ladder.

### 1. Misleading log line

**Rank:** Needs to address.

**Before (about 160 words):**

> **Should fix: the "Ignoring bound category" log fires for categories the table then shows.**
>
> Initialization counts as complete before `OnInitializedAsync` returns, so a parent
> render while `GetEnabledCategories()` is pending reaches `OnParametersSetAsync` with
> `_boundCategory` still null and `_enabledCategories` still empty. `FindCategory("Books")` then
> logs *not enabled*, and init goes on to show Books. The page re-renders on layout changes and on a
> sibling's fill, so this is a normal path (`ParentRendersWhileLoading_ShowsTheBoundCategory` drives
> it).
>
> The fill path at `:64` has the opposite problem: it logs "Ignoring X", and the next line
> overwrites X with this table's default.
>
> This log exists to explain why a bound value was ignored, so a misleading entry here is worse than
> no entry at all.
>
> Suggested fix:
> - Return early from `OnParametersSetAsync` until the categories have loaded. Init already reads
>   `Category` itself at `:41`, so nothing is lost.
> - Keep `FindCategory` a pure lookup, and log at the one call site that actually discards the value.

**After (24 words):**

> This logs "Ignoring category Books" while the categories are still loading, for a category the table
> then shows. Please return early until they've loaded.

**What was cut:** the bold title, the lifecycle explanation, the "why it matters" paragraph and the
line references. The second call path is a separate finding (hard rule 8), so it gets its own comment
(25 words):

> This logs "Ignoring X", then the next line overwrites X with this table's default. Please log only
> where a value is actually dropped, not here.

**Caveat:** in the real case another reviewer had already opened a thread on the main finding minutes
earlier. Under hard rule 11 the right output was only the second comment above, with nothing
re-filed, plus a candidate reply on that thread if the finding added a new fact.

### 2. Design question with options

**Rank:** Needs a decision.

**Before (about 170 words):**

> **Needs a decision: the shared resolver this PR defers is already on `main`.**
>
> The Follow-ups say this matching moves onto `ICategoryRules.ResolveAllowedAsync` "once the resolver
> PR merges". It merged today and is in this PR's base. `CategoryRules.cs:30-33` applies the same
> trim, case-insensitive and enabled-only rule, so the widget now holds a second copy of a permission
> rule. The team's widget guidelines exist to prevent that.
>
> Nothing breaks today. The risk is drift: if the visibility rule changes in `CategoryRules`, a
> `?category=` value is accepted by one widget and rejected by this one.
>
> Relatedly, the same value is compared four ways in this file: `:52`, `:88`, `:95` and `:91`/`:99`.
> The domain `Category` type already has case-insensitive equality. Parsing the bound string into
> `Category?` once at the edge would make each of these a plain `==`.
>
> Options:
> - (a) Resolve through `ResolveAllowedAsync` here, then intersect with `AllowedCategories`. The lookup
>   becomes async, so the load-race guard needs re-checking.
> - (b) Keep it as is and update the Follow-up with the real reason for deferring.

**After (22 words):**

> The resolver PR has merged, so `CategoryRules` already applies this rule. Can we use it here rather
> than keep a second copy?

**What was cut:** the options menu (the question invites the author's reason, which covers option
b), the drift paragraph, and the "Relatedly" aside. The aside is a separate Optional finding, so it
goes to the console. **Caveat:** in the real case another reviewer's open thread had already asked
for one shared rule. Under hard rule 11 the right output was a candidate reply carrying the new fact
(the resolver PR has merged), not a new comment. The After shows the wording had no thread existed.

### 3. Test gap backed by a mutation run

**Rank:** Needs to address.

**Before (about 165 words):** a bold "Should fix" title; "A mutant that captures `Category` before
the await passes all 41 tests (run on an isolated copy)"; a five-sentence walkthrough of two tables
drifting apart; and a "Suggested fix" with a five-line test.

**After (19 words):**

> Both renders use Books, so this still passes if `Category` is read before the await. Start from
> Games instead.

**What was cut:** the mutation run (test-run evidence is an AI tell), the walkthrough and the code
block. The one-sentence fix says the same thing.

### 4. A doc comment that overstates an invariant

**Rank:** Needs to address.

**Before (about 127 words):** a bold "Should fix" title quoting the comment; two line references to
the fill path; a debugging scenario ("someone sees the variable go A → B…"); and a "Suggested fix"
with full replacement comment text.

**After (27 words):**

> Not quite: loading does replace a sibling's value, so "never overwrite each other" is wrong. Please
> scope it to later changes, here and in the PR description.

**What was cut:** the scenario, the line references and the replacement prose. The comment says what
is wrong and lets the author word the fix. The PR description repeats the same sentence, so it is
covered in the same comment rather than filed twice.

### 5. Optional item: console only

**Rank:** Optional, so it is never posted.

**Before (about 88 words):** a bold "Optional" title, three embedding pages listed with line numbers,
a paragraph on render passes, and a "Suggested fix" with an `if` condition.

**After (console line):**

> - Optional: unbound tables now yield once on every load; guard the fill with
>   `CategoryChanged.HasDelegate` (CatalogTable.razor:57)

### 6. Review body for a second pass

**Rank:** Needs to address, for the one PR-level finding.

**Before (about 257 words):** "**Second pass.** Eight fresh reviewers covered the same lenses…
mutations run on an isolated copy. **Still nothing blocking.**", a list of withdrawn and amended
first-pass comments with line numbers, "New, inline: four **Optional** items.", and a 140-word
PR-level finding with a step-by-step Back-button scenario.

**After (33 words):**

> Nothing blocking.
> The description's note on `isAutoFilled` covers only the first fill. A second table replacing it
> pushes a history entry, so Back lands on a category nobody picked. Please correct the note.

**What was cut:** the process, the counts, the list of corrections and the scenario. A second pass
shouldn't exist: verify before posting, post once, and correct a posted comment with a one-line
reply only when told to.

### 7. A label that contradicted the finding

**Rank:** graded "Needs a decision (non-blocking)" in the input. Another reviewer's open thread had
already graded the same loop Blocking, with a reproduction.

**Before (about 240 words):** "**Needs a decision (non-blocking):** write-back can loop between two
widgets on one variable", posted with an approval, including "I traced this by reading the code and
did not run it", three paragraphs of scenario, and options (a) and (b).

**What the skill does with it:**
- It keeps the input grade, minus the "(non-blocking)" decoration, and flags the grade as too low in
  the console.
- It drops the comment as a duplicate of the open thread (hard rule 11).
- The open Blocking thread still counts as a standing must-fix finding, so the verdict is "Nothing
  blocking beyond the open thread on the write loop."
- If the request named `APPROVE`, the skill refuses to post and says why (hard rule 13). Under
  any other event, it asks the user about the flagged grade before posting (step 6).

**After, had no one else raised it and the input graded it Blocking (27 words):**

> Two tables sharing a variable but allowing different categories keep overwriting each other, an
> endless write loop. Please write back only on a user pick before merge.

**After, had it been ungraded and unverified (Needs research, 20 words):**

> What happens when two of these share a variable but allow different categories? Looks like they'd
> keep overwriting each other.

**What was cut:** the "(non-blocking)" decoration and the approval, which told the author a
reproduced infinite loop could merge. The wording, the verdict and the review event carry severity,
so they must agree with every standing must-fix finding, including ones in other reviewers' threads.
