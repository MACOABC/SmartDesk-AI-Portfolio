[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $EncryptedBackup,
    [Parameter(Mandatory)] [string] $OutputPath,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $EncryptedBackup).Path
$destination = [System.IO.Path]::GetFullPath($OutputPath)
if ((Test-Path -LiteralPath $destination) -and -not $Force) {
    throw 'Output already exists. Use -Force only for a known disposable path.'
}

Add-Type -AssemblyName System.Security.Cryptography.Pkcs
$envelope = [System.Security.Cryptography.Pkcs.EnvelopedCms]::new()
$envelope.Decode([System.IO.File]::ReadAllBytes($source))
$envelope.Decrypt()
$content = $envelope.ContentInfo.Content
if ($content.Length -lt 2 -or $content[0] -ne 0x1f -or $content[1] -ne 0x8b) {
    throw 'Decrypted content is not a gzip archive.'
}

[System.IO.File]::WriteAllBytes($destination, $content)
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$acl = [System.Security.AccessControl.FileSecurity]::new()
$acl.SetOwner($identity.User)
$acl.SetAccessRuleProtection($true, $false)
$rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
    $identity.User,
    [System.Security.AccessControl.FileSystemRights]::FullControl,
    [System.Security.AccessControl.AccessControlType]::Allow
)
$acl.AddAccessRule($rule)
Set-Acl -LiteralPath $destination -AclObject $acl

"backup_decryption=PASS file=$(Split-Path $destination -Leaf)"
