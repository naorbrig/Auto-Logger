# auto-logger Project

## Overview

A shell-based automatic logging tool that captures command output to files with manual toggle and smart auto-detection.

## Project Structure

```
auto-logger/
├── auto-logger.sh      # Main shell script with all logging functions
├── install.sh          # Installation script
├── uninstall.sh        # Uninstallation script
├── example.sh          # Usage examples/demo
├── test.sh             # Test script
├── README.md           # User documentation
├── PROJECT.md          # This file
├── .gitignore          # Git ignore rules
└── logs/               # Default logs directory (created on first use)
```

## Features Implemented

### Core Functionality
- ✅ Manual mode (single named log file)
- ✅ Auto mode (smart filename detection)
- ✅ Live output + file logging (using tee)
- ✅ Session headers with timestamps
- ✅ Exit code tracking

### Supported Commands
- ✅ npm, pnpm, yarn, bun (package managers)
- ✅ wrangler (Cloudflare)
- ✅ python, node, deno, go, cargo, flutter, ruby, php (languages)
- ✅ curl, wget (HTTP tools)
- ✅ Extensible pattern matching system

### Commands
- ✅ `log-enable <name|auto>` - Enable logging
- ✅ `log-disable` - Disable logging
- ✅ `log-status` - Show status
- ✅ `log-list` - List recent logs
- ✅ `log-view <name>` - View log file
- ✅ `log-clear [name]` - Clear logs
- ✅ `log-path [name]` - Copy log path to clipboard (cross-platform)
- ✅ `log-run <cmd>` - Manual wrapper

### Platform Support
- ✅ macOS (bash/zsh)
- ✅ Linux (bash/zsh)
- ✅ Windows WSL/Git Bash
- ✅ Clipboard support (pbcopy/xclip/xsel/clip.exe)

## Technical Details

### How It Works

1. **Logging Toggle**: Sets environment variables and creates shell functions
2. **Command Interception**: Wraps common commands with logging function
3. **Output Capture**: Uses `tee` to show output and save to file
4. **Pattern Detection**: Smart filename generation based on command structure
5. **Cleanup**: Removes function overrides when disabled

### Log File Format

```
=== Log started at 2025-11-23 14:30:45 ===
Command: npm run dev
---
[command output]
---
=== Log ended at 2025-11-23 14:32:10 (exit code: 0) ===
```

## Installation

```bash
cd auto-logger
./install.sh
```

This will:
1. Copy script to `~/.auto-logger/`
2. Add source line to shell RC file
3. Create `~/logs` directory

## Usage

### Quick Start

```bash
# Manual mode
log-enable frontend
npm run dev
log-disable

# Auto mode
log-enable auto
npm run dev          # → logs/npm-dev.log
wrangler tail        # → logs/wrangler-tail.log
log-disable

# Copy path to share with Claude Code
log-path frontend
```

## Configuration

### Environment Variables

- `AUTO_LOGGER_DIR` - Logs directory (default: `~/logs`)
- `AUTO_LOGGER_ENABLED` - Enable flag (0 or 1)
- `AUTO_LOGGER_MODE` - Mode (manual or auto)
- `AUTO_LOGGER_NAME` - Current log name (manual mode)

### Customization

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export AUTO_LOGGER_DIR="$HOME/my-logs"
```

## Development

### Adding New Command Patterns

Edit `_auto_logger_get_filename()` in `auto-logger.sh`:

```bash
case "$main_cmd" in
    mynewcmd)
        filename="${main_cmd}-${first_arg}.log"
        ;;
```

### Adding New Commands to Intercept

Edit `_auto_logger_setup_aliases()`:

```bash
mynewcmd() { _auto_logger_exec mynewcmd "$@"; }
```

## Testing

```bash
./test.sh
```

## Future Enhancements

Potential features to add:
- [ ] Log rotation (keep last N sessions)
- [ ] Timestamped files option (append date to filename)
- [ ] Log filtering/search command
- [ ] Compression of old logs
- [ ] Git integration (auto-log during git operations)
- [ ] JSON output format option
- [ ] Remote log upload (to S3, etc.)
- [ ] Interactive log selection for log-path

## Troubleshooting

See README.md for common issues and solutions.

## License

MIT

## Author

Created for streamlined development workflow with Claude Code.
