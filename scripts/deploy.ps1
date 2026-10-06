Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Image = "apache/hadoop:3.5.0"
$Network = "yarn-network"

$Containers = @(
    "resourcemanager",
    "nodemanager",
    "webappproxy"
)

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$YarnSite = (Resolve-Path (Join-Path $ProjectRoot "config\yarn-site.xml")).Path

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-DockerSuccess([string[]]$Arguments) {
    $OldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & docker @Arguments *> $null
        $Code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $OldPreference
    }

    return ($Code -eq 0)
}

function Invoke-DockerChecked(
    [string[]]$Arguments,
    [string]$ErrorMessage
) {
    $OldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & docker @Arguments
        $Code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $OldPreference
    }

    if ($Code -ne 0) {
        throw "$ErrorMessage (docker exit code: $Code)"
    }
}

function Remove-ContainerIfExists([string]$Name) {
    if (Test-DockerSuccess @("container", "inspect", $Name)) {
        Write-Host "Removing old container: $Name"
        Invoke-DockerChecked @("rm", "-f", $Name) "Failed to remove container $Name"
    }
}

Write-Step "Checking Docker"
if (-not (Test-DockerSuccess @("version"))) {
    throw "Docker is unavailable. Start Docker Desktop and make sure Linux containers are enabled."
}

Write-Step "Checking Hadoop image"
if (-not (Test-DockerSuccess @("image", "inspect", $Image))) {
    Write-Host "Image not found locally. Pulling $Image ..."
    Invoke-DockerChecked @("pull", $Image) "Failed to pull $Image"
}
else {
    Write-Host "Image already exists locally: $Image"
}

Write-Step "Creating Docker network"
if (-not (Test-DockerSuccess @("network", "inspect", $Network))) {
    Invoke-DockerChecked @("network", "create", $Network) "Failed to create Docker network"
}
else {
    Write-Host "Network already exists: $Network"
}

Write-Step "Removing old YARN containers"
foreach ($Container in $Containers) {
    Remove-ContainerIfExists $Container
}

$ConfigMount = @(
    "--mount",
    "type=bind,source=$YarnSite,target=/opt/hadoop/etc/hadoop/yarn-site.xml,readonly"
)

Write-Step "Starting ResourceManager"
$ResourceManagerArgs = @(
    "run", "-d",
    "--name", "resourcemanager",
    "--hostname", "resourcemanager",
    "--network", $Network,
    "-p", "8088:8088"
) + $ConfigMount + @(
    "--entrypoint", "/opt/hadoop/bin/yarn",
    $Image,
    "resourcemanager"
)

Invoke-DockerChecked $ResourceManagerArgs "Failed to start ResourceManager"

Write-Step "Starting NodeManager"
$NodeManagerArgs = @(
    "run", "-d",
    "--name", "nodemanager",
    "--hostname", "nodemanager",
    "--network", $Network,
    "-p", "8042:8042"
) + $ConfigMount + @(
    "--entrypoint", "/opt/hadoop/bin/yarn",
    $Image,
    "nodemanager"
)

Invoke-DockerChecked $NodeManagerArgs "Failed to start NodeManager"

Write-Step "Starting WebAppProxy"
$WebAppProxyArgs = @(
    "run", "-d",
    "--name", "webappproxy",
    "--hostname", "webappproxy",
    "--network", $Network,
    "-p", "9099:9099"
) + $ConfigMount + @(
    "--entrypoint", "/opt/hadoop/bin/yarn",
    $Image,
    "proxyserver"
)

Invoke-DockerChecked $WebAppProxyArgs "Failed to start WebAppProxy"

Write-Step "YARN cluster started"

& docker ps `
    --filter "name=resourcemanager" `
    --filter "name=nodemanager" `
    --filter "name=webappproxy" `
    --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"

Write-Host ""
Write-Host "ResourceManager UI: http://localhost:8088" -ForegroundColor Green
Write-Host "NodeManager UI:    http://localhost:8042" -ForegroundColor Green
Write-Host "WebAppProxy:       http://localhost:9099" -ForegroundColor Green
