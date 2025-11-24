# auto-logger.ps1 - PowerShell version
# Automatic command logging with manual toggle and auto-detection
# Version: 1.0.0

# Configuration
$global:AUTO_LOGGER_ENABLED = 0
$global:AUTO_LOGGER_MODE = ""
$global:AUTO_LOGGER_NAME = ""
$global:AUTO_LOGGER_FORMAT = if ($env:AUTO_LOGGER_FORMAT) { $env:AUTO_LOGGER_FORMAT } else { "default" }

# Get log directory using smart resolution
# Priority: 1) Centralized mode, 2) AUTO_LOGGER_DIR, 3) ./logs, 4) ~/logs
function Get-AutoLoggerDir {
    # Try to use Node.js helper if available
    $scriptDir = Split-Path -Parent $PSScriptRoot
    $helper = Join-Path $scriptDir "bin\get-log-dir.js"

    if ((Test-Path $helper) -and (Get-Command node -ErrorAction SilentlyContinue)) {
        try {
            $result = node $helper 2>$null
            if ($result) { return $result }
        } catch {
            # Fall through to other methods
        }
    }

    # Check environment variable
    if ($env:AUTO_LOGGER_DIR) {
        return $env:AUTO_LOGGER_DIR
    }

    # Check for local logs directory
    if (Test-Path ".\logs") {
        return ".\logs"
    }

    # Default to home logs directory
    return Join-Path $HOME "logs"
}

# Initialize logger
function Initialize-AutoLogger {
    $logDir = Get-AutoLoggerDir
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $env:AUTO_LOGGER_DIR = $logDir
}

# Generate log filename based on command
function Get-AutoLoggerFilename {
    param([string]$Command)

    $parts = $Command -split '\s+'
    $mainCmd = $parts[0]
    $firstArg = if ($parts.Length -gt 1) { $parts[1] } else { "" }
    $secondArg = if ($parts.Length -gt 2) { $parts[2] } else { "" }

    $filename = ""

    switch ($mainCmd) {
        { $_ -in @('npm', 'pnpm', 'yarn', 'bun') } {
            if ($firstArg -eq 'run') {
                $filename = "$mainCmd-$secondArg.log"
            } else {
                $filename = "$mainCmd-$firstArg.log"
            }
        }
        'npx' { $filename = "npx-$firstArg.log" }
        'docker' { $filename = "docker-$firstArg.log" }
        'docker-compose' { $filename = "docker-compose-$firstArg.log" }
        { $_ -in @('kubectl', 'k') } {
            $filename = "kubectl-$firstArg-$secondArg.log"
        }
        'terraform' { $filename = "terraform-$firstArg.log" }
        'wrangler' { $filename = "wrangler-$firstArg.log" }
        { $_ -in @('python', 'python3', 'py') } {
            $script = Split-Path -Leaf $firstArg
            $filename = "python-$script.log"
        }
        'node' {
            $script = Split-Path -Leaf $firstArg
            $filename = "node-$script.log"
        }
        { $_ -in @('go', 'cargo', 'flutter', 'ng', 'vue') } {
            $filename = "$mainCmd-$firstArg.log"
        }
        default {
            if ($firstArg) {
                $filename = "$mainCmd-$firstArg.log"
            } else {
                $filename = "$mainCmd.log"
            }
        }
    }

    return $filename
}

# Execute and log command
function Invoke-AutoLoggerExec {
    param([string]$Command)

    if ($global:AUTO_LOGGER_ENABLED -eq 0) {
        Invoke-Expression $Command
        return
    }

    Initialize-AutoLogger
    $logDir = $env:AUTO_LOGGER_DIR

    # Determine log file
    if ($global:AUTO_LOGGER_MODE -eq "auto") {
        $filename = Get-AutoLoggerFilename -Command $Command
    } else {
        $filename = "$global:AUTO_LOGGER_NAME.log"
    }

    $logFile = Join-Path $logDir $filename

    # Write log header
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $header = "`n=== Log started at $timestamp ===`nCommand: $Command`n---`n"
    Add-Content -Path $logFile -Value $header

    # Execute command with output capture
    try {
        Invoke-Expression $Command 2>&1 | Tee-Object -FilePath $logFile -Append
        $exitCode = $LASTEXITCODE
    } catch {
        $exitCode = 1
        $errorMsg = $_.Exception.Message
        Write-Host $errorMsg -ForegroundColor Red
        Add-Content -Path $logFile -Value $errorMsg
    }

    # Write log footer
    $endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $footer = "`n---`n=== Log ended at $endTime (exit code: $exitCode) ===`n"
    Add-Content -Path $logFile -Value $footer

    return $exitCode
}

# log-enable command
function log-enable {
    param([string]$Name)

    if (-not $Name) {
        Write-Host "Usage: log-enable <name|auto>"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  log-enable frontend    # All commands → logs/frontend.log"
        Write-Host "  log-enable auto        # Smart per-command files"
        return
    }

    if ($Name -eq "browser") {
        Write-Host "Browser logging is handled by Node.js CLI"
        Write-Host "This should be routed through the main CLI router"
        return
    }

    Initialize-AutoLogger

    if ($Name -eq "auto") {
        $global:AUTO_LOGGER_MODE = "auto"
        $global:AUTO_LOGGER_ENABLED = 1
        Write-Host "✓ Auto-detection logging enabled"
        Write-Host "→ Commands will be logged to individual files"
    } else {
        $global:AUTO_LOGGER_MODE = "manual"
        $global:AUTO_LOGGER_NAME = $Name
        $global:AUTO_LOGGER_ENABLED = 1

        $logDir = $env:AUTO_LOGGER_DIR
        $logFile = Join-Path $logDir "$Name.log"

        # Clear/create log file
        "" | Out-File -FilePath $logFile

        Write-Host "✓ Logging enabled: $Name"
        Write-Host "→ Logging to: $logFile"
    }

    Write-Host "→ Log directory: $env:AUTO_LOGGER_DIR"
}

# log-disable command
function log-disable {
    $global:AUTO_LOGGER_ENABLED = 0
    $global:AUTO_LOGGER_MODE = ""
    $global:AUTO_LOGGER_NAME = ""
    Write-Host "✓ Logging disabled"
}

# log-status command
function log-status {
    if ($global:AUTO_LOGGER_ENABLED -eq 1) {
        Write-Host "Logging: enabled"
        Write-Host "Mode: $global:AUTO_LOGGER_MODE"
        if ($global:AUTO_LOGGER_MODE -eq "manual") {
            Write-Host "Session: $global:AUTO_LOGGER_NAME"
        }
        Write-Host "Directory: $env:AUTO_LOGGER_DIR"
        Write-Host "Format: $global:AUTO_LOGGER_FORMAT"
    } else {
        Write-Host "Logging: disabled"
        Write-Host ""
        Write-Host "Enable with: log-enable <name|auto>"
    }
}

# log-fmt command
function log-fmt {
    param([string]$Format)

    $validFormats = @('default', 'compact', 'json', 'silent', 'timestamps')

    if (-not $Format -or $Format -notin $validFormats) {
        Write-Host "Usage: log-fmt <format>"
        Write-Host ""
        Write-Host "Available formats:"
        Write-Host "  default     Raw output (no formatting)"
        Write-Host "  compact     One-line summaries"
        Write-Host "  json        Pretty-print JSON"
        Write-Host "  silent      No terminal output"
        Write-Host "  timestamps  Add timestamps"
        return
    }

    $global:AUTO_LOGGER_FORMAT = $Format
    $env:AUTO_LOGGER_FORMAT = $Format
    Write-Host "✓ Output format set to: $Format"
}

# log-list command
function log-list {
    Initialize-AutoLogger
    $logDir = $env:AUTO_LOGGER_DIR

    if (-not (Test-Path $logDir)) {
        Write-Host "No logs directory found: $logDir"
        return
    }

    $logs = Get-ChildItem -Path $logDir -Filter *.log -File | Sort-Object LastWriteTime -Descending

    if ($logs.Count -eq 0) {
        Write-Host "No log files found in $logDir"
        return
    }

    Write-Host "Logs in $logDir`:"
    Write-Host ""

    foreach ($log in $logs) {
        $size = "{0:N1} MB" -f ($log.Length / 1MB)
        $time = $log.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "  $($log.Name.PadRight(40)) ($size, $time)"
    }

    Write-Host ""
    Write-Host "Total: $($logs.Count) log file(s)"
}

# log-view command
function log-view {
    param([string]$Name)

    if (-not $Name) {
        Write-Host "Usage: log-view <name>"
        return
    }

    Initialize-AutoLogger
    $logDir = $env:AUTO_LOGGER_DIR

    # Check if absolute path provided (Windows: C:\path or Unix: /path)
    if ([System.IO.Path]::IsPathRooted($Name)) {
        $logFile = $Name
    } else {
        # Strip .log extension if present
        $logName = $Name -replace '\.log$', ''
        $logFile = Join-Path $logDir "$logName.log"
    }

    if (-not (Test-Path $logFile)) {
        # Try to find partial match
        $matches = Get-ChildItem -Path $logDir -Filter "*$Name*.log" -File
        if ($matches.Count -eq 1) {
            $logFile = $matches[0].FullName
        } else {
            Write-Host "Log file not found: $logFile"
            return
        }
    }

    Get-Content $logFile | more
}

# log-clear command
function log-clear {
    param([string]$Name)

    Initialize-AutoLogger
    $logDir = $env:AUTO_LOGGER_DIR

    if ($Name) {
        # Check if absolute path provided
        if ([System.IO.Path]::IsPathRooted($Name)) {
            $logFile = $Name
        } else {
            # Strip .log extension if present
            $logName = $Name -replace '\.log$', ''
            $logFile = Join-Path $logDir "$logName.log"
        }

        if (Test-Path $logFile) {
            Remove-Item $logFile -Force
            Write-Host "✓ Cleared log: $(Split-Path -Leaf $logFile)"
        } else {
            Write-Host "Log file not found: $logFile"
        }
    } else {
        # Clear all logs
        $logs = Get-ChildItem -Path $logDir -Filter *.log -File
        if ($logs.Count -eq 0) {
            Write-Host "No log files to clear"
            return
        }

        $confirm = Read-Host "Clear all $($logs.Count) log file(s)? (y/N)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y') {
            $logs | Remove-Item -Force
            Write-Host "✓ Cleared $($logs.Count) log file(s)"
        } else {
            Write-Host "Cancelled"
        }
    }
}

# log-copy command
function log-copy {
    param([string]$Name)

    Initialize-AutoLogger
    $logDir = $env:AUTO_LOGGER_DIR

    if ($Name) {
        # Check if absolute path provided
        if ([System.IO.Path]::IsPathRooted($Name)) {
            $logFile = $Name
        } else {
            # Strip .log extension if present
            $logName = $Name -replace '\.log$', ''
            $logFile = Join-Path $logDir "$logName.log"
        }
    } else {
        # Get most recent log
        $logs = Get-ChildItem -Path $logDir -Filter *.log -File | Sort-Object LastWriteTime -Descending
        if ($logs.Count -eq 0) {
            Write-Host "No log files found"
            return
        }
        $logFile = $logs[0].FullName
    }

    if (-not (Test-Path $logFile)) {
        Write-Host "Log file not found: $logFile"
        return
    }

    # Convert to absolute path
    $absolutePath = (Resolve-Path $logFile).Path

    # Copy to clipboard
    Set-Clipboard -Value $absolutePath
    Write-Host "📋 Copied to clipboard: $absolutePath"
}

# log-centralize command
function log-centralize {
    param([string]$Action)

    $scriptDir = Split-Path -Parent $PSScriptRoot
    $cliTool = Join-Path $scriptDir "bin\auto-logger.js"

    if ((Test-Path $cliTool) -and (Get-Command node -ErrorAction SilentlyContinue)) {
        node $cliTool centralize $Action
    } else {
        Write-Host "Error: Node.js CLI tool not found or Node.js not installed"
        Write-Host "Please ensure auto-logger is properly installed via npm"
    }
}

# log-help command
function log-help {
    Write-Host @"

auto-logger - Automatic command logging for developers

USAGE:
  log-enable <name|auto>    Enable logging
  log-disable               Disable logging
  log-status                Show current status
  log-fmt <format>          Set output format

MODES:
  Manual Mode:
    log-enable frontend     All commands → logs/frontend.log
    npm run dev
    npm test
    log-disable

  Auto Mode:
    log-enable auto         Smart per-command files
    npm run dev            → logs/npm-dev.log
    docker build .         → logs/docker-build.log

COMMANDS:
  log-list                  List all log files
  log-view <name>           View a log file
  log-clear [name]          Clear log(s)
  log-copy [name]           Copy log path to clipboard
  log-centralize <action>   Control centralized mode
  log-help                  Show this help

FORMATS:
  log-fmt default           Raw output
  log-fmt compact           One-line summaries
  log-fmt json              Pretty JSON
  log-fmt silent            No terminal output
  log-fmt timestamps        Add timestamps

For full documentation:
  https://github.com/naorbrig/Auto-Logger

"@
}

# Initialize on load
Initialize-AutoLogger

Write-Host "✓ auto-logger loaded (PowerShell)"
Write-Host "  Commands: log-enable, log-disable, log-status, log-fmt, log-list, log-view, log-clear, log-copy, log-help"
Write-Host "           log-centralize, log-projects"
Write-Host "  Logs directory: $env:AUTO_LOGGER_DIR"
Write-Host "  Type 'log-help' for usage info"
