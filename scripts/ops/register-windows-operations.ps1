[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $SshTarget,
    [Parameter(Mandatory)] [uri] $MonitorBaseUrl,
    [Parameter(Mandatory)] [string] $BackupDestination
)

$ErrorActionPreference = 'Stop'
if ($SshTarget -notmatch '^[A-Za-z0-9_.@-]+$') { throw 'Invalid SSH target.' }

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pullScript = Join-Path $repositoryRoot 'scripts\ops\pull-offhost-backups.ps1'
$monitorScript = Join-Path $repositoryRoot 'scripts\ops\check-external.ps1'
$pwsh = (Get-Process -Id $PID).Path
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

$backupArguments = "-NoProfile -NonInteractive -File `"$pullScript`" -SshTarget `"$SshTarget`" -DestinationDirectory `"$BackupDestination`" -RetentionDays 30"
$backupAction = New-ScheduledTaskAction -Execute $pwsh -Argument $backupArguments
$backupTrigger = New-ScheduledTaskTrigger -Daily -At '23:00'
Register-ScheduledTask -TaskName 'SmartDesk Off-host Backup Sync' -Action $backupAction `
    -Trigger $backupTrigger -Principal $principal -Settings $settings -Force | Out-Null

$monitorArguments = "-NoProfile -NonInteractive -File `"$monitorScript`" -BaseUrl `"$MonitorBaseUrl`""
$monitorAction = New-ScheduledTaskAction -Execute $pwsh -Argument $monitorArguments
$monitorTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName 'SmartDesk External HTTPS Monitor' -Action $monitorAction `
    -Trigger $monitorTrigger -Principal $principal -Settings $settings -Force | Out-Null

"windows_operations=PASS tasks=2"
