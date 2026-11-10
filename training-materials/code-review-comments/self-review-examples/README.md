# Self-review examples

Worked examples of a full self-review: findings from a multi-agent team review, triaged and then
written up under `skills/jg-pr-comment-editor`. The skill is authoritative; these files only
illustrate it. Each file shows the whole output, not just the comments: the posted comments with
rank and word count, the review body, the console-only list, the private notes, and the appendices
that back the ranking.

## Reading notes

- **Source.** Self-reviews of three of JG's own branches, run before or alongside a PR. In each, a
  multi-agent team review produced the findings, a second round checked them (mutation runs, a
  headless browser over a scratch build), and the comments were styled under `jg-pr-comment-editor`.
- **Everything here is a generic reconstruction.** The product, domain, file paths, identifiers,
  line numbers, ticket keys, branch names and dates are all changed to a neutral online-store
  domain (catalog pages, sales charts, regions). Every comment is written fresh to keep the original
  finding's rank, length and lesson; none reproduces the original wording. Add new examples the same
  way.
- **Word counts** split on whitespace and count the comment text only.
- **Not linked from the skill.** These files are long, and the skill stays complete without them.

## The examples

| File | What it shows |
|---|---|
| [`image-grid-display-toggle.md`](image-grid-display-toggle.md) | A large, test-heavy branch. Many Needs to address test cuts under an explicit "only high-value tests" standard, literal expected values, one Needs a decision against the ticket, hedged May be important lines, and a test-suite table justifying every cut. |
| [`chart-comparison-series.md`](chart-comparison-series.md) | A blocking finding closed by evidence instead of a code change, a Needs research question about speculative code, mutation runs backing every test cut, and a "dropped, not filed" list. |
| [`combined-region-option.md`](combined-region-option.md) | A short review with one Blocking finding and two re-graded test gaps: the must-fix verdict line, one specific praise line, saying what wasn't reviewed, the test-gap re-grade, and what happened after the fix round. |
