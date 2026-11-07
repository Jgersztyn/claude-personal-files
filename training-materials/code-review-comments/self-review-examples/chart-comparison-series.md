# Self-review: comparison series on a sales chart

A generic reconstruction (see the [reading notes](README.md#reading-notes)).

- **Change:** "Week over week" and "Month over month" toggles on a daily sales chart and its table.
  Each toggle adds or removes that comparison's change series. The toggles use a new reusable
  multi-select toggle group component. 13 files, about +490/-25.
- **Status:** drafts only. Nothing was posted. If these are posted, the intended review event is
  `COMMENT`.
- **How it was produced:**
  - Round 1: a multi-agent team review with eight fresh-context reviewers (silent failures,
    completeness, systems fit, architecture, standards, test coverage, readability, docs accuracy).
  - Round 2: three agents. An adversarial check of the round-1 worklist plus a fresh look for misses.
    A test-cut check: 37 mutations on a scratch copy, each followed by a rebuild and the full test
    suites. A browser check of the chart on two hosts.
  - The comments were then styled under the `jg-pr-comment-editor` rules.
- **Standard set for this review:** "only high-value tests".

## What this example shows

- A finding round 1 graded Blocking was closed by evidence (a browser check), not a code change. The
  review body asks for manual validation steps because the repo can't hold that check as a test.
- A Needs research comment is a question that offers the fix if the answer is "none".
- A comment can ask for a comment: a deliberate absence (no `@key`) is load-bearing and needs one line.
- Mutation runs back every test cut. None of round 1's proposed test sets survived them.
- Findings that weren't worth filing are listed with a reason, so nobody re-files them.

## PR comments

- src/Sales/SalesChart.razor:97 · Needs to address · 24 words
  This comment is out of date, since both comparisons now start on. Please describe the both-off case, the only one that still needs `ShowLegendForOneSeries`.

- src/Sales/SalesChart.razor:152 · Needs to address · 27 words
  Please add a one-line comment on why the series loop has no `@key`. Adding one swaps the line colours when week over week is turned back on.

- tests/TestHost/Properties/launchSettings.json:1 · Needs to address · 17 words
  IDE-generated launch profile that nothing uses. Please drop it, and the one in the second test host.

- tests/Components/MultiToggleGroupTests.cs:20 · Needs to address · 29 words
  With the value as its own label, a dropped label binding still passes, since the toggle shows the value anyway. Please upper-case the labels and expect WOW and MOM.

- tests/Components/MultiToggleGroupTests.cs:28 · Needs to address · 13 words
  The click tests below catch everything this does. Please cut it and `Render_BothValues_BothOn`.

- tests/Sales/SalesWidgetRefreshTests.cs:105 · Needs to address · 25 words
  Please rename this `Refresh_NewerData_KeepsComparisonSelection`, since it checks the selection, not the rows. Please also call `RefreshNow(cut)` directly, because the polling test owns the real timer.

- tests/Sales/SalesWidgetTests.cs:1029 · Needs to address · 15 words
  `Render_WithData_ShowsRowPerSeries` already pins the default these two check. Please cut this and the next test.

- tests/Sales/SalesWidgetTests.cs:1047 · Needs to address · 23 words
  The chart gets the same rows as the table, so the table tests already catch this. Please cut it and its re-select twin.

- src/Sales/SalesChart.razor:54 · Needs research · 16 words
  What case does this `Task.Yield()` cover? If none, please drop it and its comment as speculative.

- src/Sales/SalesChart.razor:56 · May be important · 30 words
  Probably fine, but hiding one comparison in the legend and then turning the other off throws an uncaught script error in the console. Fine to leave for a follow-up ticket.

## Review body

```
Nothing blocking, a few things to fix.
Please add manual validation steps to the PR description, since no browser test covers the redraw: each toggle off and on, both off, and the chart embedded at half height.
Please split as agreed, with the toggle group component, its story and its tests going first as their own PR.
```

## Console only (not posted)

- Optional: `@bind-Values` with `:after` replaces the change handler and its summary, with the same behaviour; the pattern is already used elsewhere in the project (SalesWidget.razor:289)
- Optional: the field summary repeats the initialiser; delete it (SalesWidget.razor:46)
- Optional: use the spacing utility class instead of a hand-written padding, as the neighbouring button group does (MultiToggleGroup.razor.css:7)
- Optional: no component test checks that `Class` is forwarded, so the first PR alone wouldn't catch it being dropped; add a one-line render test (MultiToggleGroupTests.cs)
- Optional: the stylesheet is a near-copy of the button group's, with nothing keeping them in sync; follow-up: share one stylesheet (MultiToggleGroup.razor.css:1)
- Optional: UX note, any comparison toggle clears every legend hide, including hides on the other comparison's series (SalesChart.razor:56)
- Nit: a commit subject has a typo for "WoW"; fix it when re-cutting for the split

## Notes

- **Ranking.** The test cuts are Needs to address only because "only high-value tests" was set as
  the standard for this review. Every cut is backed by the mutation runs. None of round 1's five
  proposed kept sets survived that check: each would have deleted a test that is the only catch for
  some bug.
- **The blocking finding was closed by evidence.** Round 1 graded "the chart redraw after a toggle
  has no test or recorded check" as Blocking. The round-2 browser check passed every toggle scenario
  on both hosts, so it no longer blocks. The repo has no browser-test harness, so the review body
  asks for manual steps instead.
- **Merged comments.** Each pair of redundant tests is one comment, anchored on the first and naming
  the second. The two launch profiles are one comment.
- **What was checked how.** The `Task.Yield` question rests on a reconstruction around the real
  chart, not the signed-in app, which is why it's a question. The `@key` claim and the script error
  were measured in the browser check.
- **Dropped, not filed.**
  - Merging two duplicated `if` blocks in the row builder: churn, and main had the same duplication.
  - Rewriting the existing tests that use a row count to mean "loaded": a drive-by.
  - Switching to the design system's radius tokens: no matching step exists, and it would break the
    match with the neighbouring groups.
- **Verdict.** No grade looks wrong, and no must-fix finding stands, so `COMMENT` fits.

## Appendix: the test suite after the recommended changes

The branch adds 24 test methods. The posted comments cut 8, leaving 16.

| Test | Recommendation | The one bug it uniquely catches |
|---|---|---|
| `Build_MonthOverMonthAlone_KeepsItsColour` | Keep | Colours assigned by position, so a series changes colour when the other is off |
| `Render_OffersEveryItemInOrder` | Keep, upper-case the labels | The label binding not applied |
| `Render_NoValues_...`, `Render_BothValues_BothOn` | Cut | Nothing the click tests miss |
| `Click_OnTheOnlyItemOn_ReportsEmptySelection` | Keep | An empty selection swallowed |
| `DeselectingAComparison_RemovesItsSeriesFromTheChart` | Keep | The chart fed unfiltered rows while the table is right |
| `DeselectingBoth_LeavesOnlyTheValueRow` | Keep | An empty selection turned back into "all" |
| `Refresh_NewerData_KeepsComparisonSelection` | Keep, rename | A background refresh resetting the selection |
| Chart and default pairs | Cut | Nothing the table tests miss |

## Appendix: evidence

- **Browser check on two hosts:** the default view, each comparison off, both off, and each off and
  on again in both orders all draw the right series, order, colours and legend.
- **Load-bearing checks, each applied alone:** adding `@key` re-orders and re-colours the series;
  removing the one-series legend flag hides the legend with both off; removing `Task.Yield` changes
  nothing observable.
- **Mutation runs:** all 37 compiled. Three survive every test (`@key`, the legend flag,
  `Task.Yield`); only the browser check covers those.

## Appendix: pre-existing, not this PR

- A row label's doc comment says it comes from the source file, which isn't true for the running
  total rows.
