[CmdletBinding()]
param([Parameter(Mandatory)] [uri] $BaseUrl)

$ErrorActionPreference = 'Stop'
$target = [uri]::new($BaseUrl, '/')
try {
    $response = Invoke-WebRequest -Uri $target -Method Get -TimeoutSec 15 -SkipHttpErrorCheck
} catch {
    throw 'external_monitor=FAIL reason=request_error'
}
if ($response.StatusCode -ne 404) {
    throw "external_monitor=FAIL reason=unexpected_status status=$($response.StatusCode)"
}
"external_monitor=PASS status=404"
