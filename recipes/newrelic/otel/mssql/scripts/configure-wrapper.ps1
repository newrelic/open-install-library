# Configuration Wrapper Script for NRDOT Collector
# This script is downloaded and executed by the New Relic CLI installer

param(
    [Parameter(Mandatory=$true)]
    [string]$Region,

    [Parameter(Mandatory=$true)]
    [string]$LicenseKey
)

$ErrorActionPreference = "Stop"

# Load connection config
$configFile = Join-Path $env:TEMP "nr-mssql-config.txt"
if (-not (Test-Path $configFile)) {
    Write-Host "ERROR: Connection configuration file not found."
    exit 1
}

$config = @{}
Get-Content $configFile -Encoding UTF8 | ForEach-Object {
    if ($_ -match "^(\w+)=(.*)$") {
        $config[$matches[1]] = $matches[2].Trim()
    }
}

# Load monitoring user credentials
$monitoringConfigFile = Join-Path $env:TEMP "nr-mssql-monitoring-user.txt"
if (-not (Test-Path $monitoringConfigFile)) {
    Write-Host "ERROR: Monitoring user configuration file not found."
    exit 1
}

Get-Content $monitoringConfigFile -Encoding UTF8 | ForEach-Object {
    if ($_ -match "^MONITORING_(\w+)=(.*)$") {
        $config["MONITORING_" + $matches[1]] = $matches[2].Trim()
    }
}

# OTLP endpoint based on region
$otlpEndpoint = "https://otlp.nr-data.net"
if ($Region -eq "EU") {
    $otlpEndpoint = "https://otlp.eu01.nr-data.net"
} elseif ($Region -eq "STAGING") {
    $otlpEndpoint = "https://staging-otlp.nr-data.net"
}

# Download main configuration script
$scriptUrl = "https://raw.githubusercontent.com/pkudikyala/open-install-library/pk-mssql-otel-cli/recipes/newrelic/otel/mssql/scripts/configure-nrdot-sqlserver.ps1"
$scriptPath = Join-Path $env:TEMP "configure-nrdot-sqlserver.ps1"

Write-Host ""
Write-Host "Downloading configuration script..."
try {
    (New-Object System.Net.WebClient).DownloadFile($scriptUrl, $scriptPath)
    Write-Host "Script downloaded successfully."
} catch {
    Write-Host "ERROR: Failed to download configuration script"
    Write-Host $_
    exit 1
}

# Execute configuration script
Write-Host ""
& $scriptPath `
    -Hostname $config["HOSTNAME"] `
    -Port $config["PORT"] `
    -Username $config["MONITORING_USERNAME"] `
    -Password $config["MONITORING_PASSWORD"] `
    -OtlpEndpoint $otlpEndpoint `
    -LicenseKey $LicenseKey

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Configuration failed"
    exit 1
}

# Clean up
Remove-Item $scriptPath -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Configuration completed successfully."
