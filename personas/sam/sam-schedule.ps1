<#
.SYNOPSIS
  Starts, stops or checks Sam's unattended polling (a Windows scheduled task).

.DESCRIPTION
  While it's on, Windows runs `sam.ps1 -Post` every few minutes, hidden, as you. Each run polls once:
  it reviews PRs that request your review and answers replies in Sam's threads, and posts as set
  by postAs in config.json (Sam's GitHub App, or you). Runs only while you're logged on, since Sam
  needs your gh, claude and DPAPI key. Each day's console output goes to .work\logs\poll-<date>.log.

.EXAMPLE
  .\sam-schedule.ps1 -Start -Until '2026-11-06 20:00'
  Poll every 10 minutes from now until Friday 8 pm (local time).

.EXAMPLE
  .\sam-schedule.ps1 -Status
  Is it on, when it ends, how the last run went, and the end of today's log.

.EXAMPLE
  .\sam-schedule.ps1 -Stop
  No more polls. A review already running finishes and posts.
#>
[CmdletBinding(DefaultParameterSetName = 'Status')]
param(
    [Parameter(ParameterSetName = 'Start', Mandatory)]
    [switch] $Start,

    [Parameter(ParameterSetName = 'Start', Mandatory)]
    [datetime] $Until,

    [Parameter(ParameterSetName = 'Start')]
    [ValidateRange(5, 120)]
    [int] $IntervalMinutes = 10,

    [Parameter(ParameterSetName = 'Stop', Mandatory)]
    [switch] $Stop,

    [Parameter(ParameterSetName = 'Status')]
    [switch] $Status,

    # What the scheduled task runs. Not for use by hand.
    [Parameter(ParameterSetName = 'Run', Mandatory)]
    [switch] $Run
)

$ErrorActionPreference = 'Stop'
$TaskPath = '\Sam\'
# Named after this folder, so two copies of Sam on one PC (one per GitHub organization, say) each get
# their own task instead of replacing each other's.
$FolderHash = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash(
    [Text.Encoding]::UTF8.GetBytes($PSScriptRoot.TrimEnd('\').ToLowerInvariant()))) -replace '-', '').Substring(0, 8)
$TaskName = "Sam PR review poll ($FolderHash)"
$LogDir = Join-Path $PSScriptRoot '.work\logs'

function Get-SamTask { Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue }

switch ($PSCmdlet.ParameterSetName) {
    'Run' {
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force $LogDir | Out-Null }
        Start-Transcript -Append -Path (Join-Path $LogDir ('poll-' + (Get-Date -Format 'yyyy-MM-dd') + '.log')) | Out-Null
        try {
            & (Join-Path $PSScriptRoot 'sam.ps1') -Post -Verbose
        } catch {
            Write-Warning "Poll failed: $($_.Exception.Message)"
        } finally {
            Stop-Transcript | Out-Null
        }
    }
    'Start' {
        if ($Until -le (Get-Date).AddMinutes(1)) { throw "-Until ($Until) has to be in the future." }
        $first = (Get-Date).AddMinutes(1)
        # conhost --headless keeps a console window from flashing up on every poll.
        $arguments = "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Run"
        $action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\conhost.exe" -Argument $arguments -WorkingDirectory $PSScriptRoot
        $trigger = New-ScheduledTaskTrigger -Once -At $first -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration ($Until - $first)
        $trigger.EndBoundary = $Until.ToString('s')
        # One run at a time; a review that runs past two hours is stopped (sam.ps1's lock covers overlaps too).
        $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
            -Description "Sam polls GitHub every $IntervalMinutes minutes and posts reviews (postAs in config.json). Stop with sam-schedule.ps1 -Stop." -Force | Out-Null
        Write-Host "Sam is polling every $IntervalMinutes minutes and posting, as set by postAs in config.json."
        Write-Host "First poll: $($first.ToString('ddd yyyy-MM-dd HH:mm')). Last: before $($Until.ToString('ddd yyyy-MM-dd HH:mm'))."
        Write-Host 'Stop it any time with .\sam-schedule.ps1 -Stop'
    }
    'Stop' {
        if (-not (Get-SamTask)) { Write-Host "Sam isn't scheduled."; return }
        Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false
        Write-Host 'Stopped: no more polls. A review already running finishes and posts.'
    }
    'Status' {
        $task = Get-SamTask
        if (-not $task) { Write-Host "Sam isn't scheduled. Start with .\sam-schedule.ps1 -Start -Until '<date time>'"; return }
        $info = $task | Get-ScheduledTaskInfo
        $end = [datetime] $task.Triggers[0].EndBoundary
        $state = if ($end -lt (Get-Date)) { 'ended' } else { $task.State }
        Write-Host "State:     $state, until $($end.ToString('ddd yyyy-MM-dd HH:mm'))"
        Write-Host "Last run:  $(if ($info.LastRunTime.Year -gt 2000) { $info.LastRunTime.ToString('ddd HH:mm') + ', result ' + $info.LastTaskResult } else { 'not yet' })"
        Write-Host "Next run:  $(if ($info.NextRunTime) { $info.NextRunTime.ToString('ddd HH:mm') } else { 'none' })"
        $log = Join-Path $LogDir ('poll-' + (Get-Date -Format 'yyyy-MM-dd') + '.log')
        if (Test-Path $log) {
            Write-Host "`nEnd of $log`:"
            Get-Content $log -Tail 15 | ForEach-Object { Write-Host "  $_" }
        }
    }
}
