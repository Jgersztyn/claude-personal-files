# PR comments: before and after

Training material for `skills/jg-pr-comment-editor` and `agents/pr_comment_editor.md`.

**Source:** the two review passes posted on Climavision/Athena PR #373 on 2026-10-21. JG judged them too
verbose. The "Before" text is reproduced **verbatim, flaws included**. The "After" text is the target
shape under the skill's rules. The skill is authoritative; this file only illustrates it.

## Reading notes

- The "Before" comments were graded on an older scale (Should fix / Optional). "Should fix" maps to
  **Needs to address** on the current ladder.
- Several "Before" comments were later edited on GitHub with second-pass corrections. This file keeps
  the text as first posted.
- Word counts are approximate (whitespace-split, markdown included).

## 1. Misleading log line

**Anchor:** `src/UI/Components/Widgets/HeatMapForecastTable/HeatMapForecastTableWidget.razor:209`. **Rank under the current ladder:** Needs to address.

### Before (160 words)

> **Should fix: the "Ignoring bound region" log fires for regions the table then shows.**
>
> Blazor marks the component initialized before `OnInitializedAsync` finishes, so a parent render while `GetLicensedPermissionKeys()` is pending reaches `OnParametersSetAsync` with `_boundRegion` still null and `_regionPermissions` still empty. `FindSelectableRegion("PJM")` then logs *not licensed or not offered*, and init goes on to show PJM. `PageWidget` re-renders on breakpoint changes and on a sibling's fill, so this is a normal path (`ParentRendersWhileRegionsLoad_ShowsTheBoundRegion` drives it).
>
> The fill path at `:158` has the opposite problem: it logs "Ignoring X", and the next line overwrites X with this table's default.
>
> This is the log added to answer "why didn't my variable stick?", so a wrong answer here costs more than no log.
>
> Suggested fix:
> - Return early from `OnParametersSetAsync` until the regions have loaded. Init already reads `Region` itself at `:122`, so nothing is lost.
> - Keep `FindSelectableRegion` a pure lookup, and log at the one call site that actually discards the value.

### After (49 words)

> **Needs to address:** A parent render during the permissions load reaches here before the regions load, so this logs "Ignoring bound region PJM" for a region the table then shows. Return early from `OnParametersSetAsync` until the regions load, and log only where a value is actually dropped (`:124`, `:197`).

**What was cut:** The Blazor lifecycle explanation, the second call path and the "why the log matters" paragraph. An author fixing the guard needs none of them.

## 2. Design question with options

**Anchor:** `src/UI/Components/Widgets/HeatMapForecastTable/HeatMapForecastTableWidget.razor:202`. **Rank under the current ladder:** Needs a decision.

### Before (194 words)

> **Needs a decision: the shared resolver this PR defers is already on `main`.**
>
> The Follow-ups say this matching moves onto `IRegionForecasts.FindVisibleAsync` "once #370 merges". #370 merged today (`0ad46477`) and is in this PR's base. `RegionForecasts.cs:69-72` applies the same trim, case-insensitive and licensed-only rule, so the widget now holds a second copy of a permission rule. Rules 3 and 5 of `widget-composition.md` exist to prevent that.
>
> Nothing breaks today. The risk is drift: if the visibility rule changes in `RegionForecasts`, a `?region=` value is accepted by one widget and rejected by this one.
>
> Relatedly, the same value is compared four ways in this file: `:119`, `:193` (case-insensitive, no trim), `:207` (trimmed, case-insensitive) and `:197`/`:215` (ordinal). `Athena.Domain.Region` already has case-insensitive equality. Parsing the bound string into `Region?` once at the edge would make each of these a plain `==`.
>
> Options:
> - (a) Resolve through `FindVisibleAsync` here, then intersect with `AllowedRegions`, which that service doesn't apply. `FindSelectableRegion` becomes async, so the load-race guard needs re-checking.
> - (b) Keep it as is and update the Follow-up. It is unblocked now, so state the real reason for deferring, for example keeping the resolver swap separate from this behaviour change.

### After (40 words)

> **Needs a decision:** #370 has merged, so `RegionForecasts` already applies this licensed-region rule, and the widget now duplicates it. Either use it here (intersect with `AllowedRegions`, keep the lookup synchronous), or update the Follow-up with the real reason for deferring.

**What was cut:** The "Relatedly…" aside about four comparison rules (a separate finding, Optional at most) and the sub-bullets under each option.

## 3. Test gap backed by a mutation

**Anchor:** `tests/Tests.Component/UI/Components/Widgets/HeatMapForecastTableRegionBindingTests.cs:201`. **Rank under the current ladder:** Needs to address.

### Before (164 words)

> **Should fix: this test can't tell "read `Region` after the permissions load" from "read it before".**
>
> It renders `Pjm`, re-renders with the same `Pjm`, then opens the gate. A mutant that captures `Region` before the await at `:115` and uses it at `:124` passes all 34 tests (run on an isolated copy of the head).
>
> Example: table B's permissions are still loading when table A fills the empty shared variable with ERCOT. B offers ERCOT, but under the mutant it initializes from the stale empty value and shows its own default. Its fill sees a non-blank `Region` and writes nothing, and its post-init `OnParametersSetAsync` returns early because `_boundRegion` already equals ERCOT. The two tables stay on different regions.
>
> Suggested fix: start from a different value. This passes on the head and fails on the mutant:
> ```csharp
> var cut = Render(Ercot, _ => { });
> cut.SetParametersAndRender(p => p.Add(w => w.Region, Pjm));
> permissionsLoaded.SetResult();
> ShouldShow(cut, Pjm);
> ```
> The `_ReportsNothing` twin at `:207` can take the same change.

### After (33 words)

> **Needs to address:** This passes `Pjm` both before and after the gate, so a version that reads `Region` before the await still passes all 34 tests. Start from `Ercot` and re-render with `Pjm`.

**What was cut:** The multi-table failure walkthrough and the 5-line code block. The one-sentence fix says the same thing. Keep "all 34 tests still pass": it is the evidence.

## 4. Documentation that overstates an invariant

**Anchor:** `src/UI/Components/Widgets/HeatMapForecastTable/HeatMapForecastTableWidget.razor:190`. **Rank under the current ladder:** Needs to address.

### Before (127 words)

> **Should fix: "widgets sharing it never overwrite each other" isn't true of the fill path.**
>
> `FillEmptyRegionAsync` (`:147`, `:158-159`) does replace a sibling's fill that this table doesn't offer. That is the designed behaviour, and the comment two methods up says so. The PR body makes the same global claim, then describes the overwrite two paragraphs later.
>
> Example: someone debugging two tables offering `[A, C]` and `[B, C]` sees the variable go A → B. They read this line as an invariant and go looking for a bug in `PageState`.
>
> Suggested fix: scope it to this method, for example `// A later bound value this widget can't take is left in the variable, so following a change never writes.` Make the same edit to the PR body sentence.

### After (40 words)

> **Needs to address:** The load fill at `:158-159` does overwrite a sibling's value, so "never overwrite each other" is wrong. Scope it to this method ("following a later change never writes"), and fix the same sentence in the PR body.

**What was cut:** The debugging scenario and the full replacement comment.

## 5. Optional item: console only, not posted

**Anchor:** `src/UI/Components/Widgets/HeatMapForecastTable/HeatMapForecastTableWidget.razor:141`. **Rank under the current ladder:** Optional (console only).

### Before (88 words)

> **Optional: tables that never bind `Region` now always yield on load.**
>
> `ComparisonHeatmap.razor:21`, `ClimatologyView.razor:42` and the Forecast Table page (`KnownPages.cs:1207`) don't bind `Region`, but they now run `Task.Yield()` and an empty `RegionChanged` on every load. Once `GetLicensedPermissionKeys` is cached, init used to finish synchronously. Now it never does, which adds a render pass in code paths the PR says are unchanged.
>
> Suggested fix: `if (defaultRegion is not null && RegionChanged.HasDelegate)`. `PageWidget` wires `RegionChanged` only when `Region` is bound, so this matches the intent that only a bound table fills.

### After (16 words)

> - Optional: unbound embedders now yield once on every load; guard the fill with `RegionChanged.HasDelegate` (HeatMapForecastTableWidget.razor:141).

**What was cut:** The whole comment. Under the current rules it is printed in the console summary as one line and never posted.

## 6. Tandem / description issue posted in the review body

**Anchor:** `(review body)`. **Rank under the current ladder:** Needs to address.

### Before (257 words)

> **Second pass.** Eight fresh reviewers covered the same lenses. They looked for what the first pass missed and checked its findings, with mutations run on an isolated copy of the head. **Still nothing blocking.**
>
> Corrections to my first-pass comments are edited into those threads and marked:
> - **Withdrawn:**
>   - `:135` (drain not pinned): the overlapping-pair tests already do a positive check after `FinishLoadAsync`.
>   - `:467` (later-pass test): executed, and the mutant it targets already fails existing tests.
> - **Amended:**
>   - `:209`: log at both discard sites, not one.
>   - `:202`: keep the resolver lookup synchronous; option (a) as written adds an await race.
>   - `:144`: the suggested rewrites dropped a fact.
>   - `:471`: the helper name should be a verb.
>   - `:195`: five other "Region Key" parameters.
>
> New, inline: four **Optional** items.
>
> PR-level, not anchored to a line:
> - **Should fix (description): the `isFilledByWidget` tandem note only covers the first write.** `PageUrlState.ReplacesHistory` (`PageUrlState.cs:25-27`) replaces history only while the URL lacks the key. When a second table overwrites a sibling's fill it can't show, the key is already in the URL, so that write pushes an entry. The tests depend on that overwrite: the wide-first overlapping pair settles after two writes, ERCOT then PJM. On a URL-synced page with `[ERCOT, PJM]` placed before `[PJM]`, Back moves the wide table to ERCOT, a region nobody chose, and leaving the page takes a second Back. No code change is needed here. Correct the tandem note, and have the PageCore provisional-value follow-up treat replacing a widget-filled value as a history replace.

### After (51 words)

> Second pass: nothing blocking. Inline: 0 posted (4 Optional printed to console).
> **Needs to address:** `isFilledByWidget` covers only the first fill. A second table replacing a sibling's fill pushes a history entry, so Back lands on a region nobody chose. Correct the tandem note and cover it in the PageCore follow-up.

**What was cut:** The list of corrections to earlier comments (each correction goes on its own thread as one line) and the step-by-step Back scenario.

