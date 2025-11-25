# Changelog

All notable changes to auto-logger will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-11-24

### Major Features

#### Smart Log Filtering (NEW!)
- **Automatic Noise Reduction**: Reduces log noise from Flutter, npm, docker, and other verbose tools by 40-60%
- **Two Filter Modes**:
  - `terminal` mode (default): Filters terminal output only, keeps raw data in log file
  - `both` mode: Filters both terminal and log file output
- **Built-in Filter Presets**:
  - **Flutter/Android**: Removes system internals (VRI, SurfaceView, InputMethod, etc.) while keeping app logs
  - **npm/webpack/vite**: Filters module lists, build progress, chunk details
  - **docker**: Filters layer hashes and download progress
  - **wrangler**: Filters repetitive GET requests for static assets
  - **pytest**: Filters verbose test discovery
  - **gradle**: Filters task execution details
- **Commands**:
  - `log-filter enable/disable` - Toggle filtering
  - `log-filter status` - Show current filter state
  - `log-filter mode <terminal|both>` - Change filter mode
  - `log-filter list` - Show available filters
  - `log-filter test <tool> [file]` - Test filter on existing log file with statistics
- **Real-World Impact**: Tested on 5,582-line Flutter log, reduced to 3,110 lines (44% noise removed)

#### Log Append Control (NEW!)
- **Per-Shell Configuration**: Control whether commands overwrite or append to log files
- **Two Modes**:
  - Overwrite (default): Each command clears the log file (clean single-run logs)
  - Append: Each command adds to existing log (multi-session debugging)
- **Commands**:
  - `log-append enable` - Commands append to log file
  - `log-append disable` - Commands overwrite log file (default)
  - `log-append status` - Show current mode
- **Use Cases**: Perfect for debugging sessions where you want to compare multiple test runs or track changes across iterations

### Added

- `log-filter` command with enable/disable/status/mode/list/test subcommands
- `log-append` command with enable/disable/status subcommands
- Filter configuration file (`lib/log-filters.json`) with 7 pre-configured tool filters
- Smart filter detection based on command name (auto-detects flutter, npm, docker, etc.)
- Filter stream processing with pattern matching (filter_patterns and keep_patterns)
- Append mode state tracking per shell session
- Updated `log-status` to show both append and filter status

### Changed

- Improved path resolution for sourced scripts using `AUTO_LOGGER_SCRIPT_DIR` global variable
- Enhanced `_auto_logger_exec` to support filtering in both terminal-only and both modes
- Updated help text and documentation to include new features

### Fixed

- Fixed `BASH_SOURCE[0]` resolution when script is sourced vs executed
- Added proper fallback for path resolution using `readlink -f`
- Fixed version mismatch in auto-logger.sh header (1.0.0 → 1.1.0)
- Fixed GitHub URL typo in help text
- Fixed default config inconsistency in centralized-manager.js
- Fixed HAR export version in browser-logger.js

### PowerShell Parity

> **⚠️ WINDOWS WARNING:** Windows/PowerShell support has been implemented but **NOT TESTED** on actual Windows machines. Please [report any issues](https://github.com/naorbrig/Auto-Logger/issues).

- **Full Feature Parity**: PowerShell now supports all v1.1.0 features matching bash:
  - `log-append enable/disable/status` - Append mode control
  - `log-filter enable/disable/status/mode/list/test` - Smart filtering
  - `log-projects [name] [--clean]` - Project management
  - `log-run <command>` - Execute command with logging
- Added filter stream processing with pattern matching
- Added tool detection for auto-filtering
- Added JSON filter configuration parsing
- Updated `log-status` to show append/filter status
- Fixed `log-clear` to require argument (safety improvement)

## [1.0.0] - 2025-11-23

### Major Features

#### Browser Logging (NEW!)
- **Chrome DevTools Protocol Integration**: Automatically capture console logs, network requests, and JavaScript errors from Chromium-based browsers
- **Zero User Interaction**: Launch browser with logging enabled - no extensions or manual setup required
- **Comprehensive Capture**:
  - All `console.log()`, `console.warn()`, `console.error()` messages with source locations
  - Network requests and responses with headers, body, timing, and status codes
  - JavaScript errors with full stack traces
  - Performance timing information
- **Supported Browsers**: Chrome, Edge, Brave, Arc, Opera, Vivaldi, and all Chromium-based browsers
- **Commands**: `log-browser [name] [--preview|--silent|--browser=path]`
- **HAR Export**: Export network logs in standard HAR format for analysis (planned)

#### Centralized Project-Based Logging (NEW!)
- **Project Organization**: Optional centralized mode groups all logs by project in `~/auto-logger-logs/`
- **Auto Project Detection**: Project name automatically detected from current directory
- **Project Management**:
  - `log-centralize enable|disable|status` - Control centralized mode
  - `log-projects` - List all projects with stats (log count, size, last modified)
  - `log-projects <name>` - View logs for specific project
  - `log-projects <name> --clean` - Delete all logs for project
- **Benefits**: Keep personal/work projects separate, easy to find project-specific logs

#### npm Package Distribution (NEW!)
- **Global Installation**: `npm install -g auto-logger`
- **Automatic Setup**: Smart installer detects shell (bash/zsh) and configures automatically
- **Cross-Platform**: macOS, Linux, Windows (WSL/Git Bash)
- **Commands Available Globally**: All commands work from any directory after installation

### Added

#### CLI Logging
- Support for 100+ CLI tools including npm, docker, terraform, kubectl, vite, wrangler, prisma, and many more
- Manual logging mode (all commands to single log file)
- Auto-detection mode (smart per-command log files)
- Smart output formatting with 5 modes:
  - `default` - Raw output
  - `compact` - One-line summaries (perfect for wrangler tail)
  - `json` - Pretty-print JSON with colors
  - `silent` - No terminal output, only save to file
  - `timestamps` - Add timestamps to each line
- Hybrid logging (formatted terminal output + raw log files)
- Smart directory detection (./logs or ~/logs or centralized)

#### Commands
- **Core**: log-enable, log-disable, log-status, log-fmt, log-help
- **Utility**: log-list, log-view, log-clear, log-copy, log-run
- **Browser (NEW)**: log-browser [options]
- **Centralized (NEW)**: log-centralize, log-projects

#### Infrastructure
- Smart installer with shell detection (bash/zsh)
- Uninstaller for clean removal
- Config file management (`~/.auto-logger-config.json`)
- Path resolution with priority system
- Cross-platform clipboard support (macOS, Linux, Windows)

### Fixed

#### Command Output Visibility
- **PowerShell**: Fixed command output not displaying to console (removed variable assignment that captured but didn't show output)
- **Bash**: Added warning message when enabling logging in "silent" mode to alert users that output won't appear on screen

#### File Handling Improvements
- **`.log` Extension Handling**: log-view, log-copy, and log-clear now intelligently handle both forms:
  - `log-view apiworker` → works ✓
  - `log-view apiworker.log` → works ✓
  - Previously would look for `apiworker.log.log` when given `apiworker.log`
- **Absolute Paths**: log-list now shows full absolute paths (e.g., `/Users/.../logs/file.log`) instead of relative paths (`./logs/file.log`)
- **log-view Viewer**: Changed from `less` (vim-like pager) to `cat` for better piping support (`log-view file | grep error`)

#### Browser Logging Improvements
- **Response Logging**: Fixed browser network responses not being logged - now writes status/headers immediately, then appends body asynchronously
- **Network Filtering**: Added smart filtering to reduce log noise:
  - Filters static assets (.js, .css, images, fonts, Vite HMR)
  - Always logs API calls (POST/PUT/PATCH/DELETE), errors (4xx/5xx), and cross-origin requests
  - Reduces typical log from 300+ requests to ~15-20 meaningful entries
  - Statistics footer shows total/logged/filtered counts

### Supported Tool Categories
- Package Managers: npm, pnpm, yarn, bun, npx, pip, poetry, pipenv, composer, mvn, gradle, gem, mix, dotnet
- Build Tools: vite, webpack, esbuild, rollup, parcel, turbo, swc, tsc, tsup
- Testing Frameworks: jest, vitest, playwright, cypress, pytest, mocha, phpunit, rspec
- Cloud & Serverless: wrangler, vercel, netlify, railway, fly, render, aws, gcloud, az, pulumi, serverless, sst, amplify
- Containers: docker, docker-compose, podman, kubectl, helm, minikube, k9s, skaffold
- Databases & ORMs: psql, mysql, mongosh, redis-cli, sqlite3, prisma, supabase, drizzle-kit, sequelize, typeorm
- Linters & Formatters: eslint, prettier, biome, black, ruff, rustfmt, gofmt, rubocop
- Framework CLIs: next, nuxt, astro, remix, expo, ng, vue, rails, symfony, nx
- Infrastructure: terraform, ansible-playbook, vagrant
- Programming Languages: python, node, deno, go, cargo, flutter, ruby, php
- Other Dev Tools: make, cmake, gh, nodemon, ts-node, storybook, tailwindcss, sass, protoc, curl, wget

[1.1.0]: https://github.com/naorbrig/Auto-Logger/releases/tag/v1.1.0
[1.0.0]: https://github.com/naorbrig/Auto-Logger/releases/tag/v1.0.0
