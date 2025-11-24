# auto-logger

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/naorbrig/Auto-Logger/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey.svg)](https://github.com/naorbrig/Auto-Logger)
[![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-green.svg)](https://github.com/naorbrig/Auto-Logger)

> **Automatic command logging for developers** – Capture CLI output from 100+ tools AND browser DevTools (console + network) and share logs instantly with AI assistants or your team.

Stop manually copying terminal output and F12 logs! auto-logger automatically saves your command logs AND browser debugging sessions, making them easy to share for debugging and collaboration.

## Features

### CLI Logging
- **🎯 100+ CLI Tools Supported**: npm, docker, terraform, kubectl, vite, wrangler, prisma, and many more
- **📋 One-Click Copy**: Copy log paths to clipboard instantly for sharing and analysis
- **🎨 Smart Formatting**: Clean terminal output with compact/JSON modes, raw logs saved for analysis
- **🔄 Two Modes**:
  - **Manual**: All commands → single log file
  - **Auto**: Smart per-command log files (e.g., `docker build` → `docker-build.log`)
- **👁️ Live Output**: See command output in terminal AND save to file simultaneously

### Browser Logging (NEW!)
- **🌐 Browser DevTools Capture**: Automatically capture console logs, network requests, and JavaScript errors
- **🔍 Zero User Interaction**: Launch browser with logging enabled - no extensions or manual setup
- **📡 Chrome DevTools Protocol**: Supports Chrome, Edge, Brave, and all Chromium-based browsers
- **💾 HAR Export**: Export network logs in standard HAR format for analysis
- **🎯 Perfect for Frontend Debugging**: Capture everything from F12 DevTools automatically

### Organization
- **📁 Centralized Project Logging**: Optional project-based organization (all logs grouped by project)
- **🗂️ Smart Directory Detection**: Auto-detects `./logs` folders or uses `~/logs`
- **📊 Project Management**: View all projects and their logs with `log-projects`

### Platform Support
- **🌍 Cross-platform**: macOS, Linux, Windows (PowerShell coming soon, WSL/Git Bash supported)
- **⚡ Zero Config**: Works immediately with sensible defaults

## Installation

### Via npm (Recommended)

```bash
npm install -g auto-logger
```

The installer will automatically:
- Set up shell integration (bash/zsh)
- Create log directories
- Configure commands globally

Then restart your terminal or run:
```bash
source ~/.bashrc  # or ~/.zshrc
```

### Manual Installation

```bash
git clone https://github.com/naorbrig/Auto-Logger.git
cd Auto-Logger
npm install
node scripts/install.js
```

## Quick Start

**New to auto-logger?** Run `log-help` in your terminal for a quick reference guide!

### Manual Mode (Single File)

```bash
# Enable logging - all commands go to logs/frontend.log
log-enable frontend

# Run your commands - everything is logged
npm run dev
npm test
curl localhost:3000

# Disable logging
log-disable
```

### Auto Mode (Smart Detection)

```bash
# Enable auto-detection mode
log-enable auto

# Each command gets its own log file
npm run dev          # → logs/npm-dev.log
npm start            # → logs/npm-start.log
wrangler tail        # → logs/wrangler-tail.log
python app.py        # → logs/python-app.log
flutter run          # → logs/flutter-run.log

# Disable logging
log-disable
```

### Browser Logging (NEW!)

Capture console logs, network requests, and errors from your web application:

```bash
# Start browser logging
log-browser

# → Chrome launches automatically
# → Navigate to your app (e.g., localhost:3000)
# → All console.log(), network requests, and errors are captured
# → Press Ctrl+C to stop and save logs

# Named session
log-browser debug-auth-flow
# → Saves to: logs/browser-debug-auth-flow.log

# View logs
log-copy browser-debug-auth-flow
# → Copy path to clipboard
```

**What gets captured:**
- All `console.log()`, `console.warn()`, `console.error()` messages
- Network requests and responses (with headers, body, timing)
- JavaScript errors with stack traces
- Performance timing

**Supported Browsers** (Chromium-based only):
- Google Chrome
- Microsoft Edge
- Brave Browser
- Arc
- Opera, Vivaldi, and any Chromium-based browser

*Note: Firefox and Safari use different protocols and are not supported.*

### Centralized Project Logging (NEW!)

Organize logs by project instead of scattered across directories:

```bash
# Enable centralized mode (one-time setup)
log-centralize enable

# Work on frontend project
cd ~/projects/my-app
log-enable frontend
npm run dev
# → Saves to: ~/auto-logger-logs/my-app/frontend.log

# Switch to backend project
cd ~/projects/api-server
log-enable backend
python app.py
# → Saves to: ~/auto-logger-logs/api-server/backend.log

# View all projects
log-projects
# Projects in ~/auto-logger-logs:
#   my-app         (3 logs, 8.2 MB, last: 5m ago)
#   api-server     (1 log, 2.1 MB, last: 10m ago)

# View logs for specific project
log-projects my-app
# Logs for my-app:
#   frontend.log              (2.3 MB, 5m ago)
#   npm-dev.log               (1.1 MB, 10m ago)
#   browser-session.log       (4.8 MB, 15m ago)
```

**Benefits:**
- All logs for a project in one place
- Project name auto-detected from directory
- Easy to find and share project-specific logs
- Keep personal and work projects separate

## Supported Commands (100+ Tools!)

auto-logger automatically detects and logs **100+ popular CLI tools**. Here are some examples organized by category:

### 📦 Package Managers
`npm` `pnpm` `yarn` `bun` `npx` `pip` `poetry` `pipenv` `composer` `mvn` `gradle` `gem` `mix` `dotnet`

**Examples:**
- `npm run dev` → `npm-dev.log`
- `pip install -r requirements.txt` → `pip-install.log`
- `poetry run dev` → `poetry-dev.log`

### 🛠️ Build Tools
`vite` `webpack` `esbuild` `rollup` `parcel` `turbo` `swc` `tsc` `tsup`

**Examples:**
- `vite dev` → `vite-dev.log`
- `webpack serve` → `webpack-serve.log`
- `turbo run build` → `turbo-build.log`

### 🧪 Testing Frameworks
`jest` `vitest` `playwright` `cypress` `pytest` `mocha` `phpunit` `rspec`

**Examples:**
- `vitest watch` → `vitest-watch.log`
- `playwright test` → `playwright-test.log`
- `pytest tests/` → `pytest-tests.log`

### ☁️ Cloud & Serverless
`wrangler` `vercel` `netlify` `railway` `fly` `render` `aws` `gcloud` `az` `pulumi` `serverless` `sst` `amplify`

**Examples:**
- `wrangler tail` → `wrangler-tail.log`
- `vercel dev` → `vercel-dev.log`
- `aws s3 sync` → `aws-s3-sync.log`

### 🐳 Containers & Orchestration
`docker` `docker-compose` `podman` `kubectl` `helm` `minikube` `k9s` `skaffold`

**Examples:**
- `docker build .` → `docker-build.log`
- `docker-compose up` → `docker-compose-up.log`
- `kubectl get pods` → `kubectl-get-pods.log`

### 🗄️ Databases & ORMs
`psql` `mysql` `mongosh` `redis-cli` `sqlite3` `prisma` `supabase` `drizzle-kit` `sequelize` `typeorm`

**Examples:**
- `prisma migrate dev` → `prisma-migrate-dev.log`
- `supabase start` → `supabase-start.log`
- `psql -d mydb` → `psql.log`

### ✨ Linters & Formatters
`eslint` `prettier` `biome` `black` `ruff` `rustfmt` `gofmt` `rubocop`

**Examples:**
- `biome check` → `biome-check.log`
- `eslint --fix` → `eslint-fix.log`
- `ruff format` → `ruff-format.log`

### ⚡ Framework CLIs
`next` `nuxt` `astro` `remix` `expo` `ng` `vue` `rails` `symfony` `nx`

**Examples:**
- `next dev` → `next-dev.log`
- `astro build` → `astro-build.log`
- `ng serve` → `ng-serve.log`

### 🏗️ Infrastructure as Code
`terraform` `ansible-playbook` `vagrant`

**Examples:**
- `terraform apply` → `terraform-apply.log`
- `ansible-playbook deploy.yml` → `ansible-playbook-deploy.log`

### 💻 Programming Languages
`python` `node` `deno` `go` `cargo` `flutter` `ruby` `php`

**Examples:**
- `python app.py` → `python-app.log`
- `node server.js` → `node-server.log`
- `cargo run` → `cargo-run.log`

### 🔧 Other Dev Tools
`make` `cmake` `gh` `nodemon` `ts-node` `storybook` `tailwindcss` `sass` `protoc` `curl` `wget`

**Examples:**
- `gh pr list` → `gh-pr-list.log`
- `make build` → `make-build.log`
- `nodemon app.js` → `nodemon-app.log`

**✨ New tools are automatically supported!** If a command isn't listed, auto-logger will still create a log file using the pattern `command-subcommand.log`.

## Commands

### Core Commands

- `log-help` - Show complete help with examples
- `log-enable <name|auto>` - Enable logging (CLI commands)
- `log-disable` - Disable logging
- `log-status` - Show current logging status
- `log-fmt <format>` - Set output display format

### Browser Logging Commands (NEW!)

- `log-browser [name]` - Launch browser with logging enabled
- `log-browser --preview` - Show logs in terminal while capturing
- `log-browser --silent` - No terminal output, only save to file

### Centralized Mode Commands (NEW!)

- `log-centralize enable` - Enable centralized project-based logging
- `log-centralize disable` - Disable centralized mode (use default)
- `log-centralize status` - Show current mode and directory
- `log-projects` - List all projects with logs
- `log-projects <name>` - List logs for specific project
- `log-projects <name> --clean` - Delete all logs for project

### Formatting Options

Control how output appears in your terminal while keeping raw logs intact:

- `log-fmt default` - Raw output (no formatting)
- `log-fmt compact` - One-line summaries (perfect for wrangler tail)
- `log-fmt json` - Pretty-print JSON with colors
- `log-fmt silent` - No terminal output, only save to file
- `log-fmt timestamps` - Add timestamps to each line

**How it works:**
- Terminal display uses your chosen format (clean and readable)
- Log files ALWAYS contain raw unmodified output (complete data for analysis)

### Utility Commands

- `log-list` - List recent log files
- `log-view <name>` - View a log file with less
- `log-clear [name]` - Clear a specific log or all logs
- `log-copy [name]` - Copy log file path to clipboard
- `log-run <command>` - Manually wrap a command for logging

## Examples

### Frontend Development Session

```bash
# Start logging frontend work
log-enable frontend

# All these go to logs/frontend.log
npm install
npm run dev
npm test
curl http://localhost:3000/api/users

# Done
log-disable
```

### Backend Development with Auto-Detection

```bash
# Enable auto mode
log-enable auto

# Each gets its own file
python manage.py runserver  # → logs/python-manage.log
wrangler tail               # → logs/wrangler-tail.log
curl localhost:8000/health  # → logs/curl-localhost.log

# Check what's been logged
log-list

# View a specific log
log-view python-manage
```

### Debugging a Specific Issue

```bash
# Log debugging session
log-enable debug-api-error

# Run tests and debugging commands
npm test
npm run dev
curl -X POST localhost:3000/api/test

# Check the log
log-view debug-api-error

# Clear when done
log-clear debug-api-error
```

### Clean Output with Formatting

```bash
# Monitor wrangler with clean compact output
log-enable auto
log-fmt compact

wrangler tail
# Terminal shows clean output:
# [14:30:45] GET /api/auth/verify-org → 200 (328ms)
# [14:30:46] GET /api/auth-methods/org-methods → 200 (144ms)

# But the log file has FULL JSON details!
log-copy wrangler-tail
# Share the complete logs with your team or AI assistants
```

```bash
# Silent mode for long-running processes
log-enable backend
log-fmt silent

npm run dev &
# No terminal spam, everything saved to logs/backend.log
```

```bash
# Pretty JSON for API responses
log-enable auto
log-fmt json

curl https://api.example.com/data
# Terminal shows pretty-formatted JSON with colors
# Log file has raw JSON for processing
```

### Share Logs with AI Assistants

```bash
# Enable logging
log-enable frontend

# Run your commands
npm run dev
# ... errors occur ...

# Copy the log path to clipboard
log-copy
# 📋 Copied to clipboard: /Users/you/project/app/logs/frontend.log

# Now paste the path in your AI assistant to analyze the logs!
```

Or with auto mode:

```bash
log-enable auto
npm run build
# Build fails...

# Copy specific log path (absolute path)
log-copy npm-build
# 📋 Copied to clipboard: /Users/you/project/app/logs/npm-build.log
```

## Log Format

Each log entry includes:

```
=== Log started at 2025-11-23 14:30:45 ===
Command: npm run dev
---
[command output here]
---
=== Log ended at 2025-11-23 14:32:10 (exit code: 0) ===
```

## Configuration

### Log Directory (Smart Auto-Detection)

auto-logger **automatically detects** where to save logs:

1. **If `./logs` exists in current directory** → Use it (per-project logs)
2. **Otherwise** → Use `~/logs` (global logs)

**Examples:**

```bash
# Project A with logs folder
cd ~/project/my-app
mkdir logs              # Create logs folder
log-enable frontend
npm run dev             # → ./logs/frontend.log

# Project B without logs folder
cd ~/project/another-app
log-enable backend
python app.py           # → ~/logs/backend.log (global)
```

### Custom Logs Directory

Override auto-detection by setting `AUTO_LOGGER_DIR`:

```bash
# Add to your ~/.bashrc or ~/.zshrc
export AUTO_LOGGER_DIR="$HOME/my-custom-logs"

# Or set per-session
export AUTO_LOGGER_DIR="/tmp/logs"
log-enable test
```

## How It Works

When you enable logging, auto-logger creates shell functions that wrap common commands. These functions:

1. Determine the log file based on mode (manual or auto)
2. Write a session header with timestamp and command
3. Execute the command with `tee` to show output AND save to file
4. Write a session footer with timestamp and exit code

The log file is **overwritten** each time you run `log-enable`, but each command run appends a new session to the file.

## Troubleshooting

### Commands not being logged

Make sure you've enabled logging:
```bash
log-status
```

If disabled, enable it:
```bash
log-enable auto
```

### Can't find log files

Check the logs directory:
```bash
log-list
```

Or check where logs are being saved:
```bash
log-status
```

### Shell function conflicts

If you have custom functions for commands (like npm, python), they may conflict. You can:

1. Rename your functions
2. Use `log-run` to manually wrap commands:
   ```bash
   log-run npm run dev
   ```

## Uninstall

```bash
# Remove from shell RC file
# Edit ~/.bashrc or ~/.zshrc and remove the auto-logger lines

# Remove installation directory
rm -rf ~/.auto-logger

# Optionally remove logs
rm -rf ~/logs
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to:
- Report bugs by [opening an issue](https://github.com/naorbrig/Auto-Logger/issues)
- Suggest new features
- Submit pull requests

## Links

- **GitHub Repository**: https://github.com/naorbrig/Auto-Logger
- **Report Issues**: https://github.com/naorbrig/Auto-Logger/issues
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)

## Credits

Created with [Claude Code](https://claude.com/claude-code)
