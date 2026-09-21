[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $SshTarget,
    [Parameter(Mandatory)] [string] $DestinationDirectory,
    [int] $RetentionDays = 30
)

$ErrorActionPreference = 'Stop'
if ($SshTarget -notmatch '^[A-Za-z0-9_.@-]+$') { throw 'Invalid SSH target.' }
if ($RetentionDays -lt 1) { throw 'RetentionDays must be positive.' }

$destination = [System.IO.Path]::GetFullPath($DestinationDirectory)
New-Item -ItemType Directory -Force -Path $destination | Out-Null

$remoteNames = & ssh -o BatchMode=yes -o ConnectTimeout=15 $SshTarget `
    "find smartdesk-ai/backups -maxdepth 1 -type f -name 'smartdesk-*.tar.gz.cms' -printf '%f\n' | sort"
if ($LASTEXITCODE -ne 0) { throw 'Unable to list remote encrypted backups.' }

$copied = 0
foreach ($name in $remoteNames) {
    if ($name -notmatch '^smartdesk-[0-9]{8}T[0-9]{6}Z\.tar\.gz\.cms$') { continue }
    $finalPath = Join-Path $destination $name
    if (Test-Path -LiteralPath $finalPath) { continue }
    $temporaryPath = "$finalPath.partial"
    & scp -q -o BatchMode=yes -o ConnectTimeout=15 "${SshTarget}:smartdesk-ai/backups/$name" $temporaryPath
    if ($LASTEXITCODE -ne 0) { throw "Transfer failed for $name." }
    $remoteHash = (& ssh -o BatchMode=yes $SshTarget "cd smartdesk-ai/backups && sha256sum '$name'" | ForEach-Object { ($_ -split '\s+')[0] })
    $localHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $temporaryPath).Hash.ToLowerInvariant()
    if ($localHash -ne $remoteHash) {
        Remove-Item -LiteralPath $temporaryPath -Force
        throw "Integrity verification failed for $name."
    }
    Move-Item -LiteralPath $temporaryPath -Destination $finalPath
    $copied++
}

$cutoff = (Get-Date).AddDays(-$RetentionDays)
Get-ChildItem -LiteralPath $destination -File -Filter 'smartdesk-*.tar.gz.cms' |
    Where-Object LastWriteTime -LT $cutoff |
    Remove-Item -Force

"offhost_backup_sync=PASS copied=$copied"
