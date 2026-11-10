# Sam: blockers and open decisions

## Blockers to full automation

Sam stays in "draft, then JG posts" mode until these are done.

- [ ] **Set up a GitHub App for Sam** on each GitHub account or organization Sam posts to. The README's [GitHub App](README.md#github-app) section has the steps.
  - [ ] **Keep its permissions narrow.** Pull requests read and write, nothing else, installed only on the repos Sam reviews. Sam's posting token is narrowed to pull requests write on one repo, so Sam itself can't use extra access, but anyone holding the key could.
  - [ ] **Encrypt the key** with `-ImportKey` (DPAPI, your account only).
  - [ ] **Delete the plain key**, and any other plain copy, e.g. in Downloads or email.
- [x] **Post as the app.** Done: `Get-PostingToken` in `sam.ps1` decrypts the key in memory, signs a JWT, gets a token limited to pull requests write on the PR's repo, posts with it through `GH_TOKEN` for that one call, and revokes it. Detection keeps using your own `gh` login.
- [x] **Configurable review step.** Done 2026-11-05: `reviewSkill` in config picks the review skill for each PR size (`tiers`), with extra instructions and a run-directory scaffold. An empty name, or a skill that isn't installed, means Sam's built-in review.
- [ ] **Decide what Sam posts as the app.** Allow `REQUEST_CHANGES` (`allowRequestChanges: true`)? Mention @author in the summary?
- [x] **Run it unattended.** Done 2026-11-05: `sam-schedule.ps1 -Start -Until <time>` / `-Stop` / `-Status`, a scheduled task with a daily transcript in `.work/logs/`. The machine has to be on, with you logged on.

## Lessons from the first real run

Fixed already:
- [x] **Wrong diff.** A branch that merged main into itself had two local merge bases, and Codex picked the wrong one (45 unrelated files). Sam now asks GitHub for the merge base, so both reviews see the same 8 files GitHub shows.
- [x] **Reviewers couldn't write their reports.** The review skill's reviewer hook blocked writes inside the repo under review. The run folder moved to `.work/runs/`, with a per-run `Edit(//c/...)` rule.
- [x] **Codex shared Sam's checkout.** It could have seen Sam's temporary experiments. Codex now gets its own worktree.

Improvements and features, decided 2026-11-05:
- [x] **Cost.** About $20 for a 290-line PR: eight opus reviewers, then Sam's own checks. Now review tiers by size (`reviewSkill.tiers`), for example a four-reviewer skill on sonnet up to 400 changed lines and an eight-reviewer one on opus above that. Sam stays on `model`. Check the run log after a few reviews to see whether the tiers are right.
- [ ] **JG's own team-review skill.** Write a team-review skill in this repo and point the tiers' `name` at it, so Sam doesn't depend on a third-party plugin.
- [x] **Trigger.** Sam reviews when you're requested, and answers when someone replies to it. A GitHub App can't be requested as a reviewer (no user account behind it), so there's no direct trigger for Sam.
- [x] **A "started" signal.** An eyes reaction on the PR while Sam works, as the app, with `-Post` only. Removed when the run ends.
- [x] **Check lines before posting.** Each inline comment's line is checked against the PR's diff hunks; one off the diff goes in the body as `path:line`. The 422 fallback stays as a backstop.
- [x] **Follow-ups on new pushes.** Only the PR's files changed since Sam's posted review, with replies in Sam's own threads.
- [x] **Replies to Sam's comments.** Sam answers replies in its own threads, by the reply rules in `comment-standards.md`.
- [x] **Learn from outcomes.** Each posted inline comment goes to `.work/logs/comments.jsonl`, and `-Outcomes` shows by category how many were resolved, had their code changed, got a reply, or got no response.
  - [ ] Once there's enough data, use it to tune the categories and the budget, for example if most Optional comments get no response.
- [x] **Run log.** `.work/logs/runs.jsonl` and the console: minutes, cost per pass, mode, review skill, Codex status, counts. Private.
- [x] **Notify on post.** Dropped: GitHub already notifies you, since a review request subscribes you to the PR.
- [ ] **Known gaps** (low severity):
  - A timeout or 5xx after GitHub actually created a review can still double-post on a rerun. Check the PR's reviews by Sam's login and `commit_id` before re-posting.
  - A failed Sam session logs "no model cost" though money was spent; `Invoke-Sam` drops `total_cost_usd` when it throws.
  - Threads past 100 per PR, or comments past 50 per thread, aren't seen.
- [ ] **Session noise.** Plugins in your user settings can have SessionStart hooks that ask Sam's session to do unrelated setup, which Sam rightly skips. A dedicated `--settings` file for Sam would drop hooks Sam doesn't need (see "Your own plugins" below).
- [ ] **Codex's thin output.** On the wrong diff, Codex's review was one line, and when blocked it still exits 0 with "Unable to review". Treat that text as a failed Codex run, and consider `--output-schema` for structured findings.
- [ ] **Tie Codex to the script's lifetime.** A Windows job object, so killing PowerShell also kills Codex. Today a hard kill can leave Codex holding its worktree.

## To be determined

- [x] **The real prompt.** Done 2026-10-28: `sam-pr-review.md` runs the review step, checks the open threads, builds and tests, and `sam-codex-followup.md` folds in a background Codex review. Adapted from JG's own review prompt, which stays off any shared repo.
- [x] **Comment standards.** Done 2026-10-28: `comment-standards.md` adapts the `jg-pr-comment-editor` skill, with JG's five categories and tags, the severity scale (7+ is Blocking), few questions, and a 20-comment cap.
- [ ] **Load the comment skill in-session instead.** Tried 2026-11-04 and parked on request: Sam loads `Skill(jg-pr-comment-editor)` and `comment-standards.md` keeps only JG's overrides. The files are in `../../training-materials/sam/parked-pr-comments-skill-2026-11-04/`; copy them back over the live ones to switch. Needs the skill installed for your user.
- [x] **Minor and nitpick format.** Decided 2026-11-05: one short separate list comment of up to 10, at least 2 nitpicks, extras to the console.
- [ ] **Disclosure while posting as you.** Only matters with `postAs: "me"`. As the app, the `[bot]` account makes it obvious. Options: a `footer` in config, a line in the summary, or nothing.
- [ ] **Repo-specific checks.** Some repos need their own checklist: the full solution build rather than one project, a design-system decision record, framework lifecycle and disposal rules, the CONTRIBUTING shape. Decide whether to add per-repo notes to config (next to `clonePath`) that the prompt quotes.
- [ ] **Running the app.** Some PRs can only be judged by running the app, which may need backing services. Probably skip for Sam, or opt in per repo.
- [x] **Follow-ups.** Done 2026-11-05, see above.
- [x] **"Started" acknowledgement.** Done 2026-11-05: the eyes reaction instead of a comment.
- [ ] **Which requests count.** The search uses `user-review-requested:@me` (you, not your teams). Switch to `review-requested:@me` to include team requests.
- [ ] **Repos allowlist.** Add each repo you want Sam to review to `repos` in config.
- [ ] **Model and cost.** `model` in config (opus by default). Each draft records its cost. `maxBudgetUsd` caps one review (0 = no cap); pick a number.
- [ ] **Run timeout.** Nothing stops a hung `claude` session in `-Loop` mode, which would hold the lock. The scheduled task stops a run after 2 hours; `-Loop` has no limit.
- [ ] **Tool allowlist.** `config.json` allows reading, git inspection, `gh pr view/diff`, the build and test commands for your stack (`dotnet build/test/restore` in the example), edits and new files inside the worktree only (`Edit(./**)`, which covers the Write tool too), and subagents. The script adds one more `Edit(//c/...)` rule per run for that run's folder in `.work/runs/`. `find`/`cp`/`mkdir`/`cat`/`grep` were left out because Bash rules aren't path-confined the way `Edit(./**)` is (`cat` and `grep` would get around the key-folder deny rule). `git diff --output=<file>` can still write outside the worktree, which is a minor gap. Widen per repo as needed (npm, etc.).
- [ ] **Your own plugins in Sam's sessions.** `--setting-sources user` keeps your user settings, so your plugins and their hooks run inside every Sam review. That's what makes a plugin review skill available, but it's noisy, and any permission allow rules in your user settings apply in Sam's sessions too (`--permission-mode dontAsk` pins the mode, not the rules). Decide whether to keep them, or give Sam a dedicated settings file (`--settings`) that enables only the review skill's plugin.
- [ ] **Files outside the worktree.** Sam's read tools aren't confined to the PR (Read, Grep, Glob, `git blame --contents`; deny rules miss 8.3 short paths). The app key is safe (DPAPI), but other secrets you keep in plain files (SSH keys, `.env` files, tokens) could be quoted into a review by a prompt-injected session. The posting check only catches PEM-style keys. Options: run Sam under a separate Windows account, or in a sandbox.
- [ ] **Trust boundary.** Sam builds and tests PR code with your credentials in the environment (see README). Fine for your own team's PRs. Decide whether to skip PRs from forks or outside contributors, or run builds in a sandbox, before going unattended.
