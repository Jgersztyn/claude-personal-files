<#
.SYNOPSIS
  Sam drafts a review for each pull request where you are requested as a reviewer.

.DESCRIPTION
  One poll by default: finds open PRs where you are directly requested as a reviewer, runs Sam on
  each new head commit in a throwaway worktree, and saves the review as a draft under drafts\.
  Nothing is posted unless you pass -Post or post a draft with -PostDraft. Posts go out as Sam's
  GitHub App (<app-slug>[bot]), or as you with postAs 'me' in config.json.

  Works on Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
  .\sam.ps1
  Poll once and save drafts. Nothing is posted.

.EXAMPLE
  .\sam.ps1 -Pr https://github.com/<owner>/<repo>/pull/123
  Review one PR now, whether or not you are requested on it.

.EXAMPLE
  .\sam.ps1 -Pr https://github.com/<owner>/<repo>/pull/123 -PromptOnly
  Print the prompt Sam would get. Clones nothing and runs nothing.

.EXAMPLE
  .\sam.ps1 -PostDraft .\drafts\owner-repo-123-0644b75.json
  Post a draft you have read (and maybe edited) to the PR.

.EXAMPLE
  .\sam.ps1 -ImportKey C:\path\to\sam.pem
  One-time setup: encrypt the app's private key for your Windows account. Then delete the .pem.

.EXAMPLE
  .\sam.ps1 -Loop -IntervalMinutes 10 -Post
  Unattended mode. Posts as Sam's GitHub App (postAs 'app' in config.json).

.EXAMPLE
  .\sam.ps1 -Outcomes
  How Sam's posted comments fared: resolved, code changed, replied to, or no response. Private.
#>
[CmdletBinding(DefaultParameterSetName = 'Poll')]
param(
    [Parameter(ParameterSetName = 'Pr', Mandatory)]
    [string] $Pr,

    [Parameter(ParameterSetName = 'Pr')]
    [switch] $PromptOnly,

    [Parameter(ParameterSetName = 'PostDraft', Mandatory)]
    [string] $PostDraft,

    [Parameter(ParameterSetName = 'ImportKey', Mandatory)]
    [string] $ImportKey,

    [Parameter(ParameterSetName = 'Outcomes', Mandatory)]
    [switch] $Outcomes,

    [Parameter(ParameterSetName = 'Poll')]
    [switch] $Loop,

    [Parameter(ParameterSetName = 'Poll')]
    [ValidateRange(1, 1440)]
    [int] $IntervalMinutes = 10,

    [Parameter(ParameterSetName = 'Poll')]
    [Parameter(ParameterSetName = 'Pr')]
    [switch] $Post,

    [Parameter(ParameterSetName = 'Poll')]
    [Parameter(ParameterSetName = 'Pr')]
    [Parameter(ParameterSetName = 'PostDraft')]
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$OutputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom

$Root = $PSScriptRoot
$WorkDir = Join-Path $Root '.work'
$DraftDir = Join-Path $Root 'drafts'
$StatePath = Join-Path $WorkDir 'state.json'
$LockPath = Join-Path $WorkDir 'sam.lock'
# Private logs: run cost and time, and every posted comment for -Outcomes. .work is never committed.
$LogDir = Join-Path $WorkDir 'logs'
# Sam's GitHub login, looked up once by Get-SamLogin, and the ids of Sam's posted comments.
$SamLogin = $null
$SamPostsAsMe = $false
$SamCommentIds = $null
$SamCommentIdsStamp = 0

# ---------------------------------------------------------------- helpers

function Read-Utf8([string] $Path) {
    return [IO.File]::ReadAllText($Path, $Utf8NoBom)
}

function Write-Utf8([string] $Path, [string] $Text) {
    [IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

# Windows PowerShell 5.1 strips embedded double quotes from native arguments; PowerShell 7.3+ does not.
function Format-NativeArg([string] $Value) {
    $modern = $PSVersionTable.PSVersion.Major -ge 7 -and
        (Get-Variable PSNativeCommandArgumentPassing -ErrorAction SilentlyContinue) -and
        $PSNativeCommandArgumentPassing -ne 'Legacy'
    if ($modern) { return $Value }
    return $Value.Replace('"', '\"')
}

# Runs a native command, returns stdout as one string, throws with its stderr on a non-zero exit code.
# 'Continue' locally: 5.1 wraps each stderr line, such as git's progress, in an error record, and
# under 'Stop' the first one would throw.
function Invoke-Native([string] $Exe, [string[]] $Arguments) {
    $ErrorActionPreference = 'Continue'
    $all = & $Exe @Arguments 2>&1
    $code = $LASTEXITCODE
    $stdout = @($all | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
    $stderr = @($all | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() })
    if ($code -ne 0) { throw "$Exe $($Arguments[0]) $($Arguments[1]) exited with code ${code}: $($stderr -join ' ')" }
    return ($stdout -join "`n")
}

$ConfigDefaults = [ordered]@{
    searchQuery         = 'is:pr is:open archived:false user-review-requested:@me'
    repos               = [pscustomobject]@{}
    skipDraftPrs        = $true
    model               = 'opus'
    maxBudgetUsd        = 0
    allowRequestChanges = $false
    postAs              = 'app'
    githubApp           = [pscustomobject]@{ appId = ''; slug = ''; keyFile = '' }
    footer              = ''
    keepWorktree        = $false
    codexReview         = [pscustomobject]@{ enabled = $true; waitMinutes = 10 }
    # How step 3 of a review runs; see Get-ReviewTiers and Format-ReviewStep.
    reviewSkill         = [pscustomobject]@{ tiers = @(); instructions = @(); scaffold = @() }
    startReaction      = $true
    followUps           = $true
    allowedTools        = @('Read', 'Grep', 'Glob')
    disallowedTools     = @()
}

# Missing keys fall back to the defaults above, so a trimmed config.json doesn't trip StrictMode.
function Get-Config {
    $path = Join-Path $Root 'config.json'
    if (-not (Test-Path $path)) {
        throw "No config.json. Copy config.example.json to config.json and fill it in."
    }
    $config = Read-Utf8 $path | ConvertFrom-Json
    foreach ($key in $ConfigDefaults.Keys) {
        $default = $ConfigDefaults[$key]
        if (-not $config.PSObject.Properties[$key]) {
            $config | Add-Member -NotePropertyName $key -NotePropertyValue $default
        } elseif ($default -is [pscustomobject] -and $key -ne 'repos' -and $config.$key -is [pscustomobject]) {
            # Nested settings such as codexReview get their missing keys filled too.
            foreach ($sub in $default.PSObject.Properties) {
                if (-not $config.$key.PSObject.Properties[$sub.Name]) {
                    $config.$key | Add-Member -NotePropertyName $sub.Name -NotePropertyValue $sub.Value
                }
            }
        }
    }
    return $config
}

function Get-State {
    $state = @{}
    if (Test-Path $StatePath) {
        (Read-Utf8 $StatePath | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $state[$_.Name] = $_.Value }
    }
    return $state
}

function Save-State([hashtable] $State) {
    Write-Utf8 $StatePath ($State | ConvertTo-Json -Depth 5)
}

function Split-PrUrl([string] $Url) {
    if ($Url -notmatch 'github\.com/([^/]+/[^/]+)/pull/(\d+)') { throw "Not a PR URL: $Url" }
    return @{ Repo = $Matches[1]; Number = [int] $Matches[2] }
}

function Get-RepoConfig($Config, [string] $Repo) {
    $prop = $Config.repos.PSObject.Properties | Where-Object { $_.Name -eq $Repo } | Select-Object -First 1
    if ($prop) { return $prop.Value }
    return $null
}

# ---------------------------------------------------------------- GitHub

function Get-RequestedPrUrls($Config) {
    $json = Invoke-Native 'gh' @('api', '-X', 'GET', 'search/issues', '-f', "q=$($Config.searchQuery)", '-f', 'per_page=50')
    return @(($json | ConvertFrom-Json).items | ForEach-Object { $_.html_url })
}

function Get-PrInfo([string] $Url) {
    $json = Invoke-Native 'gh' @('pr', 'view', $Url, '--json', 'number,title,author,headRefName,headRefOid,baseRefName,url,isDraft,state,additions,deletions')
    $pr = $json | ConvertFrom-Json
    $pr | Add-Member -NotePropertyName repo -NotePropertyValue (Split-PrUrl $pr.url).Repo
    return $pr
}

# Sam's session has no gh api, so the script fetches the unresolved threads and quotes them in the prompt.
# Sam's own threads carry the first comment's id, which a reply needs.
function Get-OpenThreads($Info, $Threads) {
    try {
        if ($null -eq $Threads) { $Threads = Get-ReviewThreads $Info }
        return Format-Threads @($Threads | Where-Object { -not $_.isResolved })
    } catch {
        Write-Warning "Couldn't fetch the PR's review threads: $($_.Exception.Message)"
        return "Couldn't fetch them. Read them with gh pr view --comments if you can."
    }
}

function Get-ReviewThreads($Info) {
    $query = 'query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first:100){nodes{isResolved isOutdated path line comments(first:50){totalCount nodes{databaseId author{login __typename} body createdAt}}}}}}}'
    $owner, $name = $Info.repo.Split('/')
    $json = Invoke-Native 'gh' @('api', 'graphql', '-f', "query=$query", '-f', "owner=$owner", '-f', "name=$name", '-F', "number=$($Info.number)")
    return @(($json | ConvertFrom-Json).data.repository.pullRequest.reviewThreads.nodes)
}

function Get-CommentAuthor($Comment) {
    if ($Comment.author) { return $Comment.author.login }
    return 'ghost'
}

# A thread is Sam's when Sam posted its first comment. As the app, that's any thread the app started
# (GraphQL names a bot by its slug, without [bot]). With postAs 'me', Sam and you share a login, so
# only the comment ids in Sam's comment log count, never threads you wrote by hand.
function Test-SamThread($Thread) {
    $first = @($Thread.comments.nodes)[0]
    $login = Get-SamLogin
    if (-not $first -or -not $login -or (Get-CommentAuthor $first) -ne $login) { return $false }
    if ($script:SamPostsAsMe) { return (Get-SamCommentIds).Contains([long] $first.databaseId) }
    return $true
}

# The ids of every inline comment Sam has posted, from .work\logs\comments.jsonl. Re-read when the
# file changes, so a long -Loop sees new ones.
function Get-SamCommentIds {
    $log = Join-Path $LogDir 'comments.jsonl'
    $stamp = if (Test-Path $log) { (Get-Item $log).LastWriteTimeUtc.Ticks } else { 0 }
    if ($null -eq $script:SamCommentIds -or $script:SamCommentIdsStamp -ne $stamp) {
        $ids = New-Object 'System.Collections.Generic.HashSet[long]'
        if ($stamp) {
            foreach ($line in [IO.File]::ReadAllLines($log, $Utf8NoBom)) {
                if (-not $line.Trim()) { continue }
                $entry = $line | ConvertFrom-Json
                foreach ($id in @($entry.comment_id)) { if ($id) { [void] $ids.Add([long] $id) } }
            }
        }
        $script:SamCommentIds = $ids
        $script:SamCommentIdsStamp = $stamp
    }
    # The comma keeps PowerShell from unrolling the set into $null or a single id.
    return , $script:SamCommentIds
}

function Format-Threads($Threads) {
    if (@($Threads).Count -eq 0) { return 'None.' }
    $lines = foreach ($t in $Threads) {
        $where = if ($t.line) { "$($t.path):$($t.line)" } else { $t.path }
        if ($t.isOutdated) { $where += ' (outdated)' }
        if (Test-SamThread $t) { $where += " [Sam's thread, comment_id $(@($t.comments.nodes)[0].databaseId)]" }
        $where
        foreach ($c in @($t.comments.nodes)) {
            $body = $c.body
            if ($body.Length -gt 1500) { $body = $body.Substring(0, 1500) + ' ...' }
            "  $(Get-CommentAuthor $c)" + ': ' + ($body -replace '\r?\n', "`n    ")
        }
        ''
    }
    return ($lines -join "`n").TrimEnd()
}

# Sam's login as GraphQL shows it: the app's slug, or yours with postAs 'me'. Looked up once per run.
# If it can't be worked out (no slug and no imported key yet, say), it's '' and no thread counts as
# Sam's, so a draft-only run still sees every open thread.
function Get-SamLogin {
    if ($null -eq $script:SamLogin) {
        $config = Get-Config
        $slug = if ($config.githubApp.PSObject.Properties['slug']) { [string] $config.githubApp.slug } else { '' }
        $script:SamPostsAsMe = $config.postAs -eq 'me'
        try {
            $script:SamLogin = if ($config.postAs -eq 'me') { (Invoke-Native 'gh' @('api', 'user', '--jq', '.login')).Trim() }
                elseif ($slug) { $slug }
                else { (Invoke-AppApi 'GET' 'app' ('Bearer ' + (New-AppJwt ([string] $config.githubApp.appId) (Read-AppKey $config)))).slug }
        } catch {
            Write-Warning "Couldn't work out Sam's login, so no thread counts as Sam's this run: $($_.Exception.Message) Set githubApp.slug in config.json to skip this lookup."
            $script:SamLogin = ''
        }
    }
    return $script:SamLogin
}

# Sam's unresolved threads where a person spoke last, since Sam last looked at them. A bot's reply
# doesn't count, so Sam can't get into a back-and-forth with another bot.
function Get-PendingThreads($Threads, $Handled) {
    return @($Threads | Where-Object {
        $last = @($_.comments.nodes)[-1]
        $isBot = $last.author -and $last.author.PSObject.Properties['__typename'] -and $last.author.__typename -eq 'Bot'
        -not $_.isResolved -and -not $isBot -and (Test-SamThread $_) -and
            (Get-CommentAuthor $last) -ne (Get-SamLogin) -and @($Handled) -notcontains [long] $last.databaseId
    })
}

# The lines a review comment can anchor to: every added or context line on the RIGHT, every deleted or
# context line on the LEFT, per file in the PR's diff.
function Get-DiffLines([string] $Repo, [int] $Number) {
    $pages = Invoke-Native 'gh' @('api', '--paginate', '--slurp', "repos/$Repo/pulls/$Number/files?per_page=100") | ConvertFrom-Json
    $files = @{}
    foreach ($file in @($pages | ForEach-Object { $_ })) {
        # GitHub leaves out the patch for very large files; those lines count as unknown.
        if (-not $file.PSObject.Properties['patch'] -or -not $file.patch) { $files[$file.filename] = $null; continue }
        $sets = @{ RIGHT = New-Object 'System.Collections.Generic.HashSet[int]'; LEFT = New-Object 'System.Collections.Generic.HashSet[int]' }
        $files[$file.filename] = $sets
        $old = 0; $new = 0
        foreach ($line in ($file.patch -split "`n")) {
            if ($line -match '^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@') { $old = [int] $Matches[1]; $new = [int] $Matches[2]; continue }
            if ($line.StartsWith('\')) { continue }
            if ($line.StartsWith('+')) { [void] $sets.RIGHT.Add($new); $new++ }
            elseif ($line.StartsWith('-')) { [void] $sets.LEFT.Add($old); $old++ }
            else { [void] $sets.RIGHT.Add($new); [void] $sets.LEFT.Add($old); $new++; $old++ }
        }
    }
    return $files
}

# Unknown lines (no diff fetched, or no patch for the file) count as in the diff; if GitHub disagrees,
# Publish-Draft's 422 fallback moves the comments into the review body.
function Test-InDiff($DiffLines, [string] $Path, [int] $Line, [string] $Side) {
    if ($null -eq $DiffLines) { return $true }
    if (-not $DiffLines.ContainsKey($Path)) { return $false }
    if ($null -eq $DiffLines[$Path]) { return $true }
    return $DiffLines[$Path][$Side].Contains($Line)
}

# The review tiers, by changed lines (additions + deletions). Each picks the review skill for step 3
# (name; empty means Sam's built-in review), how many reviewers it spawns, and their model (empty
# means 'model'). From reviewSkill.tiers; a config with only the older top-level 'tiers' (teamReview
# instead of name) still works. With neither, one built-in tier.
function Get-ReviewTiers($Config) {
    $raw = @($Config.reviewSkill.tiers | Where-Object { $_ })
    if ($raw.Count -eq 0 -and $Config.PSObject.Properties['tiers']) { $raw = @($Config.tiers | Where-Object { $_ }) }
    if ($raw.Count -eq 0) { $raw = @([pscustomobject]@{ maxChangedLines = 0 }) }
    $tiers = @(foreach ($t in $raw) {
        $get = { param($Name, $Default) if ($t.PSObject.Properties[$Name] -and $null -ne $t.$Name -and [string] $t.$Name -ne '') { $t.$Name } else { $Default } }
        $name = [string] (& $get 'name' (& $get 'teamReview' ''))
        if ($name -and $name -notmatch '^[\w.:-]+$') { throw "Review skill name '$name' in config.json isn't a skill name (letters, digits, '.', ':', '-', '_')" }
        [pscustomobject]@{
            maxChangedLines = [int] (& $get 'maxChangedLines' 0)
            name            = $name
            reviewers       = [int] (& $get 'reviewers' 4)
            reviewerModel   = [string] (& $get 'reviewerModel' $Config.model)
        }
    })
    # The first tier that covers a change wins, so a no-limit tier (0) anywhere but last hides the rest.
    for ($i = 0; $i -lt $tiers.Count; $i++) {
        if ($tiers[$i].maxChangedLines -lt 0 -or $tiers[$i].reviewers -lt 1) {
            throw "Review tier $($i + 1) in config.json needs maxChangedLines of 0 or more and reviewers of 1 or more"
        }
        if ($tiers[$i].maxChangedLines -eq 0 -and $i -lt $tiers.Count - 1) {
            throw "Review tier $($i + 1) in config.json has no limit (maxChangedLines 0), so the tiers after it never run. Put it last."
        }
    }
    return $tiers
}

# The first tier whose maxChangedLines covers the change wins; 0 means no limit.
function Select-Tier($Config, [int] $ChangedLines) {
    $tiers = @(Get-ReviewTiers $Config)
    foreach ($tier in $tiers) {
        if ($tier.maxChangedLines -eq 0 -or $ChangedLines -le $tier.maxChangedLines) { return $tier }
    }
    return $tiers[-1]
}

# For the console and the run log.
function Get-TierLabel($Tier) {
    if ($Tier.name) { return $Tier.name }
    return 'built-in review'
}

# What Sam last did on a PR: the commit Sam's posted review covered, and the thread comments Sam has
# already looked at. Kept in state.json under "pr:<url>".
function Get-PrRecord([hashtable] $State, [string] $Url) {
    $record = @{ reviewed_sha = $null; review_url = $null; handled = @(); closed = $false }
    if ($State.ContainsKey("pr:$Url")) {
        $saved = $State["pr:$Url"]
        if ($saved -is [hashtable]) { foreach ($k in $saved.Keys) { $record[$k] = $saved[$k] } }
        else { foreach ($p in $saved.PSObject.Properties) { $record[$p.Name] = $p.Value } }
    }
    $record.handled = @($record.handled | Where-Object { $_ } | ForEach-Object { [long] $_ })
    return $record
}

# GitHub diffs a PR against the merge base of the base branch and the head. A branch that merged main
# into itself can have two merge bases locally, and git's pick shows unrelated changes, so ask GitHub.
# If GitHub can't say, fall back to git's pick, which is still a merge base and never the base branch's
# tip. Without a clone (-PromptOnly) the fallback is a placeholder.
function Get-MergeBase($Info, [string] $Clone) {
    $reason = 'it returned no merge base'
    try {
        $sha = Invoke-Native 'gh' @('api', "repos/$($Info.repo)/compare/$($Info.baseRefName)...$($Info.headRefOid)", '--jq', '.merge_base_commit.sha')
        if ($sha.Trim() -match '^[0-9a-f]{40}$') { return $sha.Trim() }
    } catch {
        $reason = $_.Exception.Message
    }
    if (-not $Clone) { return '<merge base>' }
    $local = (Invoke-Native 'git' @('-C', $Clone, 'merge-base', "origin/$($Info.baseRefName)", $Info.headRefOid)).Trim()
    Write-Warning "Couldn't get the PR's merge base from GitHub ($reason), so using git's: $local. If the branch merged $($Info.baseRefName) into itself, the diff may not match GitHub's."
    return $local
}


# ---------------------------------------------------------------- posting identity

function Read-DerLength([byte[]] $Der, [ref] $Pos) {
    $len = [int] $Der[$Pos.Value]; $Pos.Value++
    if ($len -band 0x80) {
        $count = $len -band 0x7F
        $len = 0
        for ($i = 0; $i -lt $count; $i++) { $len = ($len -shl 8) -bor $Der[$Pos.Value]; $Pos.Value++ }
    }
    return $len
}

# Returns the integer's bytes big-endian, without the leading zero DER adds when the top bit is set.
function Read-DerInteger([byte[]] $Der, [ref] $Pos) {
    if ($Der[$Pos.Value] -ne 0x02) { throw 'Malformed private key: expected an INTEGER' }
    $Pos.Value++
    $len = Read-DerLength $Der $Pos
    $start = $Pos.Value
    $Pos.Value += $len
    while ($len -gt 1 -and $Der[$start] -eq 0) { $start++; $len-- }
    $bytes = New-Object byte[] $len
    [Array]::Copy($Der, $start, $bytes, 0, $len)
    return , $bytes
}

function ConvertTo-FixedLength([byte[]] $Bytes, [int] $Length) {
    if ($Bytes.Length -ge $Length) { return , $Bytes }
    $padded = New-Object byte[] $Length
    [Array]::Copy($Bytes, 0, $padded, $Length - $Bytes.Length, $Bytes.Length)
    return , $padded
}

# GitHub hands out app keys as PKCS#1 PEM, which .NET Framework (Windows PowerShell 5.1) can't
# import, so the DER is read by hand: SEQUENCE { version, n, e, d, p, q, dp, dq, qinv }.
function Read-RsaPrivateKey([string] $Pem) {
    if ($Pem -notmatch '-----BEGIN RSA PRIVATE KEY-----([\s\S]+?)-----END RSA PRIVATE KEY-----') {
        throw "Not a PKCS#1 RSA private key (-----BEGIN RSA PRIVATE KEY-----)"
    }
    $der = [Convert]::FromBase64String(($Matches[1] -replace '\s', ''))
    if ($der[0] -ne 0x30) { throw 'Malformed private key: expected a SEQUENCE' }
    $pos = 1
    [void] (Read-DerLength $der ([ref] $pos))
    $ints = New-Object 'System.Collections.Generic.List[byte[]]'
    for ($i = 0; $i -lt 9; $i++) { $ints.Add((Read-DerInteger $der ([ref] $pos))) }

    # RSAParameters wants D as long as the modulus and the CRT values half as long, zero-padded.
    $size = $ints[1].Length
    $half = [int] [Math]::Ceiling($size / 2)
    $params = New-Object System.Security.Cryptography.RSAParameters
    $params.Modulus = $ints[1]
    $params.Exponent = $ints[2]
    $params.D = ConvertTo-FixedLength $ints[3] $size
    $params.P = ConvertTo-FixedLength $ints[4] $half
    $params.Q = ConvertTo-FixedLength $ints[5] $half
    $params.DP = ConvertTo-FixedLength $ints[6] $half
    $params.DQ = ConvertTo-FixedLength $ints[7] $half
    $params.InverseQ = ConvertTo-FixedLength $ints[8] $half
    $rsa = New-Object System.Security.Cryptography.RSACng
    $rsa.ImportParameters($params)
    return $rsa
}

function ConvertTo-Base64Url([byte[]] $Bytes) {
    return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

# A JWT that proves "I am the app" for up to 10 minutes. Backdated a minute for clock drift.
function New-AppJwt([string] $AppId, [string] $Pem) {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $header = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"RS256","typ":"JWT"}'))
    $claims = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes(
        ([ordered]@{ iat = $now - 60; exp = $now + 540; iss = $AppId } | ConvertTo-Json -Compress)))
    $unsigned = "$header.$claims"
    $rsa = Read-RsaPrivateKey $Pem
    try {
        $signature = $rsa.SignData([Text.Encoding]::ASCII.GetBytes($unsigned),
            [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    } finally {
        $rsa.Dispose()
    }
    return "$unsigned.$(ConvertTo-Base64Url $signature)"
}

# Calls GitHub directly: gh sends "token <x>", and app JWTs only work as "Bearer <x>".
function Invoke-AppApi([string] $Method, [string] $Path, [string] $Authorization, $Body) {
    $request = @{
        Method          = $Method
        Uri             = "https://api.github.com/$Path"
        UseBasicParsing = $true
        Headers         = @{ Authorization = $Authorization; Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28' }
    }
    if ($null -ne $Body) {
        $request.Body = $Body | ConvertTo-Json -Depth 5 -Compress
        $request.ContentType = 'application/json'
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    try {
        return Invoke-RestMethod @request
    } catch {
        $detail = if ($_.ErrorDetails) { $_.ErrorDetails.Message } else { '' }
        throw "GitHub App call $Method $Path failed: $($_.Exception.Message) $detail"
    }
}

# The app key lives on disk only encrypted with DPAPI, which only your Windows account on this PC
# can undo. Sam's session can read files outside the worktree (git blame --contents, 8.3 short
# paths, ...), and no path rule closes every route, so a readable PEM could be quoted into a review.
# Read through any route, this file is useless anywhere else.
$KeyEntropy = [Text.Encoding]::UTF8.GetBytes('sam github app key')
$DefaultKeyFile = '%USERPROFILE%\.config\sam\github-app-key.bin'

function Get-AppKeyFile($Config) {
    $app = $Config.githubApp
    $path = if ($app.PSObject.Properties['keyFile']) { [string] $app.keyFile } else { '' }
    if (-not $path) { return $null }
    $path = [Environment]::ExpandEnvironmentVariables($path)
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $Root $path }
    return $path
}

function Read-AppKey($Config) {
    $path = Get-AppKeyFile $Config
    if (-not $path) { throw "postAs is 'app' but githubApp.keyFile is empty in config.json" }
    if (-not (Test-Path -LiteralPath $path)) { throw "Sam's app key isn't at $path. Run .\sam.ps1 -ImportKey <path to the .pem>." }
    $bytes = [IO.File]::ReadAllBytes($path)
    $start = [Text.Encoding]::UTF8.GetString($bytes, 0, [Math]::Min(64, $bytes.Length)).TrimStart([char] 0xFEFF, ' ', "`t", "`r", "`n")
    if ($start.StartsWith('-----')) {
        throw "$path is a plain-text key. Run .\sam.ps1 -ImportKey $path (it writes the encrypted key to $DefaultKeyFile), set githubApp.keyFile to that, and delete the .pem."
    }
    Add-Type -AssemblyName System.Security
    try {
        $plain = [Security.Cryptography.ProtectedData]::Unprotect($bytes, $KeyEntropy, 'CurrentUser')
    } catch {
        throw "Couldn't decrypt $path ($($_.Exception.InnerException.Message.Trim())). It was encrypted by another Windows account or PC, or isn't a key file. Run .\sam.ps1 -ImportKey <the .pem> again."
    }
    return [Text.Encoding]::ASCII.GetString($plain)
}

# DPAPI only helps if no plain copy is lying around. Sam's session can read outside the worktree, and
# this folder's path is in every prompt, so refuse to start one while a .pem sits in it.
function Assert-NoPlainKey {
    $found = @(Get-ChildItem -LiteralPath $Root -Recurse -Depth 3 -File -Filter '*.pem' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\\.work\\' })
    if ($found.Count -gt 0) {
        throw "Plain-text key file(s) in Sam's folder: $(($found | ForEach-Object FullName) -join ', '). Sam's session could read and leak them. Import with -ImportKey if you haven't, then delete them."
    }
}

# One-time setup: encrypt the .pem from the app's owner into githubApp.keyFile, then prove it works.
function Import-AppKey($Config, [string] $PemPath) {
    $pem = Read-Utf8 $PemPath
    (Read-RsaPrivateKey $pem).Dispose()
    $configured = Get-AppKeyFile $Config
    $out = $configured
    # Never encrypt over the .pem itself (an old config may point keyFile at it): the user is about
    # to be told to delete the .pem.
    if (-not $out -or $out -like '*.pem' -or [IO.Path]::GetFullPath($out) -eq [IO.Path]::GetFullPath($PemPath)) {
        $out = [Environment]::ExpandEnvironmentVariables($DefaultKeyFile)
    }
    $dir = Split-Path $out -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }

    Add-Type -AssemblyName System.Security
    $sealed = [Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::ASCII.GetBytes($pem), $KeyEntropy, 'CurrentUser')
    [IO.File]::WriteAllBytes($out, $sealed)
    Invoke-Native 'icacls' @($out, '/inheritance:r', '/grant:r', "$env:USERDOMAIN\${env:USERNAME}:(F)") | Out-Null

    $appId = if ($Config.githubApp.PSObject.Properties['appId']) { [string] $Config.githubApp.appId } else { '' }
    if ($appId) {
        $Config.githubApp | Add-Member -NotePropertyName keyFile -NotePropertyValue $out -Force
        $slug = (Invoke-AppApi 'GET' 'app' ('Bearer ' + (New-AppJwt $appId (Read-AppKey $Config)))).slug
        Write-Host "Key works: signed in as the $slug app."
    }
    Write-Host "Encrypted key written to $out (only your Windows account on this PC can use it)."
    if ($configured -ne $out) { Write-Host "Set githubApp.keyFile in config.json to that path." }
    Write-Host "Now delete $PemPath. Sam's session can read files outside the PR, so a plain .pem anywhere on this PC can leak."
}

# postAs 'me': returns $null and gh posts as whoever `gh auth status` shows (you).
# postAs 'app': returns the app's bot login and an installation token narrowed to writing pull
# request reviews on this one repo. The app itself has more (see TODO.md); the token never does.
# Detection and PR lookups keep using your gh login, because "requested as reviewer" is about you.
function Get-PostingToken($Config, [string] $Repo) {
    if ($Config.postAs -eq 'me') { return $null }
    if ($Config.postAs -ne 'app') { throw "postAs in config.json must be 'app' or 'me', not '$($Config.postAs)'" }

    $app = $Config.githubApp
    $appId = if ($app.PSObject.Properties['appId']) { [string] $app.appId } else { '' }
    if (-not $appId) { throw "postAs is 'app' but githubApp.appId is empty in config.json" }

    $jwt = 'Bearer ' + (New-AppJwt $appId (Read-AppKey $Config))
    $slug = (Invoke-AppApi 'GET' 'app' $jwt).slug
    $installation = Invoke-AppApi 'GET' "repos/$Repo/installation" $jwt
    $token = Invoke-AppApi 'POST' "app/installations/$($installation.id)/access_tokens" $jwt @{
        repositories = @($Repo.Split('/')[1])
        permissions  = @{ pull_requests = 'write' }
    }
    return [pscustomobject]@{ Login = "$slug[bot]"; Token = $token.token }
}

# A backstop, not the protection (that's DPAPI above): catches any PEM header, such as a key Sam was
# tricked into reading from elsewhere, and any 32-character run of the app key's base64. Re-encoded
# text gets past it.
function Test-LeaksKey($Config, [string] $Text) {
    if ($Text -match 'PRIVATE KEY-----') { return $true }
    if ($Config.postAs -ne 'app') { return $false }
    $pem = Read-AppKey $Config
    $flat = $Text -replace '\s', ''
    # The key's base64 as one run, so a quote that starts mid-line or spans a line break is caught too.
    $body = (@($pem -split '\r?\n') | Where-Object { -not $_.StartsWith('-----') }) -join ''
    $body = $body -replace '\s', ''
    for ($i = 0; $i + 32 -le $body.Length; $i++) {
        if ($flat.Contains($body.Substring($i, 32))) { return $true }
    }
    return $false
}

# Checks exactly what is about to be sent, comment paths included.
function Assert-NoKey($Config, $Payload) {
    $parts = @($Payload.body) + @($Payload.comments | ForEach-Object { $_.path; $_.body })
    if (Test-LeaksKey $Config ($parts -join "`n")) {
        throw "Refusing to post: the review contains a private key or part of Sam's app key."
    }
}

# Tokens expire within the hour anyway; revoking just shortens that.
function Revoke-PostingToken($Identity) {
    if (-not $Identity) { return }
    try {
        Invoke-AppApi 'DELETE' 'installation/token' "token $($Identity.Token)" | Out-Null
    } catch {
        Write-Verbose "Couldn't revoke the posting token; it expires within the hour. $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------- checkout

function Get-ClonePath($Config, [string] $Repo) {
    $repoConfig = Get-RepoConfig $Config $Repo
    $path = $null
    if ($repoConfig -and $repoConfig.PSObject.Properties['clonePath']) { $path = $repoConfig.clonePath }
    if (-not $path) { $path = Join-Path $WorkDir ('clones\' + ($Repo -replace '/', '\')) }
    if (-not (Test-Path (Join-Path $path '.git'))) {
        Write-Host "Cloning $Repo into $path (first run only)"
        Invoke-Native 'gh' @('repo', 'clone', $Repo, $path, '--', '-c', 'core.longpaths=true') | Out-Null
    }
    return $path
}

function Remove-Worktree([string] $Clone, [string] $Worktree) {
    $ErrorActionPreference = 'Continue'
    if (Test-Path $Worktree) {
        & git -C $Clone worktree remove --force $Worktree
        if (Test-Path $Worktree) { Remove-Item -Recurse -Force $Worktree }
    }
    & git -C $Clone worktree prune
}

function Sync-PrRefs([string] $Clone, $Info) {
    $base = $Info.baseRefName
    Invoke-Native 'git' @('-C', $Clone, 'fetch', '-q', 'origin',
        "+refs/heads/${base}:refs/remotes/origin/$base",
        "+refs/pull/$($Info.number)/head:refs/sam/pr-$($Info.number)") | Out-Null
}

# -Suffix gives Codex a checkout of its own, so it never sees Sam's temporary experiments.
function New-Worktree([string] $Clone, $Info, [string] $Suffix = '') {
    $worktree = Join-Path $WorkDir ('wt\' + ($Info.repo -replace '/', '-') + "-$($Info.number)$Suffix")
    Remove-Worktree $Clone $worktree
    Invoke-Native 'git' @('-C', $Clone, 'worktree', 'add', '--quiet', '--detach', $worktree, $Info.headRefOid) | Out-Null
    return $worktree
}

# The review's run directory: the one place outside the worktree where Sam and any reviewers it spawns
# may write. It sits outside the worktree because some review skills block their reviewers from writing
# inside the repository under review. reviewSkill.scaffold lays it out the way the configured skill
# expects: entries ending in / become folders, the rest empty files. Kept after the run for a look at
# the reports; .work is safe to clear.
function New-RunDir($Config, $Info) {
    $name = ($Info.repo -replace '/', '-') + "-$($Info.number)-$($Info.headRefOid.Substring(0, 7))-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
    $runDir = Join-Path $WorkDir "runs\$name"
    New-Item -ItemType Directory -Force $runDir | Out-Null
    foreach ($entry in @($Config.reviewSkill.scaffold)) {
        $entry = [string] $entry
        if (-not $entry) { continue }
        if ([IO.Path]::IsPathRooted($entry) -or $entry -match '(^|[\\/])\.\.([\\/]|$)') {
            throw "reviewSkill.scaffold entry '$entry' must be a relative path inside the run directory"
        }
        $path = Join-Path $runDir ($entry.TrimEnd('/', '\'))
        if ($entry -match '[\\/]$') {
            New-Item -ItemType Directory -Force $path | Out-Null
        } else {
            $parent = Split-Path $path -Parent
            if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force $parent | Out-Null }
            Write-Utf8 $path ''
        }
    }
    return $runDir
}

# Claude Code matches absolute paths in POSIX form, and only Edit(...) rules cover the Write tool:
# C:\a\b becomes Edit(//c/a/b/**).
function ConvertTo-EditRule([string] $Path) {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    return 'Edit(//' + $full.Substring(0, 1).ToLowerInvariant() + ($full.Substring(2) -replace '\\', '/') + '/**)'
}

# ---------------------------------------------------------------- Codex

# Codex reviews the same diff in the background while Sam works, read-only and in its own worktree.
# Its findings go to a file that Sam checks in a second pass. --ignore-rules drops the user's
# execpolicy allow rules (such as one for dotnet test). --ignore-user-config isn't used: without the
# user's config, Codex's sandbox blocks even git diff, and it still exits 0.
function Start-CodexReview($Config, $Info, [string] $Worktree, [string] $Base) {
    $settings = $Config.codexReview
    if (-not $settings -or -not $settings.enabled) { return $null }
    $codex = Get-Command codex -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $codex) {
        Write-Warning "Codex isn't on PATH, so Sam reviews without it."
        return $null
    }
    $dir = Join-Path $WorkDir 'codex'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
    $name = ($Info.repo -replace '/', '-') + "-$($Info.number)"
    $out = Join-Path $dir "$name.md"
    $stdin = Join-Path $dir 'empty.txt'
    Write-Utf8 $stdin ''
    Remove-Item $out -ErrorAction SilentlyContinue
    $arguments = "exec review --base $Base --ephemeral --ignore-rules -c sandbox_mode=read-only -o `"$out`""
    $process = Start-Process -FilePath $codex.Source -ArgumentList $arguments -WorkingDirectory $Worktree -NoNewWindow -PassThru `
        -RedirectStandardInput $stdin -RedirectStandardOutput (Join-Path $dir "$name.log") -RedirectStandardError (Join-Path $dir "$name.err.log")
    # Touching Handle now keeps ExitCode readable after the process exits (Start-Process quirk).
    $null = $process.Handle
    Write-Host 'Codex is reviewing the same diff in the background.'
    return [pscustomobject]@{ Process = $process; Output = $out; Log = Join-Path $dir "$name.err.log"; Worktree = $Worktree }
}

function Stop-CodexReview($Codex) {
    if (-not $Codex -or $Codex.Process.HasExited) { return }
    $ErrorActionPreference = 'Continue'
    & taskkill /T /F /PID $Codex.Process.Id 2>&1 | Out-Null
}

# Called once Sam's first pass is done. Codex gets codexReview.waitMinutes more from then; past that
# it's stopped. Returns its review text (or $null) and a status for the run log: off, ok, timeout or
# failed. The output file is removed once read.
function Wait-CodexReview($Config, $Codex) {
    if (-not $Codex) { return [pscustomobject]@{ Text = $null; Status = 'off' } }
    $minutes = [double] $Config.codexReview.waitMinutes
    if (-not $Codex.Process.HasExited) { Write-Host "Waiting up to $minutes minutes for Codex to finish..." }
    if (-not $Codex.Process.WaitForExit([int] ($minutes * 60000))) {
        Stop-CodexReview $Codex
        Write-Warning "Codex was still running $minutes minutes after Sam's first pass, so Sam's review goes ahead without it."
        return [pscustomobject]@{ Text = $null; Status = 'timeout' }
    }
    $text = if (Test-Path $Codex.Output) { (Read-Utf8 $Codex.Output).Trim() } else { '' }
    if ($Codex.Process.ExitCode -ne 0 -or -not $text) {
        Write-Warning "Codex's review failed (exit $($Codex.Process.ExitCode)), so Sam's review goes ahead without it. Its log: $($Codex.Log)"
        return [pscustomobject]@{ Text = $null; Status = 'failed' }
    }
    Remove-Item $Codex.Output -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Text = $text; Status = 'ok' }
}

# ---------------------------------------------------------------- Sam

# PR text is untrusted; stop it closing the fenced block it is quoted in.
function Protect-Quoted([string] $Text) {
    return $Text.Replace('```', "'''")
}

# Fills {{key}} placeholders in one of Sam's templates in a single pass, so text inside a value that
# looks like a placeholder, such as a branch named feat/{{title}}, is never filled.
function Expand-Text([string] $Text, $Values) {
    $evaluator = [Text.RegularExpressions.MatchEvaluator] {
        param($match)
        $key = $match.Groups[1].Value
        if ($Values.Contains($key)) { return [string] $Values[$key] }
        return $match.Value
    }.GetNewClosure()
    return [regex]::Replace($Text, '\{\{(\w+)\}\}', $evaluator)
}

function Expand-Template([string] $File, $Values) {
    return Expand-Text (Read-Utf8 (Join-Path $Root $File)) $Values
}

# The review step: step 3 of sam-pr-review.md, or a sentence group inside step 2 of sam-pr-followup.md
# (-Followup). With the tier's skill name set, Sam runs that skill (a multi-agent team review, say) and
# follows reviewSkill.instructions. With no name, or if the skill isn't installed, Sam runs the
# built-in review. Both come from config.json, not the PR. Their placeholders are filled from
# $Values, which hold only values the script controls, never PR text.
function Format-ReviewStep($Config, $Tier, $Values, [switch] $Followup) {
    $scope = if ($Followup) { 'the new-changes diff above' } else { '`git diff {{merge_base}} HEAD`' }
    $builtIn = @(
        "Review the diff through each of these lenses in turn: correctness and error handling, security, tests, design and fit with the repo's documented standards, and documentation accuracy.",
        'You may spawn up to {{reviewer_count}} subagents with the Agent tool to take lenses in parallel. Spawn them in the foreground, all in one message, with `model: "{{reviewer_model}}"`, so they report back before you continue. Background agents can''t report back in this session.',
        'Notes and reports can go in the run directory at `{{run_dir}}`. It''s outside the checkout, and it''s the one place outside it you and any subagents can write.'
    )
    $name = [string] $Tier.name
    $size = if ($Followup) { 'This change is {{changed_lines}} lines' } else { 'This PR changes {{changed_lines}} lines' }
    $instructions = @($Config.reviewSkill.instructions | Where-Object { [string] $_ })
    $fallback = "If the Skill tool can't find ``$name``, say so in ``notes_for_jg`` and run the built-in review instead. " + ($builtIn[0..1] -join ' ')
    if ($Followup) {
        $text = if ($name) {
            "$size, so it gets ``$name``. Invoke it with the Skill tool, scoped to $scope. Use the run directory at ``{{run_dir}}``. " +
                (@($instructions) + $fallback -join ' ')
        } else {
            "Run the built-in review, scoped to ${scope}: " + ($builtIn -join ' ')
        }
        return Expand-Text $text $Values
    }
    $lines = New-Object System.Collections.Generic.List[string]
    if (-not $name) {
        $lines.Add("3. **Review it.** Run the built-in review, scoped to ${scope}:")
        foreach ($b in $builtIn) { $lines.Add("   - $b") }
    } else {
        $lines.Add("3. **Run the review skill.** $size, so it gets ``$name``. Invoke it with the Skill tool, scoped to $scope. In this session:")
        $lines.Add('   - Use the run directory that''s already created at `{{run_dir}}`. Don''t create another one. It''s outside the checkout, and it''s the one place outside it you and the skill''s reviewers can write.')
        foreach ($i in $instructions) { $lines.Add("   - $i") }
        $lines.Add("   - $fallback")
    }
    return Expand-Text ($lines -join "`n") $Values
}

# The values every review template shares. $Plan carries the tier and, for a follow-up, its scope.
function Get-PromptValues($Config, $Info, [string] $Worktree, [string] $RunDir, $Plan, $Threads, [switch] $Followup) {
    $trusted = [ordered]@{
        merge_base     = $Info.mergeBase
        worktree       = $Worktree
        run_dir        = $RunDir
        model          = $Config.model
        changed_lines  = [string] $Plan.ChangedLines
        reviewer_count = [string] $Plan.Tier.reviewers
        reviewer_model = $Plan.Tier.reviewerModel
    }
    return [ordered]@{
        repo           = $Info.repo
        number         = [string] $Info.number
        head_ref       = $Info.headRefName
        base_ref       = $Info.baseRefName
        merge_base     = $Info.mergeBase
        head_sha       = $Info.headRefOid
        url            = $Info.url
        worktree       = $Worktree
        run_dir        = $RunDir
        changed_lines  = [string] $Plan.ChangedLines
        review_step    = Format-ReviewStep $Config $Plan.Tier $trusted -Followup:$Followup
        title          = Protect-Quoted $Info.title
        author         = Protect-Quoted $Info.author.login
        open_threads   = Protect-Quoted (Get-OpenThreads $Info $Threads)
    }
}

function New-SamPrompt($Config, $Info, [string] $Worktree, [string] $RunDir, $Plan, $Threads) {
    return Expand-Template 'sam-pr-review.md' (Get-PromptValues $Config $Info $Worktree $RunDir $Plan $Threads)
}

# What a follow-up diffs against: Complete-Plan's base, or Sam's reviewed commit.
function Get-DiffBase($Plan) {
    if ($Plan.PSObject.Properties['DiffBase'] -and $Plan.DiffBase) { return $Plan.DiffBase }
    return $Plan.ReviewedSha
}

function New-FollowupPrompt($Config, $Info, [string] $Worktree, [string] $RunDir, $Plan, $Threads) {
    $values = Get-PromptValues $Config $Info $Worktree $RunDir $Plan $Threads -Followup
    $values.reviewed_sha = $Plan.ReviewedSha
    $values.scope = if ($Plan.Mode -eq 'followup') {
        $base = Get-DiffBase $Plan
        $merged = if ($base -ne $Plan.ReviewedSha) { " The author merged ``$($Info.baseRefName)`` in since Sam's review, so ``$($base.Substring(0, 7))`` is Sam's reviewed commit with that merge applied, made locally. Diffing against it leaves out everyone else's changes." } else { '' }
        # File names come from the PR: each is quoted, so a space can't split one, and the command sits
        # in a fenced block, so a backtick in a name can't break out of it.
        $paths = @($Plan.Files | ForEach-Object { '"' + $_ + '"' }) -join ' '
        $fence = '```'
        "The author pushed new commits. The new changes are $($Plan.ChangedLines) lines in the PR's files, shown by this command (the file names are quoted data from the PR):`n$fence" + "text`n" +
            (Protect-Quoted "git diff $base HEAD -- $paths") + "`n$fence`nReview only those.$merged"
    } else {
        "This time Sam only answers the replies waiting in Sam's threads: skip step 2, and leave ``comments``, ``minor_notes`` and ``summary`` empty. ``git log $($Plan.ReviewedSha)..HEAD`` shows any commits since Sam's review, which a reply may point to."
    }
    $ids = @($Plan.Pending | ForEach-Object { 'comment_id ' + @($_.comments.nodes)[0].databaseId })
    $values.pending = if ($ids.Count) { $ids -join ', ' } else { 'none.' }
    return Expand-Template 'sam-pr-followup.md' $values
}

# $Base is the commit Codex diffed against: the merge base, or Sam's last reviewed commit on a follow-up.
function New-CodexFollowup([string] $Base, [string] $CodexReview) {
    return Expand-Template 'sam-codex-followup.md' ([ordered]@{
        diff_base    = $Base
        codex_review = Protect-Quoted $CodexReview
    })
}

function New-SystemPromptFile {
    $text = (Read-Utf8 (Join-Path $Root 'sam-system.md')) + "`n`n" + (Read-Utf8 (Join-Path $Root 'comment-standards.md'))
    $path = Join-Path $WorkDir 'system-prompt.md'
    Write-Utf8 $path $text
    return $path
}

# -ResumeSession continues an earlier session with a follow-up prompt, such as the Codex second pass.
# $RunDir is the review's run directory, the one place outside the worktree Sam may write.
function Invoke-Sam($Config, [string] $Prompt, [string] $Worktree, [string] $RunDir, [string] $ResumeSession) {
    Assert-NoPlainKey
    # Compressed JSON only has spaces inside strings; \u0020 keeps it valid JSON and keeps 5.1's
    # argument quoting from splitting it.
    $schema = (Read-Utf8 (Join-Path $Root 'review-schema.json') | ConvertFrom-Json | ConvertTo-Json -Depth 20 -Compress).Replace(' ', '\u0020')
    # The worktree is the PR's code, and -p skips the workspace trust prompt. Load only your user
    # settings and no MCP servers, so the PR's .claude/settings.json hooks and .mcp.json never run.
    # dontAsk refuses every tool outside the lists below, whatever default mode your user settings set.
    $claudeArgs = @('-p', '--output-format', 'json',
        '--model', $Config.model,
        '--setting-sources', 'user',
        '--strict-mcp-config',
        '--permission-mode', 'dontAsk',
        '--append-system-prompt-file', (New-SystemPromptFile),
        '--json-schema', (Format-NativeArg $schema))
    if ($ResumeSession) { $claudeArgs += @('--resume', $ResumeSession) }
    if ($Config.maxBudgetUsd -gt 0) { $claudeArgs += @('--max-budget-usd', [string] $Config.maxBudgetUsd) }
    $allowed = @($Config.allowedTools | Where-Object { $_ })
    if ($RunDir) { $allowed += ConvertTo-EditRule $RunDir }
    $denied = @($Config.disallowedTools | Where-Object { $_ })
    # claude rejects either flag with no value after it, so an empty list leaves the flag out.
    if ($allowed.Count) { $claudeArgs += @('--allowedTools') + $allowed }
    if ($denied.Count) { $claudeArgs += @('--disallowedTools') + $denied }

    # claude's stderr goes to a file, so its error reaches the thrown message, state.json and the
    # scheduled poll's log, which a console-only stderr never does.
    $errLog = Join-Path $WorkDir 'claude-stderr.log'
    Push-Location $Worktree
    # MSBuild node reuse keeps processes holding files in the worktree, which blocks removing it.
    $env:MSBUILDDISABLENODEREUSE = '1'
    try {
        $ErrorActionPreference = 'Continue'
        $raw = ($Prompt | & claude @claudeArgs 2> $errLog) -join "`n"
        $exit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
        Remove-Item Env:\MSBUILDDISABLENODEREUSE -ErrorAction SilentlyContinue
        Pop-Location
    }
    if (-not $raw.Trim()) {
        $stderr = if (Test-Path -LiteralPath $errLog) { (@(Get-Content -LiteralPath $errLog -Tail 20) -join ' ').Trim() } else { '' }
        throw "claude exited $exit with no output: $stderr"
    }
    try { $result = $raw | ConvertFrom-Json } catch { throw "claude exited $exit with output that isn't JSON: $raw" }
    $props = $result.PSObject.Properties
    if (-not $props['structured_output'] -or -not $result.structured_output -or ($props['is_error'] -and $result.is_error)) {
        $subtype = if ($props['subtype']) { $result.subtype } else { 'unknown' }
        $message = if ($props['result']) { $result.result } else { $raw.Substring(0, [Math]::Min(500, $raw.Length)) }
        throw "Sam's session failed (exit $exit, $subtype): $message"
    }
    return $result
}

# ---------------------------------------------------------------- drafts

# A re-run on the same commit (-Force) gets a new suffix instead of overwriting an earlier draft.
function Get-DraftBase($Info) {
    $base = Join-Path $DraftDir (($Info.repo -replace '/', '-') + "-$($Info.number)-$($Info.headRefOid.Substring(0, 7))")
    $candidate = $base
    $n = 2
    while (Test-Path "$candidate.json") { $candidate = "$base-$n"; $n++ }
    return $candidate
}

# Minor notes as bullets; the extras beyond the posted ten use this for the console and the preview.
function Format-NoteBullets($Notes) {
    $labels = @{ minor = 'Minor'; nitpick = 'Nitpick' }
    return @(foreach ($n in @($Notes)) {
        $label = if ($labels.ContainsKey([string] $n.category)) { $labels[[string] $n.category] } else { 'Minor' }
        "- [$label] ``$($n.path):$($n.line)`` $($n.note)"
    })
}

function Get-ExtraNotes($Review) {
    if (-not $Review.PSObject.Properties['extra_minor_notes']) { return @() }
    return @($Review.extra_minor_notes | Where-Object { $_ })
}

function Format-DraftPreview($Draft) {
    $review = $Draft.review
    $mode = Get-DraftField $Draft 'mode' 'full'
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Sam's draft: $($Draft.repo)#$($Draft.number) @ $($Draft.head_sha.Substring(0, 7))")
    $lines.Add('')
    $lines.Add("$($Draft.url)  ")
    $kind = switch ($mode) {
        'followup' { "Follow-up on the changes since $(([string] $Draft.reviewed_sha).Substring(0, 7))" }
        'replies' { 'Replies in Sam''s threads only' }
        default { 'Full review' }
    }
    $lines.Add("$kind. Verdict: **$($review.verdict)**. Session: ``$($Draft.session_id)``. Cost: `$$($Draft.cost_usd)")
    $lines.Add('')
    $lines.Add('## Notes for JG (never posted)')
    $lines.Add('')
    $lines.Add($review.notes_for_jg)
    if ($mode -eq 'full' -or ([string] $review.summary).Trim()) {
        $lines.Add('')
        $lines.Add('## Summary (posted as the review body)')
        $lines.Add('')
        $lines.Add($review.summary)
    }
    if (@($review.comments).Count) {
        $lines.Add('')
        $lines.Add('## Inline comments')
    }
    foreach ($c in @($review.comments)) {
        $severity = if ($c.PSObject.Properties['severity'] -and $c.severity) { " (severity $($c.severity))" } else { '' }
        $lines.Add('')
        $lines.Add("### ``$($c.path):$($c.line)``$severity")
        $lines.Add('')
        $lines.Add((Get-CommentTag $c) + $c.body)
    }
    $minor = Format-MinorNotes $review
    if ($minor) {
        $lines.Add('')
        $lines.Add('## Minor and nitpicks (posted as one separate comment)')
        $lines.Add('')
        $lines.Add($minor)
    }
    $extras = @(Get-ExtraNotes $review)
    if ($extras.Count) {
        $lines.Add('')
        $lines.Add('## More minor notes (never posted)')
        $lines.Add('')
        foreach ($b in (Format-NoteBullets $extras)) { $lines.Add($b) }
    }
    $replies = @(Get-ThreadReplies $review)
    if ($replies.Count) {
        $lines.Add('')
        $lines.Add('## Answers in Sam''s threads')
        foreach ($r in $replies) {
            $reaction = Get-ReplyReaction $r
            $lines.Add('')
            $lines.Add("### Thread $($r.comment_id)$(if ($reaction) { " (reacts $reaction)" })")
            if (([string] $r.body).Trim()) {
                $lines.Add('')
                $lines.Add($r.body)
            }
        }
    }
    $lines.Add('')
    $lines.Add('## What Sam ran')
    $lines.Add('')
    foreach ($r in @($review.ran)) { $lines.Add("- $r") }
    $lines.Add('')
    $lines.Add("Codex second pass: $(if ($Draft.codex_review) { 'yes, its raw review is in the .json' } else { 'no' })")
    return ($lines -join "`n")
}

function Save-Draft($Info, $Result, [string] $CodexReview, $Plan) {
    if (-not (Test-Path $DraftDir)) { New-Item -ItemType Directory $DraftDir | Out-Null }
    $draft = [pscustomobject][ordered]@{
        repo       = $Info.repo
        number     = $Info.number
        url        = $Info.url
        title      = $Info.title
        head_sha   = $Info.headRefOid
        mode       = $Plan.Mode
        reviewed_sha = $Plan.ReviewedSha
        created    = (Get-Date).ToString('o')
        session_id = $Result.session_id
        cost_usd   = $Result.total_cost_usd
        posted_url       = $null
        posted_minor_url = $null
        posted_replies   = [pscustomobject]@{}
        posted_reactions = [pscustomobject]@{}
        review           = $Result.structured_output
        codex_review     = $CodexReview
    }
    $base = Get-DraftBase $Info
    Write-Utf8 "$base.json" ($draft | ConvertTo-Json -Depth 20)
    Write-Utf8 "$base.md" (Format-DraftPreview $draft)
    return "$base.json"
}

# ---------------------------------------------------------------- posting

$CommentTags = @{ blocking = '[Blocking] '; needs_decision = '[Needs a decision] '; optional = '[Optional] ' }

# Drafts from before categories carry only a 'blocking' flag.
function Get-CommentTag($Comment) {
    $props = $Comment.PSObject.Properties
    if ($props['category'] -and $CommentTags.ContainsKey([string] $Comment.category)) { return $CommentTags[[string] $Comment.category] }
    if ($props['blocking'] -and $Comment.blocking) { return $CommentTags['blocking'] }
    return ''
}

# The minor and nitpick findings as one short comment, or $null when there are none.
function Format-MinorNotes($Review) {
    if (-not $Review.PSObject.Properties['minor_notes']) { return $null }
    # The schema caps the list at 10; this makes sure of it.
    $notes = @($Review.minor_notes | Where-Object { $_ } | Select-Object -First 10)
    if ($notes.Count -eq 0) { return $null }
    return "A few smaller things, none blocking:`n`n" + ((Format-NoteBullets $notes) -join "`n")
}

# Writes to GitHub with the app's token when there is one. GH_TOKEN is set only for this one call, so
# nothing else (Sam's session included) ever sees it. Returns the parsed response, or $null if empty.
function Invoke-GhWrite([string] $Method, [string] $Path, $Payload, $Identity) {
    $arguments = @('api', '-X', $Method, $Path)
    if ($null -ne $Payload) {
        $file = Join-Path $WorkDir 'post-payload.json'
        Write-Utf8 $file ($Payload | ConvertTo-Json -Depth 20)
        $arguments += @('--input', $file)
    }
    $savedToken = $env:GH_TOKEN
    if ($Identity) { $env:GH_TOKEN = $Identity.Token }
    try {
        $json = Invoke-Native 'gh' $arguments
    } finally {
        if ($Identity) { $env:GH_TOKEN = $savedToken }
    }
    if (-not $json.Trim()) { return $null }
    return $json | ConvertFrom-Json
}

function Send-Review([string] $Repo, [int] $Number, $Payload, $Identity) {
    return Invoke-GhWrite 'POST' "repos/$Repo/pulls/$Number/reviews" $Payload $Identity
}

# A PR's conversation comment goes through the issues API; pull requests write covers it on a PR.
function Send-PrComment([string] $Repo, [int] $Number, [string] $Body, $Identity) {
    return (Invoke-GhWrite 'POST' "repos/$Repo/issues/$Number/comments" ([ordered]@{ body = $Body }) $Identity).html_url
}

function Send-ThreadReply([string] $Repo, [int] $Number, [long] $CommentId, [string] $Body, $Identity) {
    return (Invoke-GhWrite 'POST' "repos/$Repo/pulls/$Number/comments/$CommentId/replies" ([ordered]@{ body = $Body }) $Identity).html_url
}

# An eyes reaction on the PR while Sam works, as the app, only when Sam will post. Failing to add or remove it never
# stops a review.
function Add-StartReaction($Config, $Info) {
    if (-not $Post -or $Config.postAs -ne 'app' -or -not $Config.startReaction) { return $null }
    $identity = $null
    try {
        $identity = Get-PostingToken $Config $Info.repo
        $reaction = Invoke-GhWrite 'POST' "repos/$($Info.repo)/issues/$($Info.number)/reactions" ([ordered]@{ content = 'eyes' }) $identity
        return $reaction.id
    } catch {
        Write-Warning "Couldn't add the eyes reaction: $($_.Exception.Message)"
        return $null
    } finally {
        Revoke-PostingToken $identity
    }
}

function Remove-StartReaction($Config, $Info, $ReactionId) {
    if (-not $ReactionId) { return }
    $identity = $null
    try {
        $identity = Get-PostingToken $Config $Info.repo
        Invoke-GhWrite 'DELETE' "repos/$($Info.repo)/issues/$($Info.number)/reactions/$ReactionId" $null $identity | Out-Null
    } catch {
        Write-Warning "Couldn't remove the eyes reaction: $($_.Exception.Message)"
    } finally {
        Revoke-PostingToken $identity
    }
}

function Add-JsonLine([string] $Path, $Entry) {
    if (-not (Test-Path (Split-Path $Path))) { New-Item -ItemType Directory (Split-Path $Path) | Out-Null }
    [IO.File]::AppendAllText($Path, ($Entry | ConvertTo-Json -Depth 10 -Compress) + "`n", $Utf8NoBom)
}

# One line per posted inline comment, so -Outcomes can check later whether it was resolved, the code
# changed under it, or it got a reply. A failure here never fails the post.
function Write-PostedComments($Draft, $Review, $Comments) {
    try {
        # ForEach-Object unrolls the array: Windows PowerShell 5.1's ConvertFrom-Json emits it as one object.
        $posted = @(Invoke-Native 'gh' @('api', "repos/$($Draft.repo)/pulls/$($Draft.number)/reviews/$($Review.id)/comments?per_page=100") |
            ConvertFrom-Json | ForEach-Object { $_ })
        foreach ($p in $posted) {
            $source = $Comments | Where-Object { $_.path -eq $p.path -and $_.body -eq $p.body } | Select-Object -First 1
            Add-JsonLine (Join-Path $LogDir 'comments.jsonl') ([ordered]@{
                at = (Get-Date).ToString('o'); repo = $Draft.repo; number = $Draft.number; head_sha = $Draft.head_sha
                review_id = $Review.id; comment_id = $p.id; path = $p.path
                line = if ($source) { $source.line } else { $null }
                category = if ($source) { $source.category } else { $null }
                severity = if ($source) { $source.severity } else { $null }
            })
        }
    } catch {
        Write-Warning "Posted, but couldn't log the comments for -Outcomes: $($_.Exception.Message)"
    }
}

function Get-DraftField($Draft, [string] $Name, $Default) {
    if ($Draft.PSObject.Properties[$Name]) { return $Draft.$Name }
    return $Default
}

# Whether the draft has a review to post: always for a full review. A follow-up needs a summary or an
# inline comment, since GitHub rejects a review with neither. Its minor list can post on its own.
function Test-ReviewContent($Draft) {
    $review = $Draft.review
    if ((Get-DraftField $Draft 'mode' 'full') -eq 'full') { return $true }
    return @($review.comments).Count -gt 0 -or [bool] ([string] $review.summary).Trim()
}

# Whether the draft has anything besides thread replies to post.
function Test-ReviewWanted($Draft) {
    return (Test-ReviewContent $Draft) -or [bool] (Format-MinorNotes $Draft.review)
}

# A thread answer's reaction, or '' for none. Older drafts have no reaction field.
function Get-ReplyReaction($Reply) {
    if (-not $Reply.PSObject.Properties['reaction']) { return '' }
    $reaction = [string] $Reply.reaction
    if (@('+1', 'hooray', 'heart') -contains $reaction) { return $reaction }
    return ''
}

# Thread answers with something to post: a reply, a reaction, or both.
function Get-ThreadReplies($Review) {
    if (-not $Review.PSObject.Properties['thread_replies']) { return @() }
    return @($Review.thread_replies | Where-Object { $_ -and (([string] $_.body).Trim() -or (Get-ReplyReaction $_)) })
}

# Posts what a draft holds and hasn't posted yet: the review, then the minor list, then thread replies.
# Each part is saved to the draft as soon as it posts, so a rerun never posts anything twice.
function Publish-Draft($Config, [string] $DraftPath, [switch] $AllowNewerHead) {
    $draft = Read-Utf8 $DraftPath | ConvertFrom-Json
    foreach ($field in @('posted_minor_url', 'codex_review', 'posted_replies', 'posted_reactions', 'mode')) {
        if (-not $draft.PSObject.Properties[$field]) { $draft | Add-Member -NotePropertyName $field -NotePropertyValue $null }
    }
    if (-not $draft.mode) { $draft.mode = 'full' }
    if (-not $draft.posted_replies) { $draft.posted_replies = [pscustomobject]@{} }
    if (-not $draft.posted_reactions) { $draft.posted_reactions = [pscustomobject]@{} }
    $review = $draft.review
    $minorBody = Format-MinorNotes $review
    $replyLeft = { param($r) ([string] $r.body).Trim() -and -not $draft.posted_replies.PSObject.Properties[[string] $r.comment_id] }
    $reactionLeft = { param($r) (Get-ReplyReaction $r) -and -not $draft.posted_reactions.PSObject.Properties[[string] $r.comment_id] }
    $replies = @(Get-ThreadReplies $review | Where-Object { (& $replyLeft $_) -or (& $reactionLeft $_) })
    # Answers only ever go to Sam's own threads, whatever the draft says. A reaction goes on the latest
    # comment in the thread that isn't Sam's: the author's reply.
    $reactTo = @{}
    if ($replies.Count) {
        $samThreads = @(Get-ReviewThreads ([pscustomobject]@{ repo = $draft.repo; number = $draft.number }) | Where-Object { Test-SamThread $_ })
        $samIds = @(foreach ($t in $samThreads) {
            $first = [long] @($t.comments.nodes)[0].databaseId
            $latest = @($t.comments.nodes | Where-Object { (Get-CommentAuthor $_) -ne (Get-SamLogin) }) | Select-Object -Last 1
            if ($latest) { $reactTo[$first] = [long] $latest.databaseId }
            $first
        })
        foreach ($r in @($replies | Where-Object { $samIds -notcontains [long] $_.comment_id })) {
            Write-Warning "Skipping an answer to comment $($r.comment_id): it isn't one of Sam's threads."
        }
        $replies = @($replies | Where-Object { $samIds -contains [long] $_.comment_id })
    }
    $reviewLeft = (Test-ReviewContent $draft) -and -not $draft.posted_url
    $minorLeft = $minorBody -and -not $draft.posted_minor_url
    if (-not $reviewLeft -and -not $minorLeft -and $replies.Count -eq 0) {
        if ($draft.posted_url) { throw "Already posted: $($draft.posted_url)" }
        throw 'Nothing to post: no new comments and no thread replies in this draft.'
    }

    $current = (Get-PrInfo $draft.url).headRefOid
    # A rerun for what's left after the review posted skips this: the review it belongs to is already up.
    if ($current -ne $draft.head_sha -and -not $AllowNewerHead -and -not $draft.posted_url) {
        throw "The PR has new commits since this draft ($($draft.head_sha.Substring(0, 7)) -> $($current.Substring(0, 7))). Re-run Sam, or post anyway with -Force."
    }

    $reviewEvent = 'COMMENT'
    if ($review.verdict -eq 'needs_changes' -and $Config.allowRequestChanges) { $reviewEvent = 'REQUEST_CHANGES' }
    $body = [string] $review.summary
    if ($Config.footer) { $body += "`n`n" + $Config.footer }

    # GitHub only takes inline comments on lines in the diff. Anything else goes in the body, still
    # pointing at its line.
    $diffLines = $null
    if ($reviewLeft -and @($review.comments).Count) {
        try {
            $diffLines = Get-DiffLines $draft.repo $draft.number
        } catch {
            Write-Warning "Couldn't read the PR's diff to check comment lines, so posting them as they are: $($_.Exception.Message)"
        }
    }
    $comments = New-Object System.Collections.Generic.List[object]
    $meta = New-Object System.Collections.Generic.List[object]
    $outside = New-Object System.Collections.Generic.List[string]
    foreach ($c in @($review.comments)) {
        $side = 'RIGHT'
        if ($c.PSObject.Properties['side'] -and $c.side) { $side = $c.side }
        $text = (Get-CommentTag $c) + $c.body
        $comment = [ordered]@{ path = $c.path; line = [int] $c.line; side = $side; body = $text }
        $start = if ($c.PSObject.Properties['start_line'] -and $c.start_line -and [int] $c.start_line -lt [int] $c.line) { [int] $c.start_line } else { 0 }
        if ($start -and (Test-InDiff $diffLines $c.path $start $side)) {
            $comment.start_line = $start
            $comment.start_side = $side
        }
        if (Test-InDiff $diffLines $c.path ([int] $c.line) $side) {
            $comments.Add($comment)
            $meta.Add([pscustomobject]@{ path = $c.path; line = [int] $c.line; body = $text; category = $c.category
                severity = if ($c.PSObject.Properties['severity']) { $c.severity } else { $null } })
        } else {
            $outside.Add("``$($c.path):$($c.line)`` $text")
        }
    }
    if ($outside.Count) {
        Write-Warning "$($outside.Count) comment(s) point at lines outside the diff, so they go in the review body."
        $body += "`n`n" + ($outside -join "`n`n")
    }

    $payload = [ordered]@{ commit_id = $draft.head_sha; body = $body; event = $reviewEvent; comments = $comments.ToArray() }
    Assert-NoKey $Config $payload
    if ($minorBody) { Assert-NoKey $Config ([ordered]@{ body = $minorBody; comments = @() }) }
    foreach ($r in $replies) { Assert-NoKey $Config ([ordered]@{ body = $r.body; comments = @() }) }

    $identity = Get-PostingToken $Config $draft.repo
    try {
        $who = if ($identity) { $identity.Login } else { Invoke-Native 'gh' @('api', 'user', '--jq', '.login') }
        if ($reviewLeft) {
            Write-Host "Posting a $reviewEvent review on $($draft.url) as $who"
            try {
                $posted = Send-Review $draft.repo $draft.number $payload $identity
            } catch {
                # Only a 422 means GitHub rejected the review. On anything else the review may have been
                # created, and retrying would post it twice.
                if ($comments.Count -eq 0 -or $_.Exception.Message -notmatch 'HTTP 422') { throw }
                Write-Warning "Inline comments were rejected ($($_.Exception.Message)). Posting them in the review body."
                $folded = ($comments | ForEach-Object { "``$($_.path):$($_.line)`` $($_.body)" }) -join "`n`n"
                $payload.body = $body + "`n`n" + $folded
                $payload.comments = @()
                Assert-NoKey $Config $payload
                $posted = Send-Review $draft.repo $draft.number $payload $identity
                $meta.Clear()
            }
            # Saved before anything else posts, so a later failure can't lead to the review posting twice.
            $draft.posted_url = $posted.html_url
            Write-Utf8 $DraftPath ($draft | ConvertTo-Json -Depth 20)
            if ($meta.Count) { Write-PostedComments $draft $posted $meta.ToArray() }
        }
        if ($minorLeft) {
            try {
                $draft.posted_minor_url = Send-PrComment $draft.repo $draft.number $minorBody $identity
            } catch {
                $done = if ($draft.posted_url) { "The review posted ($($draft.posted_url)), but the" } else { 'The' }
                throw "$done minor list didn't post: $($_.Exception.Message) Run -PostDraft again to post what's left."
            }
            Write-Utf8 $DraftPath ($draft | ConvertTo-Json -Depth 20)
        }
        foreach ($r in $replies) {
            $id = [string] $r.comment_id
            if (& $replyLeft $r) {
                Write-Host "Replying in Sam's thread $id"
                $url = Send-ThreadReply $draft.repo $draft.number ([long] $r.comment_id) $r.body $identity
                $draft.posted_replies | Add-Member -NotePropertyName $id -NotePropertyValue $url
                Write-Utf8 $DraftPath ($draft | ConvertTo-Json -Depth 20)
            }
            if (& $reactionLeft $r) {
                $reaction = Get-ReplyReaction $r
                $target = $reactTo[[long] $r.comment_id]
                $done = if ($target) {
                    # GitHub returns the existing reaction instead of adding a second, so a rerun is safe.
                    Write-Host "Reacting $reaction in Sam's thread $id"
                    Invoke-GhWrite 'POST' "repos/$($draft.repo)/pulls/comments/$target/reactions" ([ordered]@{ content = $reaction }) $identity | Out-Null
                    "$reaction on $target"
                } else {
                    Write-Warning "No reply from anyone else in Sam's thread $id to react to; skipping the reaction."
                    'skipped'
                }
                $draft.posted_reactions | Add-Member -NotePropertyName $id -NotePropertyValue $done
                Write-Utf8 $DraftPath ($draft | ConvertTo-Json -Depth 20)
            }
        }
    } finally {
        Revoke-PostingToken $identity
    }
    return $draft
}

function Test-AnythingPosted($Draft) {
    return [bool] ((Get-DraftField $Draft 'posted_url' $null) -or (Get-DraftField $Draft 'posted_minor_url' $null) -or
        ((Get-DraftField $Draft 'posted_replies' $null) -and @($Draft.posted_replies.PSObject.Properties).Count) -or
        ((Get-DraftField $Draft 'posted_reactions' $null) -and @($Draft.posted_reactions.PSObject.Properties).Count))
}

# After a post, even a partial one: the commit Sam has now covered, for the next follow-up. That's the
# draft's commit once its review is up, or right away for a follow-up with no review to post. A
# replies-only run covers no new code, so it leaves reviewed_sha alone.
function Update-PrRecord([hashtable] $State, $Draft) {
    $record = Get-PrRecord $State $Draft.url
    $mode = Get-DraftField $Draft 'mode' 'full'
    if ($mode -ne 'replies' -and ($Draft.posted_url -or -not (Test-ReviewContent $Draft))) { $record.reviewed_sha = $Draft.head_sha }
    if ($Draft.posted_url) { $record.review_url = $Draft.posted_url }
    $record.closed = $false
    $State["pr:$($Draft.url)"] = $record
}

# ---------------------------------------------------------------- one PR

# True when $Old is in $New's history. Fetches $Old first if this clone hasn't seen it.
function Test-Ancestor([string] $Clone, [string] $Old, [string] $New) {
    $ErrorActionPreference = 'Continue'
    & git -C $Clone cat-file -e "$Old^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { & git -C $Clone fetch -q origin $Old 2>$null }
    & git -C $Clone merge-base --is-ancestor $Old $New 2>$null
    return $LASTEXITCODE -eq 0
}

# What a PR needs now, decided before anything is cloned:
#   full      Sam's first review of it, or a redo of a commit with -Force
#   followup  new commits since Sam's posted review; Complete-Plan narrows it once there's a clone
#   replies   someone answered in one of Sam's threads, and there's no new code to review
#   none      nothing to do
# -RepliesOnly is for a PR that no longer requests your review: Sam still answers in its threads
# there, but doesn't review new commits until it's requested again.
function New-ReviewPlan($Config, [hashtable] $State, $Info, [switch] $RepliesOnly) {
    $record = Get-PrRecord $State $Info.url
    $headDone = $State.ContainsKey("$($Info.url)@$($Info.headRefOid)") -or $record.reviewed_sha -eq $Info.headRefOid
    $plan = [pscustomobject]@{ Mode = 'full'; ReviewedSha = $null; DiffBase = $null; Files = @(); Pending = @(); Threads = $null
        ChangedLines = [int] $Info.additions + [int] $Info.deletions; Tier = $null }
    if ($Config.followUps -and $record.reviewed_sha) {
        try {
            $plan.Threads = @(Get-ReviewThreads $Info)
            $plan.Pending = @(Get-PendingThreads $plan.Threads $record.handled)
        } catch {
            Write-Warning "Couldn't read the review threads on $($Info.url): $($_.Exception.Message)"
        }
    }
    $canFollow = $Config.followUps -and $record.reviewed_sha
    if ($Force -and $headDone -and -not $RepliesOnly) {
        # A redo of the same commit is a full review.
    } elseif ($headDone -or $RepliesOnly) {
        $plan.Mode = if ($plan.Pending.Count) { 'replies' } else { 'none' }
    } elseif ($canFollow) {
        $plan.Mode = 'followup'
    }
    if ($plan.Mode -ne 'full') { $plan.ReviewedSha = $record.reviewed_sha }
    if ($plan.Mode -eq 'replies') { $plan.ChangedLines = 0 }
    $plan.Tier = Select-Tier $Config $plan.ChangedLines
    return $plan
}

# What a follow-up diffs against. Normally Sam's reviewed commit. If the author merged the base branch
# in since then, that diff would include everyone else's changes, so it's a commit made locally from
# Sam's reviewed commit with the new base merged in: diffing it against the head shows only the
# author's changes. $null if that merge conflicts, and the follow-up becomes a full review.
function Get-FollowupBase([string] $Clone, [string] $Prev, $Info) {
    if (Test-Ancestor $Clone $Info.mergeBase $Prev) { return $Prev }
    try {
        $tree = @((Invoke-Native 'git' @('-C', $Clone, 'merge-tree', '--write-tree', $Prev, $Info.mergeBase)) -split "`n")[0].Trim()
        return (Invoke-Native 'git' @('-C', $Clone, '-c', 'user.name=Sam', '-c', 'user.email=sam@localhost', 'commit-tree', $tree,
            '-p', $Prev, '-p', $Info.mergeBase, '-m', "Sam's reviewed commit with $($Info.baseRefName) merged in")).Trim()
    } catch {
        Write-Warning "The base branch was merged in since Sam's review, and Sam couldn't separate the author's changes from it ($($_.Exception.Message)), so this is a full review."
        return $null
    }
}

# Narrows a follow-up to the new commits, once there's a clone. If Sam's reviewed commit is no longer
# in the branch (a force push), it's a full review again. New commits that touch none of the PR's files,
# such as a merge from the base branch, leave only replies, or nothing.
function Complete-Plan($Config, $Plan, $Info, [string] $Clone) {
    if ($Plan.Mode -ne 'followup') { return }
    $prev = $Plan.ReviewedSha
    if (-not (Test-Ancestor $Clone $prev $Info.headRefOid)) {
        Write-Warning "Sam's last reviewed commit $($prev.Substring(0, 7)) isn't in the branch any more (force push?), so this is a full review."
        $Plan.Mode = 'full'
        $Plan.ReviewedSha = $null
        $Plan.ChangedLines = [int] $Info.additions + [int] $Info.deletions
        $Plan.Tier = Select-Tier $Config $Plan.ChangedLines
        return
    }
    $base = Get-FollowupBase $Clone $prev $Info
    if (-not $base) {
        $Plan.Mode = 'full'
        $Plan.ReviewedSha = $null
        $Plan.ChangedLines = [int] $Info.additions + [int] $Info.deletions
    } else {
        $Plan | Add-Member -Force -NotePropertyName DiffBase -NotePropertyValue $base
        $names = { param($From) @((Invoke-Native 'git' @('-C', $Clone, '-c', 'core.quotepath=off', 'diff', '--name-only', $From, $Info.headRefOid)) -split "`n" | Where-Object { $_ }) }
        $prFiles = & $names $Info.mergeBase
        $Plan.Files = @(& $names $base | Where-Object { $prFiles -contains $_ })
        $Plan.ChangedLines = 0
        if ($Plan.Files.Count) {
            $numstat = Invoke-Native 'git' (@('-C', $Clone, '-c', 'core.quotepath=off', 'diff', '--numstat', $base, $Info.headRefOid, '--') + $Plan.Files)
            foreach ($row in ($numstat -split "`n")) {
                if ($row -match '^(\d+)\t(\d+)\t') { $Plan.ChangedLines += [int] $Matches[1] + [int] $Matches[2] }
            }
        } else {
            $Plan.Mode = if ($Plan.Pending.Count) { 'replies' } else { 'none' }
        }
    }
    $Plan.Tier = Select-Tier $Config $Plan.ChangedLines
}

# One line per run in .work\logs\runs.jsonl, plus a line in the console: time, cost, what ran. Never posted.
function Write-RunLog($Run, [datetime] $Started) {
    $Run.minutes = [Math]::Round(((Get-Date) - $Started).TotalMinutes, 1)
    if ($null -ne $Run.first_pass_usd) { $Run.cost_usd = [Math]::Round([double] $Run.first_pass_usd + [double] $Run.second_pass_usd, 2) }
    try {
        Add-JsonLine (Join-Path $LogDir 'runs.jsonl') $Run
    } catch {
        Write-Warning "Couldn't write the run log: $($_.Exception.Message)"
    }
    $cost = if ($null -ne $Run.cost_usd) { '${0}' -f $Run.cost_usd } else { 'no model cost' }
    if ($Run.second_pass_usd) { $cost += ' (second pass ${0})' -f [Math]::Round([double] $Run.second_pass_usd, 2) }
    $review = if ($Run.review_skill) { ", $($Run.review_skill)" } else { '' }
    Write-Host "Run:      $($Run.minutes) min, $cost, $($Run.mode)$review, Codex $($Run.codex)"
}

function Invoke-PrReview($Config, [hashtable] $State, [string] $Url, [switch] $Manual, [switch] $RepliesOnly) {
    $info = Get-PrInfo $Url
    $sha7 = $info.headRefOid.Substring(0, 7)
    $key = "$($info.url)@$($info.headRefOid)"
    $recordKey = "pr:$($info.url)"
    $record = Get-PrRecord $State $info.url

    if ($info.state -ne 'OPEN') {
        # A closed PR stops being watched for replies.
        if ($record.reviewed_sha -and -not $record.closed -and -not $PromptOnly) {
            $record.closed = $true
            $State[$recordKey] = $record
            Save-State $State
        }
        $message = "Skip $Url (the PR is $($info.state.ToLowerInvariant()))"
        if ($Manual) { Write-Host $message } else { Write-Verbose $message }
        return
    }
    if (-not $Manual) {
        if (-not (Get-RepoConfig $Config $info.repo)) { Write-Verbose "Skip $Url (repo not in config.repos)"; return }
        if ($info.isDraft -and $Config.skipDraftPrs) { Write-Verbose "Skip $Url (draft PR)"; return }
    }

    if ($PromptOnly) {
        $info | Add-Member -NotePropertyName mergeBase -NotePropertyValue (Get-MergeBase $info)
        $lines = [int] $info.additions + [int] $info.deletions
        $plan = [pscustomobject]@{ Mode = 'full'; ChangedLines = $lines; Tier = Select-Tier $Config $lines }
        Write-Output (New-SamPrompt $Config $info '<worktree>' '<run dir>' $plan $null)
        return
    }

    $plan = New-ReviewPlan $Config $State $info -RepliesOnly:$RepliesOnly
    if ($plan.Mode -eq 'none') {
        $status = if ($State.ContainsKey($key)) { $State[$key].status } else { 'reviewed' }
        $message = if ($RepliesOnly) { "Skip $Url (no new replies in Sam's threads)" } else { "Skip $Url (already $status at $sha7; -Force to redo)" }
        if ($Manual) { Write-Host $message } else { Write-Verbose $message }
        return
    }

    # Before anything is cloned, reacted to or handed to Codex, and outside the try below, so a .pem
    # skips this PR without marking its commit failed. Invoke-Sam checks again before each session.
    Assert-NoPlainKey

    $started = Get-Date
    $run = [ordered]@{ at = $started.ToString('o'); repo = $info.repo; number = $info.number; head_sha = $info.headRefOid
        mode = $plan.Mode; changed_lines = $null; review_skill = $null; codex = 'off'; minutes = $null; cost_usd = $null
        first_pass_usd = $null; second_pass_usd = $null; verdict = $null; comments = 0; minor_notes = 0
        extra_minor_notes = 0; thread_replies = 0; draft = $null; posted = $false; error = $null }
    $entry = $null
    $clone = $null
    $worktree = $null
    $codexWorktree = $null
    $codex = $null
    $reaction = $null
    try {
        $clone = Get-ClonePath $Config $info.repo
        Sync-PrRefs $clone $info
        $info | Add-Member -NotePropertyName mergeBase -NotePropertyValue (Get-MergeBase $info $clone)
        Complete-Plan $Config $plan $info $clone
        $run.mode = $plan.Mode
        if ($plan.Mode -eq 'none') {
            # Nothing Sam reviewed changed, so the new head counts as covered.
            Write-Host "Nothing to review on $Url at ${sha7}: the new commits don't touch the PR's files, and no one is waiting on Sam."
            $record.reviewed_sha = $info.headRefOid
            $State[$recordKey] = $record
            $State[$key] = @{ status = 'no_new_changes'; at = (Get-Date).ToString('o') }
            return
        }
        if ($plan.Mode -ne 'replies') {
            $run.changed_lines = $plan.ChangedLines
            $run.review_skill = Get-TierLabel $plan.Tier
        }
        $what = switch ($plan.Mode) {
            'followup' { "follow-up on $($plan.ChangedLines) changed lines since $($plan.ReviewedSha.Substring(0, 7)), $(Get-TierLabel $plan.Tier)" }
            'replies' { "replies in Sam's threads" }
            default { "$($plan.ChangedLines) changed lines, $(Get-TierLabel $plan.Tier)" }
        }
        Write-Host "Sam is on $($info.url) at ${sha7}: $what..."
        $reaction = Add-StartReaction $Config $info
        $worktree = New-Worktree $clone $info

        $codexBase = if ($plan.Mode -eq 'followup') { Get-DiffBase $plan } else { $info.mergeBase }
        # After a base-branch merge, the follow-up's base is a local commit outside the branch's history,
        # and Codex would review from the merge base, base-branch changes included. Sam goes alone.
        $baseMerged = $plan.Mode -eq 'followup' -and $codexBase -ne $plan.ReviewedSha
        if ($baseMerged -and $Config.codexReview.enabled) { $run.codex = 'skipped_base_merge' }
        if ($Config.codexReview.enabled -and $plan.Mode -ne 'replies' -and -not $baseMerged) {
            # Codex is optional, so a problem starting it never stops Sam's review.
            try {
                $codexWorktree = New-Worktree $clone $info '-codex'
                $codex = Start-CodexReview $Config $info $codexWorktree $codexBase
            } catch {
                Write-Warning "Couldn't start Codex, so Sam reviews without it: $($_.Exception.Message)"
                Stop-CodexReview $codex
                $codex = $null
                $codexWorktree = $null
                Remove-Worktree $clone (Join-Path $WorkDir ('wt\' + ($info.repo -replace '/', '-') + "-$($info.number)-codex"))
            }
        }
        # The replies handed to Sam count as handled now, even if the run fails, so one reply can't set
        # off a run every poll. A full review doesn't answer replies, so they stay pending for the next
        # poll's replies run.
        if ($plan.Pending.Count -and $plan.Mode -ne 'full') {
            $record.handled = @($record.handled) + @($plan.Pending | ForEach-Object { [long] @($_.comments.nodes)[-1].databaseId })
            $State[$recordKey] = $record
        }

        $runDir = New-RunDir $Config $info
        $prompt = if ($plan.Mode -eq 'full') { New-SamPrompt $Config $info $worktree $runDir $plan $plan.Threads }
            else { New-FollowupPrompt $Config $info $worktree $runDir $plan $plan.Threads }
        $result = Invoke-Sam $Config $prompt $worktree $runDir
        $run.first_pass_usd = [double] $result.total_cost_usd
        $codexResult = Wait-CodexReview $Config $codex
        if ($codexResult.Status -ne 'off') { $run.codex = $codexResult.Status }
        $codexReview = $codexResult.Text
        if ($codexReview) {
            Write-Host "Sam's second pass, with Codex's findings..."
            try {
                $second = Invoke-Sam $Config (New-CodexFollowup $codexBase $codexReview) $worktree $runDir $result.session_id
                $run.second_pass_usd = [double] $second.total_cost_usd
                $second.total_cost_usd = [double] $second.total_cost_usd + [double] $result.total_cost_usd
                $result = $second
            } catch {
                # The first pass is a complete review; keep it rather than lose it.
                Write-Warning "The second pass failed, so the draft is Sam's first pass: $($_.Exception.Message)"
                $run.codex = 'second_pass_failed'
                $codexReview = $null
            }
        }
        $draftPath = Save-Draft $info $result $codexReview $plan
        $review = $result.structured_output
        $replies = @(Get-ThreadReplies $review)
        $extras = @(Get-ExtraNotes $review)
        $run.draft = $draftPath
        $run.verdict = $review.verdict
        $run.comments = @($review.comments).Count
        $run.minor_notes = @($review.minor_notes).Count
        $run.extra_minor_notes = $extras.Count
        $run.thread_replies = $replies.Count
        # A replies-only run doesn't cover the head, so it leaves the commit's entry as it was.
        if ($plan.Mode -ne 'replies') {
            $entry = @{ status = 'drafted'; draft = $draftPath; at = (Get-Date).ToString('o') }
            $State[$key] = $entry
        }

        Write-Host ''
        Write-Host "Verdict:  $($review.verdict), $($run.comments) inline comment(s), $($run.minor_notes) minor note(s), $($replies.Count) thread reply(ies)"
        if ($extras.Count) {
            Write-Host "More minor notes, not posted:"
            foreach ($b in (Format-NoteBullets $extras)) { Write-Host "  $b" }
        }
        Write-Host "Draft:    $($draftPath -replace '\.json$', '.md')"
        if ($Post) {
            $draft = Read-Utf8 $draftPath | ConvertFrom-Json
            try {
                if (-not (Test-ReviewWanted $draft) -and $replies.Count -eq 0) {
                    Write-Host 'Posted:   nothing, since there are no new findings or replies.'
                    if ($entry) { $entry.status = 'nothing_to_post' }
                } else {
                    $draft = Publish-Draft $Config $draftPath
                    $run.posted = $true
                    if ($entry) { $entry.status = 'posted' }
                    if ($draft.posted_url) { Write-Host "Posted:   $($draft.posted_url)" }
                    if ($replies.Count) { Write-Host "Answered: $(@($draft.posted_replies.PSObject.Properties).Count) reply(ies), $(@($draft.posted_reactions.PSObject.Properties).Count) reaction(s)" }
                }
                Update-PrRecord $State $draft
            } catch {
                # The review itself worked; keep the draft path so it can be posted with -PostDraft. Record
                # whatever did post, so the next push gets a follow-up rather than a second full review.
                $partial = Read-Utf8 $draftPath | ConvertFrom-Json
                if (Test-AnythingPosted $partial) { Update-PrRecord $State $partial }
                if ($entry) { $entry.status = 'post_failed'; $entry.error = $_.Exception.Message }
                $run.error = "post: $($_.Exception.Message)"
                Write-Warning "Draft saved but posting failed: $($_.Exception.Message)"
            }
        } else {
            Write-Host "Post it:  .\sam.ps1 -PostDraft `"$draftPath`""
        }
    } catch {
        $run.error = $_.Exception.Message
        if ($plan.Mode -ne 'replies') { $State[$key] = @{ status = 'failed'; error = $_.Exception.Message; at = (Get-Date).ToString('o') } }
        Write-Warning "Review of $Url failed: $($_.Exception.Message)"
    } finally {
        # Codex is still running only if Sam's session failed; it holds files in its worktree.
        Stop-CodexReview $codex
        Remove-StartReaction $Config $info $reaction
        Save-State $State
        if ($codexWorktree) { Remove-Worktree $clone $codexWorktree }
        if ($worktree -and -not $Config.keepWorktree) { Remove-Worktree $clone $worktree }
        if ($run.mode -ne 'none') { Write-RunLog $run $started }
    }
}

# Reviews what requests your review. PRs Sam has posted on stay watched until they close, but only
# for replies in Sam's threads: new commits there get a follow-up when your review is requested again.
function Invoke-Poll($Config) {
    $state = Get-State
    $urls = @(Get-RequestedPrUrls $Config)
    Write-Verbose "$($urls.Count) open PR(s) request your review"
    foreach ($url in $urls) {
        try {
            Invoke-PrReview $Config $state $url
        } catch {
            Write-Warning "Checking $url failed: $($_.Exception.Message)"
        }
    }
    if (-not $Config.followUps) { return }
    foreach ($name in @($state.Keys | Where-Object { $_ -like 'pr:*' })) {
        $url = $name.Substring(3)
        $record = Get-PrRecord $state $url
        if (-not $record.reviewed_sha -or $record.closed -or $urls -contains $url) { continue }
        try {
            Invoke-PrReview $Config $state $url -RepliesOnly
        } catch {
            Write-Warning "Checking $url for replies failed: $($_.Exception.Message)"
        }
    }
}

# ---------------------------------------------------------------- outcomes

# How Sam's posted inline comments fared, by category, from the private comment log and each PR's
# threads now. Each comment counts once, under the first that applies: resolved, code changed under it
# (GitHub marks the thread outdated), replied to by someone else, or no response yet. Gone means the
# thread was deleted.
function Show-Outcomes {
    $log = Join-Path $LogDir 'comments.jsonl'
    if (-not (Test-Path $log)) { Write-Host 'No posted comments logged yet. Sam logs them when it posts.'; return }
    $entries = @(Get-Content -LiteralPath $log -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
    $kinds = @('resolved', 'code changed', 'replied', 'no response', 'gone')
    $counts = [ordered]@{}
    $prs = 0
    foreach ($group in ($entries | Group-Object { "$($_.repo)#$($_.number)" })) {
        $first = $group.Group[0]
        try {
            $threads = @(Get-ReviewThreads ([pscustomobject]@{ repo = $first.repo; number = $first.number }))
        } catch {
            Write-Warning "Couldn't read the threads on $($group.Name): $($_.Exception.Message)"
            continue
        }
        $prs++
        $byId = @{}
        foreach ($t in $threads) {
            $c = @($t.comments.nodes)[0]
            if ($c) { $byId[[long] $c.databaseId] = $t }
        }
        foreach ($e in $group.Group) {
            $t = $byId[[long] $e.comment_id]
            $outcome = if (-not $t) { 'gone' }
                elseif ($t.isResolved) { 'resolved' }
                elseif ($t.isOutdated) { 'code changed' }
                elseif (@(@($t.comments.nodes) | Select-Object -Skip 1 | Where-Object { (Get-CommentAuthor $_) -ne (Get-SamLogin) }).Count) { 'replied' }
                else { 'no response' }
            $category = if ($e.category) { [string] $e.category } else { 'unknown' }
            if (-not $counts.Contains($category)) {
                $counts[$category] = [ordered]@{}
                foreach ($o in $kinds) { $counts[$category][$o] = 0 }
            }
            $counts[$category][$outcome]++
        }
    }
    $order = @('blocking', 'needs_decision', 'optional') + @($counts.Keys | Where-Object { @('blocking', 'needs_decision', 'optional') -notcontains $_ })
    $rows = foreach ($category in $order) {
        if (-not $counts.Contains($category)) { continue }
        $c = $counts[$category]
        $total = 0
        foreach ($o in $kinds) { $total += $c[$o] }
        [pscustomobject][ordered]@{ Category = $category; Posted = $total; Resolved = $c['resolved']; 'Code changed' = $c['code changed']
            Replied = $c['replied']; 'No response' = $c['no response']; Gone = $c['gone'] }
    }
    Write-Host "Sam's inline comments on $prs PR(s), as they stand now:"
    $rows | Format-Table -AutoSize | Out-String | Write-Host
}

# ---------------------------------------------------------------- main

if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory $WorkDir | Out-Null }
$config = Get-Config

if ($PSCmdlet.ParameterSetName -eq 'ImportKey') {
    Import-AppKey $config (Resolve-Path $ImportKey).Path
    return
}

# One run at a time, so a scheduled poll can't overlap a long review, and -PostDraft can't overwrite
# state.json while a review is writing it. -Loop holds the lock only while it polls, not while it sleeps.
function Enter-SamLock {
    if (Test-Path $LockPath) {
        $holder = (Read-Utf8 $LockPath).Trim()
        if ($holder -and $holder -ne [string] $PID -and (Get-Process -Id ([int] $holder) -ErrorAction SilentlyContinue)) { return $holder }
    }
    Write-Utf8 $LockPath ([string] $PID)
    return $null
}

function Exit-SamLock {
    if ((Test-Path $LockPath) -and (Read-Utf8 $LockPath).Trim() -eq [string] $PID) { Remove-Item $LockPath -ErrorAction SilentlyContinue }
}

if ($PSCmdlet.ParameterSetName -eq 'PostDraft') {
    $holder = Enter-SamLock
    if ($holder) { throw "Sam is reviewing right now (PID $holder). Post the draft once that run finishes." }
    try {
        $draftPath = (Resolve-Path $PostDraft).Path
        # What the draft had posted before this run. Only something new moves the PR's record, so
        # re-posting an old draft can't rewind it.
        $postedSoFar = { param($d) '{0}|{1}|{2}|{3}' -f (Get-DraftField $d 'posted_url' ''), (Get-DraftField $d 'posted_minor_url' ''),
            $(if (Get-DraftField $d 'posted_replies' $null) { @($d.posted_replies.PSObject.Properties).Count } else { 0 }),
            $(if (Get-DraftField $d 'posted_reactions' $null) { @($d.posted_reactions.PSObject.Properties).Count } else { 0 }) }
        $before = & $postedSoFar (Read-Utf8 $draftPath | ConvertFrom-Json)
        try {
            $draft = Publish-Draft $config $draftPath -AllowNewerHead:$Force
        } finally {
            # Follow-ups start from what's posted, including a partial post.
            $draft = Read-Utf8 $draftPath | ConvertFrom-Json
            if ((Test-AnythingPosted $draft) -and (& $postedSoFar $draft) -ne $before) {
                $state = Get-State
                Update-PrRecord $state $draft
                $key = "$($draft.url)@$($draft.head_sha)"
                if ($state.ContainsKey($key) -and $draft.posted_url) { $state[$key] = @{ status = 'posted'; draft = $draftPath; at = (Get-Date).ToString('o') } }
                Save-State $state
            }
        }
        if ($draft.posted_url) { Write-Host "Posted:  $($draft.posted_url)" }
        if ($draft.posted_minor_url) { Write-Host "Minor:   $($draft.posted_minor_url)" }
        foreach ($p in @($draft.posted_replies.PSObject.Properties)) { Write-Host "Replied: $($p.Value)" }
        if ($draft.PSObject.Properties['posted_reactions'] -and $draft.posted_reactions) {
            foreach ($p in @($draft.posted_reactions.PSObject.Properties)) { Write-Host "Reacted: $($p.Value) in thread $($p.Name)" }
        }
    } finally {
        Exit-SamLock
    }
    return
}

if ($PSCmdlet.ParameterSetName -eq 'Outcomes') {
    Show-Outcomes
    return
}

if ($PSCmdlet.ParameterSetName -eq 'Pr' -and $PromptOnly) {
    Invoke-PrReview $config @{} $Pr -Manual
    return
}

if ($Loop -and $Force) { throw '-Force with -Loop would redo every review on every poll. Use -Force with -Pr instead.' }

if ($Loop) {
    while ($true) {
        $holder = Enter-SamLock
        if ($holder) {
            Write-Host "Sam is already running (PID $holder). Skipping this poll."
        } else {
            try { Invoke-Poll $config } catch { Write-Warning "Poll failed: $($_.Exception.Message)" } finally { Exit-SamLock }
        }
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    }
}

$holder = Enter-SamLock
if ($holder) {
    Write-Host "Sam is already running (PID $holder). Exiting."
    return
}
try {
    if ($PSCmdlet.ParameterSetName -eq 'Pr') {
        Invoke-PrReview $config (Get-State) $Pr -Manual
    } else {
        Invoke-Poll $config
    }
} finally {
    Exit-SamLock
}
