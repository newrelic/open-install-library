# Configure NRDOT Collector for SQL Server Monitoring
# This script edits the existing NRDOT config to add SQL Server monitoring

param(
    [Parameter(Mandatory=$true)]
    [string]$Hostname,

    [Parameter(Mandatory=$true)]
    [string]$Port,

    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$Password,

    [Parameter(Mandatory=$true)]
    [string]$OtlpEndpoint,

    [Parameter(Mandatory=$true)]
    [string]$LicenseKey
)

$ErrorActionPreference = "Stop"
$configPath = "C:\Program Files (x86)\NRDOT Collector Host\config.yaml"

Write-Host ""
Write-Host "=== Configuring NRDOT Collector for SQL Server ==="
Write-Host ""
Write-Host "SQL Server: $Hostname:$Port"
Write-Host "Username: $Username"
Write-Host ""

# Backup existing config
if (Test-Path $configPath) {
    $backupPath = $configPath + ".backup." + (Get-Date -Format "yyyyMMdd-HHmmss")
    Write-Host "Creating backup: $backupPath"
    Copy-Item $configPath $backupPath
    Write-Host ""
}

# Read existing config
$config = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)

Write-Host "Adding SQL Server receiver configuration..."

# Build newrelicsqlserver receiver
$receiver = @"

  newrelicsqlserver:
    hostname: "$Hostname"
    port: $Port
    username: "$Username"
    password: "$Password"
    monitored_databases: []
    # timeout: 30s
    # collection_interval: 30s
    # query_monitoring_fetch_interval: 15
    # query_monitoring_response_time_threshold: 100
    # query_monitoring_count_threshold: 30
    # interval_calculator_cache_ttl_minutes: 10

    # Core Metric Category Toggles - Enable/disable entire categories of metrics
    # enable_instance_metrics: true
    # enable_database_metrics: true
    # enable_user_connection_metrics: true
    # enable_wait_time_metrics: true
    # enable_failover_cluster_metrics: true
    # enable_database_principals_metrics: true
    # enable_database_role_membership_metrics: true
    # enable_security_metrics: true
    # enable_lock_metrics: true
    # enable_thread_pool_metrics: true
    # enable_tempdb_metrics: true
    # enable_database_buffer_metrics: true
"@

# Insert receiver after filelog or before processors section
if ($config -match "(?s)(receivers:.*?)(processors:)") {
    $receiversBlock = $matches[1]
    $processorsBlock = $matches[2]
    $config = $config -replace [regex]::Escape($receiversBlock + $processorsBlock), ($receiversBlock + $receiver + "`n`n" + $processorsBlock)
    Write-Host "  ✓ Added newrelicsqlserver receiver"
} else {
    Write-Host "  WARNING: Could not find receivers section"
}

# Add SQL Server processors
Write-Host "Adding SQL Server processors..."

$processors = @"

  # SQL Server execution plan filters
  filter/exec_plan_include:
    metrics:
      include:
        match_type: strict
        metric_names:
          - sqlserver.slowquery.query_details
          - sqlserver.execution.plan
          - sqlserver.blocking_query.details
          - sqlserver.activequery.query_details

  filter/exec_plan_exclude:
    metrics:
      exclude:
        match_type: strict
        metric_names:
          - sqlserver.slowquery.query_details
          - sqlserver.execution.plan
          - sqlserver.blocking_query.details
          - sqlserver.activequery.query_details

  # SQL Server metrics conversion
  cumulativetodelta:
    max_staleness: 5m
    include:
      match_type: strict
      metrics:
        - sqlserver.wait_stats.latch.wait_time_ms
        - sqlserver.wait_stats.latch.waiting_tasks_count
        - sqlserver.wait_stats.wait_time_ms
        - sqlserver.wait_stats.waiting_tasks_count
        - sqlserver.stats.sql_compilations_per_sec
        - sqlserver.stats.sql_recompilations_per_sec
        - sqlserver.stats.lock_waits_per_sec
        - sqlserver.stats.deadlocks_per_sec
        - sqlserver.stats.user_errors_per_sec
        - sqlserver.stats.kill_connection_errors_per_sec
        - sqlserver.access.page_splits_per_sec
        - sqlserver.buffer.checkpoint_pages_per_sec
        - sqlserver.bufferpool.batch_requests_per_sec
        - sqlserver.instance.transactions_per_sec
        - sqlserver.instance.forced_parameterizations_per_sec
        - sqlserver.instance.full_scans_rate
        - sqlserver.instance.lock_timeouts_rate
        - sqlserver.database.log.flushes_per_sec
        - sqlserver.database.log.bytes_flushed_per_sec
        - sqlserver.database.log.flush_waits_per_sec
        - sqlserver.failover_cluster.log_bytes_received_per_sec
        - sqlserver.user_connections.authentication.logins_per_sec

  deltatorate:
    metrics:
      - sqlserver.wait_stats.latch.wait_time_ms
      - sqlserver.wait_stats.latch.waiting_tasks_count
      - sqlserver.wait_stats.wait_time_ms
      - sqlserver.wait_stats.waiting_tasks_count
      - sqlserver.stats.sql_compilations_per_sec
      - sqlserver.stats.sql_recompilations_per_sec
      - sqlserver.stats.lock_waits_per_sec
      - sqlserver.stats.deadlocks_per_sec
      - sqlserver.stats.user_errors_per_sec
      - sqlserver.stats.kill_connection_errors_per_sec
      - sqlserver.access.page_splits_per_sec
      - sqlserver.buffer.checkpoint_pages_per_sec
      - sqlserver.bufferpool.batch_requests_per_sec
      - sqlserver.instance.transactions_per_sec
      - sqlserver.instance.forced_parameterizations_per_sec
      - sqlserver.instance.full_scans_rate
      - sqlserver.instance.lock_timeouts_rate
      - sqlserver.database.log.flushes_per_sec
      - sqlserver.database.log.bytes_flushed_per_sec
      - sqlserver.database.log.flush_waits_per_sec
      - sqlserver.failover_cluster.log_bytes_received_per_sec
      - sqlserver.user_connections.authentication.logins_per_sec

  resourcedetection/db_safe:
    detectors: ["system"]
    override: false
    system:
      hostname_sources: ["os"]
      resource_attributes:
        host.id:
          enabled: true
"@

if ($config -match "(?s)(processors:.*?)(exporters:)") {
    $processorsBlock = $matches[1]
    $exportersBlock = $matches[2]
    $config = $config -replace [regex]::Escape($processorsBlock + $exportersBlock), ($processorsBlock + $processors + "`n`n" + $exportersBlock)
    Write-Host "  ✓ Added SQL Server processors"
} else {
    Write-Host "  WARNING: Could not find processors section"
}

# Add connectors
Write-Host "Adding connectors..."

$connectors = @"

connectors:
  metricsaslogs:
    include_resource_attributes: true
    include_scope_info: true
"@

if ($config -match "(?s)(processors:.*?)(exporters:)") {
    $beforeExporters = $matches[1]
    $exportersBlock = $matches[2]
    $config = $config -replace [regex]::Escape($beforeExporters + $exportersBlock), ($beforeExporters + $connectors + "`n" + $exportersBlock)
    Write-Host "  ✓ Added connectors"
}

# Update exporters
Write-Host "Updating OTLP exporter..."
$config = $config -replace "endpoint:.*", "endpoint: `"$OtlpEndpoint`""
$config = $config -replace "api-key:.*", "api-key: `"$LicenseKey`""
Write-Host "  ✓ Updated endpoint and API key"

# Update metrics pipeline
Write-Host "Updating service pipelines..."
$config = $config -replace "receivers: \[otlp\]", "receivers: [newrelicsqlserver, otlp]"

# Add SQL Server pipelines before extensions
$sqlPipelines = @"
    logs:
      receivers: [metricsaslogs, otlp]
      processors: [memory_limiter, transform, resourcedetection, resourcedetection/cloud, resourcedetection/env, batch]
      exporters: [otlphttp]
    metrics/exec_plan_to_logs:
      receivers: [newrelicsqlserver, otlp]
      processors: [memory_limiter, transform, resourcedetection, resourcedetection/cloud, resourcedetection/env, filter/exec_plan_include, batch]
      exporters: [metricsaslogs]
"@

if ($config -match "(?s)(  pipelines:.*?)(  extensions:)") {
    $pipelinesBlock = $matches[1]
    $extensionsBlock = $matches[2]
    $config = $config -replace [regex]::Escape($pipelinesBlock + $extensionsBlock), ($pipelinesBlock + $sqlPipelines + "`n" + $extensionsBlock)
    Write-Host "  ✓ Added SQL Server pipelines"
}

# Write updated config
Write-Host ""
Write-Host "Writing updated configuration..."
[System.IO.File]::WriteAllText($configPath, $config, [System.Text.Encoding]::UTF8)
Write-Host "  ✓ Configuration updated"

# Restart service
Write-Host ""
Write-Host "Restarting NRDOT Collector service..."
try {
    $service = Get-Service -Name "NRDOT Collector Host" -ErrorAction SilentlyContinue
    if ($service) {
        Restart-Service -Name "NRDOT Collector Host" -Force
        Start-Sleep -Seconds 3

        $service = Get-Service -Name "NRDOT Collector Host"
        Write-Host "  Service status: $($service.Status)"

        if ($service.Status -eq "Running") {
            Write-Host ""
            Write-Host "SUCCESS: NRDOT Collector configured and running!" -ForegroundColor Green
            Write-Host ""
            Write-Host "SQL Server metrics will appear in New Relic within 1-2 minutes."
        } else {
            Write-Host ""
            Write-Host "WARNING: Service is not running. Status: $($service.Status)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  WARNING: Service not found" -ForegroundColor Yellow
    }
} catch {
    Write-Host ""
    Write-Host "ERROR: Failed to restart service: $_" -ForegroundColor Red
    exit 1
}
