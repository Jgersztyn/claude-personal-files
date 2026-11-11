# Self-review: a combined option in a region selector

A generic reconstruction (see the [reading notes](README.md#reading-notes)).

- **Change:** a "Combined" option in a sales report's Region selector, next to North and South.
  Picking Combined, or both regions, shows their totals together. The branch is stacked on an open
  PR that added comparison series to the same report. The uncommitted working tree was reviewed:
  5 files changed, about +200/-150, plus 4 new files.
- **Status:** drafts only. No PR exists yet. If one is opened, the intended review event is
  `COMMENT`.
- **How it was produced:**
  - One round of a multi-agent team review: eight fresh-context reviewers.
  - A second-opinion model was requested and failed to start on this platform, so one model
    reviewed.
  - The comments were then styled under the `jg-pr-comment-editor` rules.
  - The findings were fixed in one iteration afterwards (see "After the fix round"), so the comments
    describe the reviewed snapshot, not the committed code.

## What this example shows

- Blocking comments state the failure, then "needs to" or "please … before merge".
- With must-fix findings, the verdict line names each one as a short noun phrase.
- One specific praise line fits in the body when the findings name a real strength.
- The body says what wasn't reviewed (the base PR).
- Two test gaps in correct code arrive graded Blocking and are re-graded to Needs to address, with
  the re-grade recorded in the notes rather than made quietly.
- "After the fix round" records which fixes were proven by a test that fails without them.

## PR comments

- src/Sales/RegionResults.cs:71 · Blocking · 38 words
  `IsForbidden` only counts a sibling that loaded or came back empty, so when North is forbidden and South fails, the panel goes blank and never refreshes. It needs to count any sibling that isn't forbidden, with a test.

- src/Sales/SalesWidget.razor:261 · Needs to address · 34 words
  Nothing tests picking a region after a load throws, and this guard is what stops the error turning into "No data". Please add a component test that also covers the reset in the catch.

- src/Sales/SalesWidget.razor:660 · Needs to address · 21 words
  Nothing tests that the comparison toggles turn off when a second region or Combined is picked. Please add a component test.

## Review body

```
Needs fixing before merge: the blank panel from `IsForbidden`.
Good call keeping Combined out of `Region.All`, so API routing doesn't change.
Didn't review the base PR this branch is stacked on.
```

## Console only (not posted)

- Optional: a failure revealed by picking a region is never recorded in telemetry; record it when the state moves to Error. Standing follow-up (SalesWidget.razor:253)
- Optional: an exception reading the hidden region fails the whole day and the refresh stays silent; catch per region and return Failed. Standing follow-up (SalesWidget.razor:448)
- Optional: reading both regions doubles traffic per refresh and sends a 403 per refresh for single-region accounts; read the account's regions from its entitlements instead. Cross-layer follow-up (SalesReportService.cs:81)
- Optional: the comparison toggles still look selected while disabled; pass an empty selection while change rows can't show (SalesWidget.razor:658)
- Optional: Combined can differ from North plus South while data is still loading, which breaks the letter of one acceptance criterion; raise it with the reporter (RegionRow.cs:73)
- Optional: several method names are noun phrases (`RunsOf`, `AnswerOf`, `ChartTitle`); use verbs such as `FindRuns`, `GetAnswer`, `YAxisTitle` (RegionResults.cs:22)
- Optional: Combined's sources point at the API-routing list `Region.All`; name North and South explicitly (RegionOption.cs:17)
- Optional: the private test helper `Build` shadows the production `Build` at call sites; rename it `BuildForNorth` (BuildMethod.cs)

## Notes

- **Merged.** The `IsForbidden` comment is one finding filed by four reviewers. The comparison-toggle
  comment merges a standards Blocking finding with a test-coverage Optional one.
- **Dropped.** A deselect-Combined test that two reviewers asked for, and merging two toggle handlers,
  which would edit the base PR's helper.
- **Re-graded.** The two missing-test comments arrived graded Blocking, but the code they cover has
  no wrong behaviour on the tree. A test gap in correct code becomes Needs to address (the skill's
  Area 1), so they're worded firmly and left off the must-fix line.
- **Unverified as reviewed.** The `IsForbidden` and region-pick findings were traced by reading, with
  nothing run. The fix round then mutation-checked both.
- **Could matter for sign-off.** The Combined total against North plus South during loading. It's
  raised with the user and left off the must-fix line.
- **No open threads,** so no candidate replies. The intended `COMMENT` event matches the body.

## After the fix round

One fix iteration followed. An independent verifier then checked everything below before the local
commit.

- **All three posted findings fixed, each with a test that a mutation run showed fails without the
  fix:**
  - `IsForbidden` now counts any sibling that isn't forbidden. Test:
    `Render_NorthForbiddenAndSouthFails_ShowsTheError`.
  - Picking a region after a thrown load. Test: `PickingARegion_AfterTheLoadThrew_KeepsTheError`. It
    fails if either the guard or the reset in the catch is deleted.
  - The comparison disable. Test: `PickingASecondRegion_DisablesTheComparisons`.
- **Accepted Optional items, applied:** the verb renames, Combined's explicit sources, and
  `BuildForNorth`.
- **Left as follow-ups:** telemetry on a revealed failure, the hidden region's exception failing the
  day, entitlements instead of 403s, and disabled toggles that still look selected.
