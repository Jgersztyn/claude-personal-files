# Sam

Sam is JG's PR review persona. When you're requested as a reviewer on a pull request, Sam checks out the PR, reviews it with Claude Code, and writes a draft review. You read the draft and post it, or Sam posts it on its own. After its review is posted, Sam follows up on new commits and answers replies in its own threads.

Sam runs as one PowerShell script, not a service. It works on any GitHub account or organization once it's configured: a `config.json` naming the repos to review, optionally the review skills to run, and optionally a GitHub App for Sam to post as.

**Status: working, attended.** Sam reviews, drafts, and posts as its own GitHub App (`<app-slug>[bot]`) when told to, and can poll on a schedule. Before leaving Sam unattended, see the remaining items in [TODO.md](TODO.md).

## How it works

```
gh search: open PRs where you're directly requested
  + PRs Sam has posted on that are still open (for replies in Sam's threads only)
  └─ for each PR, decide what it needs (.work/state.json):
       full      Sam hasn't reviewed it yet (or -Force on the same commit)
       followup  new commits since Sam's posted review, while you're still requested
       replies   someone answered in one of Sam's threads
       nothing   otherwise
       ├─ fetch the PR head and base into a clone, add a throwaway worktree
       ├─ ask GitHub for the PR's merge base, so the diff matches the one GitHub shows
       ├─ a follow-up covers only the PR's files that changed since Sam's reviewed commit;
       │    a force push makes it a full review, a merge from the base branch with nothing new makes it replies or nothing
       ├─ pick the review tier by changed lines (reviewSkill.tiers in config): which review skill runs,
       │    how many reviewers it spawns and on which model. Sam itself always runs on `model`.
       ├─ with -Post as the app: an eyes reaction on the PR while Sam works, removed when it's done
       ├─ start `codex exec review` in the background against the merge base (or Sam's last reviewed
       │    commit on a follow-up), in a second worktree (read-only sandbox). Not for replies.
       ├─ claude -p in the worktree: first pass, with sam-pr-review.md or sam-pr-followup.md
       │    system prompt  = sam-system.md + comment-standards.md
       │    method         = the tier's review skill, or Sam's built-in review, then Sam verifies and triages
       │    tools          = config.json allowlist (read, build, test, write only inside the worktree)
       │                     + write access to this run's folder, .work/runs/<pr>-<sha>-<time>/
       │    output         = JSON matching review-schema.json
       ├─ wait for Codex (up to codexReview.waitMinutes after the first pass, else go on without it)
       ├─ claude -p --resume: second pass with sam-codex-followup.md and Codex's findings
       ├─ save drafts/<owner>-<repo>-<pr>-<sha>.json and a readable .md next to it
       ├─ print the verdict, counts and any extra minor notes (those are never posted)
       ├─ post it only with -Post (as Sam's app; never APPROVE)
       │    one review: verdict body + [Blocking] / [Needs a decision] / [Optional] inline comments,
       │      each line checked against the PR's diff first; a comment off the diff goes in the body as `path:line`
       │    one separate PR comment: up to 10 minor and nitpick notes
       │    replies in Sam's own threads, never anyone else's
       ├─ log the run (time, cost, review skill, Codex, counts) to .work/logs/runs.jsonl and the console
       └─ remove the worktree
```

### What Sam can and can't do

- Sam can't post or push. Sam's tool allowlist has no `gh api`, `gh pr review`/`comment`, `git push` or `git stash`. Sam's output is plain data, and the script decides whether to post it.
- The PR's own Claude config never loads. `claude -p` skips the workspace trust prompt, so Sam runs with `--setting-sources user --strict-mcp-config`. The PR's `.claude/settings.json` hooks and permissions, `.mcp.json` servers, `.claude/skills`, `.claude/commands` and `CLAUDE.md` are all ignored as configuration. This was checked with a planted skill, command and CLAUDE.md. Sam still reads `CLAUDE.md` and `CONTRIBUTING.md` as files to review against, and treats them as untrusted like the rest of the PR.
- **Sam can read files outside the PR.** Read, Grep, Glob and `git blame --contents` aren't confined to the worktree, and path deny rules have gaps (8.3 short names, for one). A malicious PR could try to talk Sam into quoting a file into a review. So the app's private key is stored encrypted with Windows DPAPI, which only your Windows account on this PC can undo, and it's decrypted in memory only when the script needs it: to post, and to look up Sam's own login when `githubApp.slug` is empty. That only helps once the plain `.pem` is deleted. Sam refuses to start a review while a `.pem` sits anywhere in this folder, but it can't see copies elsewhere (Downloads, for example), so delete those too. Before anything is posted, the text is also checked for a PEM header or any piece of the app key, and refused if it has one. Re-encoded text can get past that check, so it's a backstop only.
- **A prompt-injected Sam can run code too.** It can edit files in the worktree and run the build and test commands in its allowlist, so injected text alone could get it to build code that uses anything your Windows account can, the DPAPI key included. Like the point below, the real fix is running Sam under a separate account or in a sandbox (TODO.md).
- **Codex reads the PR too.** It runs in its own worktree with `-c sandbox_mode=read-only`, `--ephemeral` and `--ignore-rules`, under your Codex login and `~/.codex/config.toml` (so your Codex MCP servers and plugins load), and it loads the PR's own `AGENTS.md` like any Codex session would. `--ignore-user-config` would be tighter, but it left Codex unable to run `git diff`. Its findings reach Sam as untrusted data that Sam checks before using, and nothing it writes is posted directly. Turn it off with `codexReview.enabled: false`.
- **PR code does run.** The build and test commands run the PR's build scripts and tests on your machine, with your credentials in the environment. Any CI or local build does the same. So only point Sam at repos whose authors you'd trust to build their code locally: your own team, not outside forks.

## Files

| File | What it is |
|---|---|
| `sam-system.md` | Persona: who Sam is, what a finished review looks like, rules for untrusted content, output shape. The same every run. |
| `comment-standards.md` | How Sam writes comments and thread replies: the five categories, the severity scale, comment shape and length, the comment budget, the reply rules. Adapted from the `jg-pr-comment-editor` skill in this repo. Appended to the system prompt. |
| `sam-pr-review.md` | Per-PR task for a full review. `{{repo}}`, `{{number}}`, `{{title}}`, `{{author}}`, `{{head_ref}}`, `{{base_ref}}`, `{{head_sha}}`, `{{url}}`, `{{merge_base}}`, `{{worktree}}`, `{{run_dir}}`, `{{changed_lines}}`, `{{review_step}}` and `{{open_threads}}` are filled in. |
| `sam-pr-followup.md` | Per-PR task for a follow-up or replies run. The same values, plus `{{reviewed_sha}}`, `{{scope}}` (the new-changes diff, or "replies only") and `{{pending}}` (Sam's threads waiting on an answer). |
| `sam-codex-followup.md` | The second-pass prompt. `{{codex_review}}` and `{{diff_base}}` are filled in. |
| `review-schema.json` | The structured output Sam must return: verdict, summary, categorized inline comments (20 at most), up to 10 minor notes, extra minor notes (console only), thread replies, what Sam ran, private notes for JG. |
| `config.example.json` | Copy to `config.json`. Search query, repo allowlist, model, review tiers, tool allowlist, posting and follow-up options. |
| `sam.ps1` | The runner. |
| `sam-schedule.ps1` | Turns unattended polling on and off, as a Windows scheduled task. |
| `sam-avatar.svg`, `sam-avatar.png` | Avatar for Sam's GitHub App (512×512, transparent; the PNG is rendered from the SVG). |
| `TODO.md` | Blockers to full automation and open decisions. |
| `drafts/` | Sam's reviews. Created on first run. |
| `.work/` | Clones, worktrees, state, lock, and the private logs in `.work/logs/`. Created on first run. Safe to delete, but Sam then forgets what it reviewed and posted, so it re-reviews everything and stops following up. |

`config.json`, `drafts/`, `.work/` and any `.pem` are git-ignored. Keep your config out of git: it names your repos and your app.

## Setup

1. Have `gh` (logged in as you), `git` and `claude` on PATH.
2. `Copy-Item config.example.json config.json`.
3. In `config.json`, list the repos Sam may review under `repos`, as `owner/name`. Leave `clonePath` blank and Sam keeps its own clone in `.work/clones/`. That's the safer choice. You can point it at an existing clone, but worktrees share that clone's stash and refs. Only PRs in listed repos are reviewed by a poll; `-Pr` works on any repo.
4. Widen `allowedTools` for the stacks you review. The example allows `dotnet build`, `dotnet test` and `dotnet restore`; add the equivalents for your repos (for example `Bash(npm test:*)`), and keep each rule as narrow as the job allows.
5. Optional: pick review skills (see [Review skill](#review-skill)). Without one, Sam runs its built-in review.
6. Optional: have `codex` on PATH and logged in, for the background Codex review. Without it, Sam reviews alone and says so.
7. To post as Sam, set up a GitHub App (see [GitHub App](#github-app)). To post as yourself instead, set `postAs` to `"me"` and skip that section.

## Review skill

The review itself is step 3 of a full review, and part of step 2 of a follow-up. `reviewSkill` in `config.json` decides how it runs:

| Key | What it does |
|---|---|
| `tiers` | One entry per PR size, by changed lines (additions plus deletions). The first tier whose `maxChangedLines` covers the change wins, and `0` means no limit, so the last tier is usually `0`. Each tier has a `name`, the skill Sam invokes with the Skill tool (empty means Sam's built-in review), `reviewers`, how many reviewers it spawns, and `reviewerModel`, their model (empty means `model`). A follow-up picks its tier by the size of the new changes only. |
| `instructions` | Extra lines for the skill, added to the step as bullets. `{{reviewer_count}}`, `{{reviewer_model}}`, `{{model}}`, `{{changed_lines}}`, `{{run_dir}}`, `{{merge_base}}` and `{{worktree}}` are filled in. Use them for whatever the skill needs to run headless: foreground spawns, a model per spawn, switches it understands. |
| `scaffold` | Folders (ending in `/`) and empty files the skill expects in its run directory before it starts. Paths are relative to the run directory. |

The built-in review is one pass each for correctness and error handling, security, tests, design and the repo's standards, and documentation accuracy, with up to `reviewers` subagents on `reviewerModel` if Sam wants them.

Sam's session loads only your user settings, so a skill has to be installed for your user (a plugin or `~/.claude/skills/`). If Sam can't find it, Sam says so in its private notes and falls back to the built-in review, so a missing skill never stops a review.

Whatever the skill, Sam verifies and triages every finding itself before it writes anything, and every comment follows `comment-standards.md`.

Example, for a plugin with a four-reviewer team review for small PRs and an eight-reviewer one for large PRs, both writing their reports to a `reports/` folder in the run directory. The plugin and skill names are placeholders:

```json
"reviewSkill": {
  "tiers": [
    { "maxChangedLines": 400, "name": "my-plugin:team-review-small", "reviewers": 4, "reviewerModel": "sonnet" },
    { "maxChangedLines": 0, "name": "my-plugin:team-review-large", "reviewers": 8, "reviewerModel": "opus" }
  ],
  "instructions": [
    "Spawn the {{reviewer_count}} reviewers in the foreground, all in one message, so they run in parallel and report back before you continue. Background agents can't report back in this session.",
    "Tell every reviewer to write its report to `{{run_dir}}/reports/`.",
    "Pass `model: \"{{reviewer_model}}\"` on every spawn."
  ],
  "scaffold": ["reports/"]
}
```

An older config with a top-level `tiers` list (`teamReview` in place of `name`) still works when `reviewSkill.tiers` is empty. Check what a review prompt looks like with `-PromptOnly` after changing any of this.

## GitHub App

Sam posts as its own GitHub App, so its reviews come from a `[bot]` account instead of from you.

1. Create a GitHub App under your account or organization (Settings, Developer settings, GitHub Apps). No webhook is needed, so untick **Active** under Webhook.
2. Repository permissions: **Pull requests: Read and write**. Nothing else. Sam's posting token only ever asks for that (reviews, the minor-notes comment, thread replies, reactions), so more access only widens what a leaked key could do.
3. Upload `sam-avatar.png` as the app's logo if you like.
4. Install the app on the repos Sam reviews. "Only select repositories" is safer than all.
5. Put the app's **App ID** in `githubApp.appId`. Put its slug (the name in its URL) in `githubApp.slug` too. Without it, Sam signs in as the app on every run to find its own threads, and until the key is imported it treats no thread as its own.
6. Generate a private key on the app's page, import it, then **delete the `.pem`**:
   ```powershell
   .\sam.ps1 -ImportKey C:\path\to\sam.pem
   ```
   This encrypts the key for your Windows account into `githubApp.keyFile` (default `%USERPROFILE%\.config\sam\github-app-key.bin`), locks that file to you, and signs in as the app to prove it works. On a new PC or a new Windows account, import again. If the `.pem` is gone, generate a new key on the app's settings page.

If someone else owns the app, ask them for the App ID and a private key, and to install it on your repos.

## Use

```powershell
# Preview what Sam would be told for a PR. Clones and runs nothing.
.\sam.ps1 -Pr https://github.com/<owner>/<repo>/pull/123 -PromptOnly

# Review one PR now and save a draft.
.\sam.ps1 -Pr https://github.com/<owner>/<repo>/pull/123

# Poll once: draft a review for every new PR where you're requested.
.\sam.ps1 -Verbose

# Read drafts\<name>.md, edit the .json if you want, then post it as Sam.
.\sam.ps1 -PostDraft .\drafts\<owner>-<repo>-123-0644b75.json

# Resume Sam's session to ask it about a review (session id is in the draft).
claude --resume <session_id>

# How Sam's posted comments fared, by category: resolved, code changed, replied to, no response.
.\sam.ps1 -Outcomes

# Unattended in this console. See TODO.md before relying on this.
.\sam.ps1 -Loop -IntervalMinutes 10 -Post
```

### Polling on a schedule

`sam-schedule.ps1` turns unattended polling on and off. It's a Windows scheduled task under `\Sam\`, named after this folder so two copies of Sam on one PC don't replace each other's task. It runs `sam.ps1 -Post` every 10 minutes, hidden, as you. It only runs while you're logged on, and it stops by itself at `-Until`.

```powershell
.\sam-schedule.ps1 -Start -Until '2026-11-06 20:00'   # local time
.\sam-schedule.ps1 -Status                            # on or off, last and next run, end of today's log
.\sam-schedule.ps1 -Stop                              # no more polls; a review already running finishes
```

Each day's console output goes to `.work/logs/poll-<date>.log`. A run that takes more than 2 hours is stopped.

### When Sam runs

Sam reviews when you're requested as a reviewer, and answers when someone replies to it.

- **First review.** When you're directly requested on a PR in `config.repos`.
- **Follow-up.** When the author pushes after Sam's review has posted, and you're still requested. Sam reviews only the PR's files that changed since its reviewed commit, with the tier for that size, and replies in its own threads: fixed, still open, or a new question. Anything Sam didn't raise last time and the new commits didn't touch stays as it is. A follow-up with nothing new to say posts only its replies.
  - If the author merged the base branch in since Sam's review, Sam diffs against a local commit made from its reviewed commit with that merge applied, so other people's changes stay out of the follow-up. Codex sits that follow-up out, since it would review from the merge base, base-branch changes included. If that merge conflicts, it's a full review.
  - After a force push that drops Sam's reviewed commit, it's a full review. Replies waiting in Sam's threads get answered on the next poll.
- **Replies.** When a person answers in one of Sam's threads, on any open, non-draft PR in `config.repos` that Sam has posted on, even once you're no longer requested. Each reply is answered once. Replies from bots are ignored, so Sam can't get into a back-and-forth with one.
- A GitHub App can't be requested as a reviewer, so there's no way to request Sam directly. Requesting you is the trigger.
- With `postAs: "me"`, posting submits your review, which drops your review request, so follow-ups wait until you're re-requested. As the app, your request stays open.
- With `postAs: "me"`, Sam and you share a login, so a thread counts as Sam's only if its first comment is in Sam's comment log (`.work/logs/comments.jsonl`). Sam never answers in threads you wrote yourself.
- Follow-ups start from what's **posted**, including a partial post. A draft you never post doesn't count. `-PostDraft` records it like `-Post` does.
- `-PromptOnly` always shows the full-review prompt, even when the real run would be a follow-up.
- `followUps: false` turns follow-ups and replies off: each new commit gets a full review while you're requested.

Each commit is reviewed once. Use `-Force` with `-Pr` to redo a full review of the same commit (`-Loop -Force` is refused, since it would redo everything every poll). A failed run is recorded and not retried without `-Force`, and a reply counts as handled once Sam has been given it, even if that run fails, so a broken PR can't burn money every poll. Set `maxBudgetUsd` in config to cap what one run can spend (0 means no cap).

### Run log

Every run adds a line to `.work/logs/runs.jsonl` and prints it: minutes, cost per pass, mode, review skill, how Codex went, and the counts. Every posted inline comment goes to `.work/logs/comments.jsonl` for `-Outcomes`. Both stay on this machine and are never posted.

## Posting rules

- With `postAs: "app"`, reviews post as Sam's GitHub App. For each post, Sam signs in as the app with its private key and asks GitHub for a token that can only write pull requests, only on that PR's repo, and lasts at most an hour. It's revoked right after posting. Finding PRs and reading them still uses your `gh` login, because "requested as reviewer" is about you.
- With `postAs: "me"`, reviews post as whoever `gh auth status` shows.
- Never `APPROVE`, never merge.
- One review per run: the summary as its body, and each `blocking`, `needs_decision` and `optional` finding as an inline comment, which the script tags `[Blocking]`, `[Needs a decision]` or `[Optional]`. Then `minor_notes` post as one separate PR comment, a short bulleted list of up to 10, with at least 2 nitpicks when there are any. Any more show in the console and the draft only. Then the thread replies, if any.
- Each part is saved to the draft as soon as it posts. If something fails partway, `-PostDraft` on the same draft posts only what's left.
- Before posting, each inline comment's line is checked against the PR's diff. A comment on a line outside it goes in the review body as `` `path:line` [Tag] … ``, so it still points at its line.
- Replies go only to threads Sam started. A reply the draft aims at anyone else's thread is skipped with a warning.
- An answer in a thread can be a reply, a reaction (`+1`, `hooray` or `heart`) on the author's latest reply, or both. A plain fix with nothing worth saying gets just the reaction. Replies are warm and specific: one sentence for a simple change, a few lines at most for a complex one (see Replies in `comment-standards.md`).
- `needs_changes` posts as `REQUEST_CHANGES` only if `allowRequestChanges` is true. Otherwise everything posts as `COMMENT`.
- If the PR moved on since the draft, posting stops. Re-run Sam, or pass `-Force` to post anyway.
- If GitHub still rejects the review with a 422, the comments are folded into the review body and posted that way. Any other failure isn't retried, so a review can't post twice.
- If posting fails after a review ran, the draft is kept and state shows `post_failed`. Post it later with `-PostDraft`. If the failure wasn't a 422 (a timeout or 5xx), check the PR first: GitHub may have created the review anyway.
- `footer` in config is appended to every posted review body. It's empty by default, see the disclosure item in TODO.md.

## Troubleshooting

- **Paths too long on clone or checkout.** Sam clones with `core.longpaths=true`. For an existing clone, run `git -C <clone> config core.longpaths true`.
- **"Sam is already running" or "Sam is reviewing right now".** Another run holds `.work/sam.lock`. `-PostDraft` takes the lock too, so it can't overwrite `state.json` while a review is writing it. `-Loop` holds it only while it polls, so `-PostDraft` works between polls. If no run is active, delete the file.
- **"... is a plain-text key" or "Sam's app key isn't at ...".** Run `.\sam.ps1 -ImportKey <the .pem>`. "Couldn't decrypt" means the file was encrypted by another Windows account or PC; import again.
- **"Plain-text key file(s) in Sam's folder".** Import the key if you haven't, then delete the `.pem` files it names.
- **"GitHub App call ... failed".** A 401 on `GET app` means the App ID or key is wrong. A 404 on `repos/.../installation` means the app isn't installed on that repo. A 422 on `access_tokens` means the repo isn't one the installation covers.
- **"Review skill name ... isn't a skill name" or "reviewSkill.scaffold entry ...".** Fix that key in `config.json` (see [Review skill](#review-skill)).
- **The review skill didn't run.** Read the draft's notes for JG: Sam says there when it couldn't find the skill and used the built-in review.
- **"Codex's review failed" or "Codex was still running".** Sam's review still completes, without the second pass. Codex's output and log are in `.work/codex/`. Raise `codexReview.waitMinutes`, or set `enabled` to false.
- **Reading the reviewers' reports.** Each run's folder stays in `.work/runs/`, with whatever the review skill wrote there.
- **"Couldn't add the eyes reaction".** The reaction never stops a review. It needs the app's Pull requests write permission on that repo.
- **Sam keeps re-reviewing everything.** `.work/state.json` was deleted or reset, so Sam doesn't know what it posted. Follow-ups pick up again after the next posted review.
- **Sam's session failed.** Check the error in `.work/state.json`, then `claude --resume` the session if one started, or re-run with `-Force`.
