Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Containers = @(
    "webappproxy",
    "nodemanager",
    "resourcemanager"
)

Write-Host "Stopping YARN cluster..." -ForegroundColor Cyan

foreach ($Container in $Containers) {
    $OldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & docker container inspect $Container *> $null
        $Exists = ($LASTEXITCODE -eq 0)
    }
    finally {
        $ErrorActionPreference = $OldPreference
    }

    if ($Exists) {
        & docker stop $Container | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to stop $Container"
        }

        Write-Host "Stopped: $Container"
    }
}

Write-Host ""
Write-Host "YARN cluster stopped." -ForegroundColor Green
