param(
    [string]$TaskName = "GitHub Weekly Trending Sync",
    [string]$Time = "09:15"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$SyncScript = Join-Path $Root "scripts\sync_local.ps1"
$PowerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$Argument = "-NoProfile -ExecutionPolicy Bypass -File `"$SyncScript`""

$Action = New-ScheduledTaskAction -Execute $PowerShell -Argument $Argument -WorkingDirectory $Root
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At $Time
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Description "Pull the latest GitHub weekly trending report into the local workspace." `
    -Force | Out-Null

Write-Host "Registered scheduled task: $TaskName"
Write-Host "Schedule: every Monday at $Time"
