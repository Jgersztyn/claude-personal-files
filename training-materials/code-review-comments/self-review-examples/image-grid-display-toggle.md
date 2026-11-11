# Self-review: a display toggle on an image grid

A generic reconstruction (see the [reading notes](README.md#reading-notes)).

- **Change:** a "Fill window" toggle on a catalog page's grid of product image tiles. Checked, the
  grid sizes its tiles to fill the window. Unchecked, tiles keep a fixed size and the grid scrolls.
  17 files, about +650/-40, most of it tests.
- **Status:** drafts only. No PR exists yet. If one is opened, the intended review event is
  `COMMENT`.
- **How it was produced:**
  - Two rounds of a multi-agent team review. Round 1 used eight fresh-context reviewers. Round 2
    used three: an adversarial check of the worklist, the safety of the proposed test cuts, and a
    fresh look for misses.
  - Executed evidence came from a scratch copy outside the repo: mutation runs, and a headless
    browser over a component-story build.
  - The comments were then styled under the `jg-pr-comment-editor` rules.
- **Standard set for this review:** "only high-value tests".

## What this example shows

- An explicit review standard can raise a rank. Test cuts that would normally be Optional are
  Needs to address here, and the notes say why.
- A test comment names the one number that makes the test useful ("a literal 6"), not just "use a
  literal".
- A conflict with the ticket is a Needs a decision, not a bug: both answers in one sentence, a lean, and
  "Please …".
- Measured but unlikely risks are hedged May be important lines that end in a "fine to leave" exit.
- The appendix gives each kept test the one bug it uniquely catches, which is what justifies every cut.

## PR comments

- src/Catalog/ProductGridPanel.razor:94 · Needs to address · 30 words
  This comment says a layout change can land here, but layout changes remount the panel. Only the toggle does, so please say that, and that a missing image isn't re-requested.

- tests/Catalog/ProductGridTests.cs:294 · Needs to address · 24 words
  All four rows of `Unfilled_NoColumnsSaved_TilesByCount` take the same branch and catch the same bug. Please make it one `[Fact]` with five tiles, expecting 6.

- tests/Catalog/ProductGridTests.cs:310 · Needs to address · 31 words
  Computing the expected value with `TileLayout` hides the number that makes this test useful, so a layout bug could still pass. Please use a literal 2 here, and 5 at :334.

- tests/Catalog/ProductGridTests.cs:316 · Needs to address · 33 words
  Only the two five-tile rows can fail, since a span hard-coded to 1 passes the rest. Please keep those and assert every span equals the first, so a track-count change doesn't break it.

- tests/Catalog/ProductGridPanelTests.cs:332 · Needs to address · 27 words
  Production never reaches this default, since the page always binds the setting. The next test repeats `Unfill_GridShown_UnfillsIt`. Please cut both and put `RenderPanel` back as it was.

- tests/Catalog/ProductGridPanelTests.cs:378 · Needs to address · 16 words
  `CatalogChanged_SameImage_ShowsTheNewImage` can't tell catalogs apart, because the fake ignores the catalog key. Please rename it `CatalogChanged_ImageMissingEarlier_ShowsIt`.

- tests/Catalog/GridControlsTests.cs:115 · Needs to address · 14 words
  `Uncheck_TilesFilled_UnfillsTheTiles` checks only the page setting and renders no tiles. Please rename it `Uncheck_TilesFilled_ClearsFillWindow`.

- tests/Catalog/GridControlsTests.cs:125 · Needs to address · 13 words
  This mirrors the uncheck test and catches nothing it doesn't. Please cut it.

- tests/Catalog/TileLayoutTests/WithFixedLastRowMethod.cs:18 · Needs to address · 26 words
  `AllRowsFull_TilesAsBefore` can't fail, since a full last row already matches the others. The other test repeats a row from the grid theory. Please delete the file.

- src/Catalog/ProductGrid.razor:96 · Needs a decision · 47 words
  Unfilled, a short last row leaves blank space on its right, which the ticket rules out. Either the reporter accepts the gap, or we drop `WithFixedLastRow` so the last row's tiles render larger. I lean towards dropping it. Please do that unless the reporter accepts the gap.

- tests/Catalog/ProductGridPanelTests.cs:414 · Needs a decision · 42 words
  This passes with the guard deleted, so it only pins where the guard sits relative to the rebuild. Either cut it and its test hook, or keep it and say so in its comment. I lean towards cutting both. Please remove them.

- src/Catalog/ProductGrid.razor:10 · May be important · 29 words
  Probably fine, but on a page of only banner tiles, unchecking widens nothing and shrinks a lone banner to the fixed height. Fine to leave for a follow-up ticket.

- src/Catalog/ProductGrid.razor:98 · May be important · 39 words
  Probably fine, but with no saved column count, unfilled mode picks columns from the tile count, so two tiles shrink by a quarter in a small square window. Taking the smaller count fixes it, but it's fine to leave.

- src/Catalog/ProductGrid.razor.css:122 · May be important · 38 words
  Scrolling works only because the `div` prefix outranks an equal-specificity rule in the page shell, so a shell change would quietly break it. An inner element could scroll instead, as `ReviewGrid` does. Fine to leave for a follow-up.

## Review body

```
Nothing blocking, a few things to fix.
Please say in the PR description that the toggle isn't saved, starts checked, and resets when the page is re-saved. Product should confirm the reset.
Please also say why the controls are one composite component, and why this is one PR.
Please squash on merge, so the store the first commit added never reaches main.
```

## Console only (not posted)

- Optional: the field holding the last request always repeats the current key; hold only the image id and guard on both (ProductGridPanel.razor:62)
- Optional: `WithFixedLastRow` keeps a track count only a stretched row needs; reset it to one track per tile, and decide this before writing the test literals (TileLayout.cs:87)
- Optional: two CSS declarations are no-ops, and one shorthand replaces the overflow pair (ProductGrid.razor.css:125, :126)
- Optional: merge the two checkbox render tests into one theory over true and false, since each case catches a different dropped binding (GridControlsTests.cs:99)
- Optional: the reason the setting ids are static lives only in a test comment; move it to the production comment (LayoutMapper.cs:17)
- Optional: name the new options component for what it renders, e.g. `FillWindowCheckBox`, since every other `*Options` type is a settings object (GridOptions.razor)
- Nit: the checkbox label is a size larger than the text beside it (GridOptions.razor:5)
- Nit: two long test comments to tighten (ProductGridTests.cs:262; GridControlsTests.cs:151)

## Notes

- **Ranking.** The test cuts are Needs to address only because "only high-value tests" was set as
  the standard for this review. Otherwise they would be Optional.
- **Order of work.** Settle the short-last-row decision (`ProductGrid.razor:96`) and the track-count
  item before writing the literals in the `:294`, `:310` and `:316` comments. Those literals assume
  today's track counts.
- **What was checked how.** The scrolling claim (css:122) was checked in a reconstruction, not the
  signed-in app. The banner-only finding (`:10`) was measured on a real story build. The window-size
  figures (`:98`) come from running the column solver as a script.
- **Merged comments.** The guard comment (`ProductGridPanel.razor:94`) also covers two test comments
  that repeat its wrong example.
- **Verdict.** No grade looks wrong, and no must-fix finding stands, so `COMMENT` fits.

## Appendix: the test suite after the recommended changes

The branch adds 28 test methods. The recommended suite keeps 18, or 17 if the `:414` decision is
"cut".

| Test | Recommendation | The one bug it uniquely catches |
|---|---|---|
| `Unfilled_NoColumnsSaved_TilesByCount` | One fact, literal 6 | Unfilled mode reads the window size |
| `Unfilled_ColumnsSaved_UsesSavedColumns` | Keep, literal 2 | Unfilled mode ignores the saved column count |
| `Unfilled_LastRowShort_KeepsFullRowSpan` | Two rows, assert equal spans | A short last row stretches |
| `FillAgain_WindowMeasuredWhileUnfilled_UsesThatSize` | Keep, literal 5 | The window isn't measured while unfilled, so refilling uses zero |
| `Unfill_ImageStillMissing_LeavesPanelAsItWas` | Keep | Guard deleted, so the toggle refetches |
| `CatalogChanged_SameImage_ShowsTheNewImage` | Keep, rename | Guard compares only the image id |
| `Unfill_GridShown_UnfillsIt` | Keep | The panel doesn't forward the toggle |
| Render-default pair | Cut | Nothing reachable, or a duplicate |
| `Check_TilesUnfilled_FillsThemAgain` | Cut | Nothing the uncheck test misses |
| `WithFixedLastRowMethod.cs` | Delete | Nothing the grid theory misses |

## Appendix: evidence

- **Story build in a headless browser:** unfilled, the grid scrolls, each image fills its tile width,
  and the short last row keeps its neighbours' width.
- **Guard mutations:** deleting the guard fails only `Unfill_ImageStillMissing_...`. Moving it below
  the rebuild fails only the `:414` test.

## Appendix: pre-existing, not this PR

- A failed image fetch looks the same as "no image yet", with no retry short of reloading.
- A story comment describes a CSS background, but the tile draws an `<img>`.
