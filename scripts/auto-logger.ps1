# auto-logger.ps1 - PowerShell version
# Automatic command logging with manual toggle and auto-detection
# Version: 1.1.0

# Configuration
$global:AUTO_LOGGER_ENABLED = 0
$global:AUTO_LOGGER_MODE = ""
$global:AUTO_LOGGER_NAME = ""
$global:AUTO_LOGGER_FORMAT = if ($env:AUTO_LOGGER_FORMAT) { $env:AUTO_LOGGER_FORMAT } else { "default" }
$global:AUTO_LOGGER_APPEND = 0  # 0 = overwrite each command (default), 1 = append
$global:AUTO_LOGGER_FILTER_ENABLED = 0  # 0 = no filtering (default), 1 = filtering enabled
$global:AUTO_LOGGER_FILTER_MODE = "terminal"  # terminal = filter terminal only, both = filter terminal and file

# Store script directory for reliable path resolution
$global:AUTO_LOGGER_SCRIPT_DIR = Split-Path -Parent $PSScriptRoot

# Get log directory using smart resolution
# Priority: 1) Centralized mode, 2) AUTO_LOGGER_DIR, 3) ./logs, 4) ~/logs
function Get-AutoLoggerDir {
    # Try to use Node.js helper if available
    $helper = Join-Path $global:AUTO_LOGGER_SCRIPT_DIR "bin\get-log-dir.js"

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

# Detect tool from command for filtering
function Get-DetectedTool {
    param([string]$Command)

    $cmd = $Command.ToLower()

    if ($cmd -match '^flutter') { return "flutter" }
    if ($cmd -match '^(npm|pnpm|yarn|npx)') { return "npm" }
    if ($cmd -match '^docker') { return "docker" }
    if ($cmd -match '^vite') { return "vite" }
    if ($cmd -match '^wrangler') { return "wrangler" }
    if ($cmd -match '^(pytest|python)') { return "pytest" }
    if ($cmd -match '^(gradle|\.\/gradlew)') { return "gradle" }

    return ""
}

# Get filter patterns from JSON file
function Get-FilterPatterns {
    param([string]$Tool)

    $filtersFile = Join-Path $global:AUTO_LOGGER_SCRIPT_DIR "lib\log-filters.json"

    if (-not (Test-Path $filtersFile)) {
        return $null
    }

    try {
        $filters = Get-Content $filtersFile -Raw | ConvertFrom-Json
        if ($filters.$Tool) {
            return $filters.$Tool
        }
    } catch {
        # Ignore errors
    }

    return $null
}

# Filter a single line based on patterns
function Test-ShouldFilterLine {
    param(
        [string]$Line,
        [array]$FilterPatterns,
        [array]$KeepPatterns
    )

    # Check keep patterns first (highest priority)
    if ($KeepPatterns) {
        foreach ($pattern in $KeepPatterns) {
            if ($Line -match $pattern) {
                return $false  # Don't filter, keep this line
            }
        }
    }

    # Check filter patterns
    if ($FilterPatterns) {
        foreach ($pattern in $FilterPatterns) {
            if ($Line -match $pattern) {
                return $true  # Filter this line
            }
        }
    }

    return $false  # Don't filter by default
}

# Filter stream processing
function Invoke-FilterStream {
    param(
        [string]$Tool,
        [string[]]$InputLines
    )

    if ($global:AUTO_LOGGER_FILTER_ENABLED -ne 1) {
        return $InputLines
    }

    if (-not $Tool) {
        return $InputLines
    }

    $patterns = Get-FilterPatterns -Tool $Tool
    if (-not $patterns) {
        return $InputLines
    }

    $filterPatterns = $patterns.filter_patterns
    $keepPatterns = $patterns.keep_patterns

    $filteredLines = @()
    foreach ($line in $InputLines) {
        $shouldFilter = Test-ShouldFilterLine -Line $line -FilterPatterns $filterPatterns -KeepPatterns $keepPatterns
        if (-not $shouldFilter) {
            $filteredLines += $line
        }
    }

    return $filteredLines
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

    # Determine if we should append or overwrite
    $appendMode = $global:AUTO_LOGGER_APPEND -eq 1

    # Write log header
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $header = "`n=== Log started at $timestamp ===`nCommand: $Command`n---`n"

    if ($appendMode) {
        Add-Content -Path $logFile -Value $header
    } else {
        Set-Content -Path $logFile -Value $header
    }

    # Detect tool for filtering
    $detectedTool = Get-DetectedTool -Command $Command

    # Execute command with output capture
    try {
        $output = Invoke-Expression "$Command 2>&1" | Out-String
        $outputLines = $output -split "`n"
        $exitCode = $LASTEXITCODE

        # Apply filtering based on mode
        if ($global:AUTO_LOGGER_FILTER_ENABLED -eq 1 -and $detectedTool) {
            if ($global:AUTO_LOGGER_FILTER_MODE -eq "both") {
                # Filter both terminal and file
                $filteredLines = Invoke-FilterStream -Tool $detectedTool -InputLines $outputLines
                $filteredOutput = $filteredLines -join "`n"
                Write-Host $filteredOutput
                Add-Content -Path $logFile -Value $filteredOutput
            } else {
                # terminal mode: Raw to file, filtered to terminal
                Add-Content -Path $logFile -Value $output
                $filteredLines = Invoke-FilterStream -Tool $detectedTool -InputLines $outputLines
                $filteredOutput = $filteredLines -join "`n"
                Write-Host $filteredOutput
            }
        } else {
            # No filtering - output to both
            Write-Host $output
            Add-Content -Path $logFile -Value $output
        }
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
        Write-Host "  log-enable frontend    # All commands -> logs/frontend.log"
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
        Write-Host "Auto-detection logging enabled"
        Write-Host "-> Commands will be logged to individual files"
    } else {
        $global:AUTO_LOGGER_MODE = "manual"
        $global:AUTO_LOGGER_NAME = $Name
        $global:AUTO_LOGGER_ENABLED = 1

        $logDir = $env:AUTO_LOGGER_DIR
        $logFile = Join-Path $logDir "$Name.log"

        # Clear/create log file (unless append mode)
        if ($global:AUTO_LOGGER_APPEND -ne 1) {
            "" | Out-File -FilePath $logFile
        }

        Write-Host "Logging enabled: $Name"
        Write-Host "-> Logging to: $logFile"
    }

    Write-Host "-> Log directory: $env:AUTO_LOGGER_DIR"
}

# log-disable command
function log-disable {
    $global:AUTO_LOGGER_ENABLED = 0
    $global:AUTO_LOGGER_MODE = ""
    $global:AUTO_LOGGER_NAME = ""
    Write-Host "Logging disabled"
}

# log-status command
function log-status {
    if ($global:AUTO_LOGGER_ENABLED -eq 1) {
        Write-Host "Logging: ENABLED"
        Write-Host "   Mode: $global:AUTO_LOGGER_MODE"
        if ($global:AUTO_LOGGER_MODE -eq "manual") {
            $logDir = $env:AUTO_LOGGER_DIR
            $logFile = Join-Path $logDir "$global:AUTO_LOGGER_NAME.log"
            Write-Host "   File: $logFile"
        }
        Write-Host "   Format: $global:AUTO_LOGGER_FORMAT"

        # Show append status
        if ($global:AUTO_LOGGER_APPEND -eq 1) {
            Write-Host "   Append: enabled (commands append to log)"
        } else {
            Write-Host "   Append: disabled (commands overwrite log)"
        }

        # Show filter status
        if ($global:AUTO_LOGGER_FILTER_ENABLED -eq 1) {
            Write-Host "   Filter: enabled (mode: $global:AUTO_LOGGER_FILTER_MODE)"
        } else {
            Write-Host "   Filter: disabled"
        }
    } else {
        Write-Host "Logging: DISABLED"
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
    Write-Host "Output format set to: $Format"
}

# log-append command
function log-append {
    param([string]$Action)

    if (-not $Action) { $Action = "status" }

    switch ($Action) {
        "enable" {
            $global:AUTO_LOGGER_APPEND = 1
            Write-Host "Append mode enabled"
            Write-Host "  Commands will append to log files"
        }
        "disable" {
            $global:AUTO_LOGGER_APPEND = 0
            Write-Host "Append mode disabled"
            Write-Host "  Commands will overwrite log files (default)"
        }
        "status" {
            if ($global:AUTO_LOGGER_APPEND -eq 1) {
                Write-Host "Append mode: enabled"
                Write-Host "  Each command appends to the log file"
            } else {
                Write-Host "Append mode: disabled (default)"
                Write-Host "  Each command overwrites the log file"
            }
        }
        default {
            Write-Host "Usage: log-append [enable|disable|status]"
            Write-Host ""
            Write-Host "Commands:"
            Write-Host "  enable   Commands append to existing log file"
            Write-Host "  disable  Commands overwrite log file (default)"
            Write-Host "  status   Show current append mode"
        }
    }
}

# log-filter command
function log-filter {
    param(
        [string]$Action,
        [string]$Arg1,
        [string]$Arg2
    )

    if (-not $Action) { $Action = "status" }

    switch ($Action) {
        "enable" {
            $global:AUTO_LOGGER_FILTER_ENABLED = 1
            Write-Host "Log filtering enabled"
            Write-Host "  Mode: $global:AUTO_LOGGER_FILTER_MODE"
            Write-Host "  Noisy logs will be filtered based on tool detection"
            Write-Host ""
            Write-Host "Supported tools: flutter, npm, docker, vite, wrangler, pytest, gradle"
        }
        "disable" {
            $global:AUTO_LOGGER_FILTER_ENABLED = 0
            Write-Host "Log filtering disabled"
            Write-Host "  All output will be shown"
        }
        "status" {
            if ($global:AUTO_LOGGER_FILTER_ENABLED -eq 1) {
                Write-Host "Log filtering: enabled"
                Write-Host "  Mode: $global:AUTO_LOGGER_FILTER_MODE"
                if ($global:AUTO_LOGGER_FILTER_MODE -eq "terminal") {
                    Write-Host "    - Terminal output: filtered"
                    Write-Host "    - Log file: raw (unfiltered)"
                } else {
                    Write-Host "    - Terminal output: filtered"
                    Write-Host "    - Log file: filtered"
                }
            } else {
                Write-Host "Log filtering: disabled"
                Write-Host "  All output is shown (no filtering)"
            }
        }
        "mode" {
            if ($Arg1 -in @("terminal", "both")) {
                $global:AUTO_LOGGER_FILTER_MODE = $Arg1
                Write-Host "Filter mode set to: $Arg1"
                if ($Arg1 -eq "terminal") {
                    Write-Host "  Terminal output will be filtered, log files will be raw"
                } else {
                    Write-Host "  Both terminal and log files will be filtered"
                }
            } else {
                Write-Host "Usage: log-filter mode <terminal|both>"
                Write-Host ""
                Write-Host "Modes:"
                Write-Host "  terminal  Filter terminal output only (default)"
                Write-Host "            Log files contain raw unfiltered output"
                Write-Host "  both      Filter both terminal and log file output"
            }
        }
        "list" {
            $filtersFile = Join-Path $global:AUTO_LOGGER_SCRIPT_DIR "lib\log-filters.json"

            if (-not (Test-Path $filtersFile)) {
                Write-Host "Filters file not found: $filtersFile"
                return
            }

            try {
                $filters = Get-Content $filtersFile -Raw | ConvertFrom-Json
                Write-Host "Available log filters:"
                Write-Host ""

                foreach ($prop in $filters.PSObject.Properties) {
                    $tool = $prop.Name
                    $desc = $prop.Value.description
                    Write-Host "  $tool"
                    Write-Host "    $desc"
                }

                Write-Host ""
                Write-Host "Enable filtering with: log-filter enable"
            } catch {
                Write-Host "Error reading filters file: $($_.Exception.Message)"
            }
        }
        "test" {
            if (-not $Arg1) {
                Write-Host "Usage: log-filter test <tool> [logfile]"
                Write-Host ""
                Write-Host "Test filter patterns on a log file"
                Write-Host ""
                Write-Host "Examples:"
                Write-Host "  log-filter test flutter                    # Test with sample"
                Write-Host "  log-filter test flutter mylog.log          # Test on file"
                return
            }

            $tool = $Arg1
            $patterns = Get-FilterPatterns -Tool $tool

            if (-not $patterns) {
                Write-Host "No filter found for tool: $tool"
                return
            }

            Write-Host "Testing filter for: $tool"
            Write-Host "Description: $($patterns.description)"
            Write-Host ""

            if ($Arg2 -and (Test-Path $Arg2)) {
                $lines = Get-Content $Arg2
                $originalCount = $lines.Count
                $filteredLines = Invoke-FilterStream -Tool $tool -InputLines $lines

                # Temporarily enable filtering for test
                $oldFilter = $global:AUTO_LOGGER_FILTER_ENABLED
                $global:AUTO_LOGGER_FILTER_ENABLED = 1
                $filteredLines = Invoke-FilterStream -Tool $tool -InputLines $lines
                $global:AUTO_LOGGER_FILTER_ENABLED = $oldFilter

                $filteredCount = $filteredLines.Count
                $removed = $originalCount - $filteredCount
                $percent = if ($originalCount -gt 0) { [math]::Round(($removed / $originalCount) * 100, 1) } else { 0 }

                Write-Host "Results:"
                Write-Host "  Original lines: $originalCount"
                Write-Host "  After filtering: $filteredCount"
                Write-Host "  Lines removed: $removed ($percent%)"
            } else {
                Write-Host "Filter patterns: $($patterns.filter_patterns.Count)"
                Write-Host "Keep patterns: $($patterns.keep_patterns.Count)"
            }
        }
        default {
            Write-Host "Usage: log-filter <command> [args]"
            Write-Host ""
            Write-Host "Commands:"
            Write-Host "  enable              Enable log filtering"
            Write-Host "  disable             Disable log filtering"
            Write-Host "  status              Show current filter status"
            Write-Host "  mode <terminal|both> Set filter mode"
            Write-Host "  list                List available filters"
            Write-Host "  test <tool> [file]  Test filter on log file"
        }
    }
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

    Write-Host "Recent logs in $logDir`:"
    Write-Host ""

    foreach ($log in $logs) {
        $size = "{0:N1} KB" -f ($log.Length / 1KB)
        $time = $log.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        # Show absolute path
        Write-Host "  $($log.FullName)"
        Write-Host "    Size: $size, Modified: $time"
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

    # Check if absolute path provided
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

    Get-Content $logFile
}

# log-clear command (fixed to require argument)
function log-clear {
    param([string]$Name)

    if (-not $Name) {
        Write-Host "Usage: log-clear <logname|--all>"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  log-clear frontend        # Clear specific log"
        Write-Host "  log-clear --all           # Clear all logs (with confirmation)"
        Write-Host ""
        Write-Host "Tip: Use 'log-list' to see available logs"
        return
    }

    Initialize-AutoLogger
    $logDir = $env:AUTO_LOGGER_DIR

    if ($Name -eq "--all") {
        # Clear all logs with confirmation
        $logs = Get-ChildItem -Path $logDir -Filter *.log -File
        if ($logs.Count -eq 0) {
            Write-Host "No log files to clear"
            return
        }

        Write-Host "About to clear $($logs.Count) log file(s) in $logDir"
        $confirm = Read-Host "Are you sure? (y/N)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y') {
            $logs | Remove-Item -Force
            Write-Host "Cleared $($logs.Count) log file(s)"
        } else {
            Write-Host "Cancelled"
        }
        return
    }

    # Clear specific log
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
        Write-Host "Cleared log: $(Split-Path -Leaf $logFile)"
    } else {
        Write-Host "Log file not found: $logFile"
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
    Write-Host "Copied to clipboard: $absolutePath"
}

# log-centralize command
function log-centralize {
    param([string]$Action)

    $cliTool = Join-Path $global:AUTO_LOGGER_SCRIPT_DIR "bin\auto-logger.js"

    if ((Test-Path $cliTool) -and (Get-Command node -ErrorAction SilentlyContinue)) {
        node $cliTool centralize $Action
    } else {
        Write-Host "Error: Node.js CLI tool not found or Node.js not installed"
        Write-Host "Please ensure auto-logger is properly installed via npm"
    }
}

# log-projects command
function log-projects {
    param(
        [string]$ProjectName,
        [switch]$Clean
    )

    $cliTool = Join-Path $global:AUTO_LOGGER_SCRIPT_DIR "bin\log-projects.js"

    if ((Test-Path $cliTool) -and (Get-Command node -ErrorAction SilentlyContinue)) {
        $args = @()
        if ($ProjectName) { $args += $ProjectName }
        if ($Clean) { $args += "--clean" }

        if ($args.Count -gt 0) {
            node $cliTool @args
        } else {
            node $cliTool
        }
    } else {
        Write-Host "Error: Node.js CLI tool not found or Node.js not installed"
        Write-Host "Please ensure auto-logger is properly installed via npm"
    }
}

# log-run command
function log-run {
    param([string]$Command)

    if (-not $Command) {
        Write-Host "Usage: log-run <command>"
        Write-Host ""
        Write-Host "Run any command with logging enabled"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  log-run 'npm run build'"
        Write-Host "  log-run 'python script.py'"
        return
    }

    # Temporarily enable auto mode
    $wasEnabled = $global:AUTO_LOGGER_ENABLED
    $wasMode = $global:AUTO_LOGGER_MODE

    $global:AUTO_LOGGER_ENABLED = 1
    $global:AUTO_LOGGER_MODE = "auto"

    Invoke-AutoLoggerExec -Command $Command

    # Restore previous state
    $global:AUTO_LOGGER_ENABLED = $wasEnabled
    $global:AUTO_LOGGER_MODE = $wasMode
}

# log-help command
function log-help {
    Write-Host @"

auto-logger - Automatic command logging for developers
Version: 1.1.0

USAGE:
  log-enable <name|auto>    Enable logging
  log-disable               Disable logging
  log-status                Show current status
  log-fmt <format>          Set output format

MODES:
  Manual Mode:
    log-enable frontend     All commands -> logs/frontend.log
    npm run dev
    npm test
    log-disable

  Auto Mode:
    log-enable auto         Smart per-command files
    npm run dev            -> logs/npm-dev.log
    docker build .         -> logs/docker-build.log

COMMANDS:
  log-list                  List all log files
  log-view <name>           View a log file
  log-clear <name|--all>    Clear log(s)
  log-copy [name]           Copy log path to clipboard
  log-run <command>         Run command with auto-logging

ADVANCED:
  log-append [enable|disable|status]
                            Control append vs overwrite mode
  log-filter [enable|disable|status|mode|list|test]
                            Smart log filtering for noisy tools
  log-centralize <action>   Control centralized mode
  log-projects [name]       List/manage projects

FORMATS:
  log-fmt default           Raw output
  log-fmt compact           One-line summaries
  log-fmt json              Pretty JSON
  log-fmt silent            No terminal output
  log-fmt timestamps        Add timestamps

FILTERING:
  log-filter enable         Enable smart filtering
  log-filter mode terminal  Filter terminal only (default)
  log-filter mode both      Filter terminal and log file
  log-filter list           Show available filters
  log-filter test <tool>    Test filter on log file

  Supported: flutter, npm, docker, vite, wrangler, pytest, gradle

For full documentation:
  https://github.com/naorbrig/Auto-Logger

"@
}

# Initialize on load
Initialize-AutoLogger

Write-Host "auto-logger loaded (PowerShell)"
Write-Host "  Commands: log-enable, log-disable, log-status, log-fmt, log-list, log-view, log-clear, log-copy, log-help"
Write-Host "           log-append, log-filter, log-centralize, log-projects, log-run"
Write-Host "  Logs directory: $env:AUTO_LOGGER_DIR"
Write-Host "  Type 'log-help' for usage info"
