# Sam: open decisions

## Lessons from the first real run

Fixed already:
- [x] **Wrong diff.** A branch that merged main into itself had two local merge bases, and Codex picked the wrong one (45 unrelated files). Sam now asks GitHub for the merge base, so both reviews see the same 8 files GitHub shows.
- [x] **Reviewers couldn't write their reports.** The review skill's reviewer hook blocked writes inside the repo under review. The run folder moved to `.work/runs/`, with a per-run `Edit(//c/...)` rule.
- [x] **Codex shared Sam's checkout.** It could have seen Sam's temporary experiments. Codex now gets its own worktree.
- [x] **Cost.** About $20 for a 290-line PR: eight opus reviewers, then Sam's own checks. Now review tiers by size (`reviewSkill.tiers`), for example a four-reviewer skill on sonnet up to 400 changed lines and an eight-reviewer one on opus above that. Sam stays on `model`. Check the run log after a few reviews to see whether the tiers are right.
- [x] **Notify on post.** Dropped: GitHub already notifies you, since a review request subscribes you to the PR.

Still open:
- [ ] **JG's own team-review skill.** Write a team-review skill in this repo and point the tiers' `name` at it, so Sam doesn't depend on a third-party plugin.
- [ ] **Tune from outcomes.** Once `-Outcomes` has enough data, use it to tune the categories and the budget, for example if most Optional comments get no response.
- [ ] **Known gaps** (low severity):
  - A timeout or 5xx after GitHub actually created a review can still double-post on a rerun. Check the PR's reviews by Sam's login and `commit_id` before re-posting.
  - A failed Sam session logs "no model cost" though money was spent; `Invoke-Sam` drops `total_cost_usd` when it throws.
  - Threads past 100 per PR, or comments past 50 per thread, aren't seen.
- [ ] **Codex's thin output.** On the wrong diff, Codex's review was one line, and when blocked it still exits 0 with "Unable to review". Treat that text as a failed Codex run, and consider `--output-schema` for structured findings.
- [ ] **Tie Codex to the script's lifetime.** A Windows job object, so killing PowerShell also kills Codex. Today a hard kill can leave Codex holding its worktree.

## To be determined

- [ ] **Decide what Sam posts as the app.** Allow `REQUEST_CHANGES` (`allowRequestChanges: true`)? Mention @author in the summary?
- [ ] **Load the comment skill in-session instead.** Tried 2026-11-04 and parked on request: Sam loads `Skill(jg-pr-comment-editor)` and `comment-standards.md` keeps only JG's overrides. The file is in `../../training-materials/sam/parked-pr-comments-skill-2026-11-04/`; copy it over the live `comment-standards.md` to switch. Needs the skill installed for your user.
- [ ] **Disclosure while posting as you.** Only matters with `postAs: "me"`. As the app, the `[bot]` account makes it obvious. Options: a `footer` in config, a line in the summary, or nothing.
- [ ] **Repo-specific checks.** Some repos need their own checklist: the full solution build rather than one project, a design-system decision record, framework lifecycle and disposal rules, the CONTRIBUTING shape. Decide whether to add per-repo notes to config (next to `clonePath`) that the prompt quotes.
- [ ] **Running the app.** Some PRs can only be judged by running the app, which may need backing services. Probably skip for Sam, or opt in per repo.
- [ ] **Which requests count.** The search uses `user-review-requested:@me` (you, not your teams). Switch to `review-requested:@me` to include team requests.
- [ ] **Model and cost.** `model` in config (opus by default). Each draft records its cost. `maxBudgetUsd` caps each Claude pass, not the run (0 = no cap), so a run with a Codex second pass can spend twice that; pick a number.
- [ ] **Run timeout.** Nothing stops a hung `claude` session in `-Loop` mode, which would hold the lock. The scheduled task stops a run after 2 hours; `-Loop` has no limit.
- [ ] **Tool allowlist.** `config.json` allows reading, git inspection, `gh pr view/diff`, the build and test commands for your stack (`dotnet build/test/restore` in the example), edits and new files inside the worktree only (`Edit(./**)`, which covers the Write tool too), and subagents. The script adds one more `Edit(//c/...)` rule per run for that run's folder in `.work/runs/`. `find`/`cp`/`mkdir`/`cat`/`grep` were left out because Bash rules aren't path-confined the way `Edit(./**)` is (`cat` and `grep` would get around the key-folder deny rule). `git diff --output=<file>` can still write outside the worktree, which is a minor gap. Widen per repo as needed (npm, etc.).
- [ ] **Your own plugins in Sam's sessions.** `--setting-sources user` keeps your user settings, so your plugins and their hooks run inside every Sam review. That's what makes a plugin review skill available, but it's noisy: SessionStart hooks can ask Sam's session to do unrelated setup, which Sam rightly skips. Any permission allow rules in your user settings apply in Sam's sessions too (`--permission-mode dontAsk` pins the mode, not the rules). Decide whether to keep them, or give Sam a dedicated settings file (`--settings`) that enables only the review skill's plugin.
- [ ] **Files outside the worktree.** Sam's read tools aren't confined to the PR (Read, Grep, Glob, `git blame --contents`; deny rules miss 8.3 short paths). The app key is safe (DPAPI), but other secrets you keep in plain files (SSH keys, `.env` files, tokens) could be quoted into a review by a prompt-injected session. The posting check only catches PEM-style keys. Options: run Sam under a separate Windows account, or in a sandbox.
- [ ] **Trust boundary.** Sam builds and tests PR code with your credentials in the environment (see README). Fine for your own team's PRs. Decide whether to skip PRs from forks or outside contributors, or run builds in a sandbox, before going unattended.
