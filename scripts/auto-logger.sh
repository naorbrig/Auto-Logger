#!/bin/bash
# auto-logger.sh - Automatic command logging with manual toggle and auto-detection
# Version: 1.0.0

# Configuration
export AUTO_LOGGER_ENABLED=0
export AUTO_LOGGER_MODE=""
export AUTO_LOGGER_NAME=""
export AUTO_LOGGER_FORMAT="${AUTO_LOGGER_FORMAT:-default}"

# Get log directory using smart resolution
# Priority: 1) Centralized mode, 2) AUTO_LOGGER_DIR, 3) ./logs, 4) ~/logs
_auto_logger_get_dir() {
    # Try to use Node.js helper if available
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local helper="$script_dir/bin/get-log-dir.js"

    if [[ -x "$helper" ]] && command -v node &> /dev/null; then
        node "$helper" 2>/dev/null || echo "$HOME/logs"
    elif [[ -n "$AUTO_LOGGER_DIR" ]]; then
        echo "$AUTO_LOGGER_DIR"
    elif [[ -d "./logs" ]]; then
        echo "./logs"
    else
        echo "$HOME/logs"
    fi
}

# Ensure logs directory exists
_auto_logger_init() {
    local logdir=$(_auto_logger_get_dir)
    if [[ ! -d "$logdir" ]]; then
        mkdir -p "$logdir"
    fi

    # Convert to absolute path if relative
    if [[ ! "$logdir" = /* ]]; then
        logdir="$(cd "$logdir" 2>/dev/null && pwd)" || logdir="$HOME/logs"
    fi

    export AUTO_LOGGER_DIR="$logdir"
}

# Generate log filename based on command
_auto_logger_get_filename() {
    local cmd="$1"
    local filename=""

    # Extract the main command and first argument
    local main_cmd=$(echo "$cmd" | awk '{print $1}')
    local first_arg=$(echo "$cmd" | awk '{print $2}')

    case "$main_cmd" in
        npm|pnpm|yarn|bun)
            # npm run dev -> npm-dev.log
            # npm start -> npm-start.log
            if [[ "$first_arg" == "run" ]]; then
                local script_name=$(echo "$cmd" | awk '{print $3}')
                filename="${main_cmd}-${script_name}.log"
            else
                filename="${main_cmd}-${first_arg}.log"
            fi
            ;;
        npx)
            # npx vite -> npx-vite.log
            filename="${main_cmd}-${first_arg}.log"
            ;;
        wrangler)
            # wrangler tail -> wrangler-tail.log
            # wrangler dev -> wrangler-dev.log
            filename="${main_cmd}-${first_arg}.log"
            ;;
        python|python3)
            # python app.py -> python-app.log
            local script=$(basename "$first_arg" .py 2>/dev/null || echo "script")
            filename="python-${script}.log"
            ;;
        node)
            # node server.js -> node-server.log
            local script=$(basename "$first_arg" .js 2>/dev/null || echo "script")
            filename="node-${script}.log"
            ;;
        flutter)
            # flutter run -> flutter-run.log
            filename="${main_cmd}-${first_arg}.log"
            ;;
        cargo)
            # cargo run -> cargo-run.log
            filename="${main_cmd}-${first_arg}.log"
            ;;
        go)
            # go run main.go -> go-run.log
            filename="${main_cmd}-${first_arg}.log"
            ;;
        deno)
            # deno run app.ts -> deno-run.log
            filename="${main_cmd}-${first_arg}.log"
            ;;
        ruby)
            # ruby app.rb -> ruby-app.log
            local script=$(basename "$first_arg" .rb 2>/dev/null || echo "script")
            filename="ruby-${script}.log"
            ;;
        php)
            # php index.php -> php-index.log
            local script=$(basename "$first_arg" .php 2>/dev/null || echo "script")
            filename="php-${script}.log"
            ;;

        # Build tools
        vite|webpack|esbuild|rollup|parcel|turbo|swc|tsc|tsup)
            filename="${main_cmd}-${first_arg}.log"
            ;;

        # Testing frameworks
        jest|vitest|playwright|cypress|pytest|mocha|phpunit|rspec)
            filename="${main_cmd}-${first_arg}.log"
            ;;

        # Cloud platforms
        vercel|netlify|railway|render)
            filename="${main_cmd}-${first_arg}.log"
            ;;
        fly|flyctl)
            filename="${main_cmd}-${first_arg}.log"
            ;;
        aws|gcloud|az)
            # aws s3 sync -> aws-s3-sync.log
            local second_arg=$(echo "$cmd" | awk '{print $3}')
            if [[ -n "$second_arg" && "$second_arg" != -* ]]; then
                filename="${main_cmd}-${first_arg}-${second_arg}.log"
            else
                filename="${main_cmd}-${first_arg}.log"
            fi
            ;;
        pulumi|serverless|sst|amplify)
            filename="${main_cmd}-${first_arg}.log"
            ;;

        # Containers/orchestration
        docker)
            filename="${main_cmd}-${first_arg}.log"
            ;;
        docker-compose)
            filename="docker-compose-${first_arg}.log"
            ;;
        podman|kubectl|helm|minikube|k9s|skaffold)
            filename="${main_cmd}-${first_arg}.log"
            ;;

        # Databases
        psql|mysql|mongosh|redis-cli|sqlite3)
            filename="${main_cmd}.log"
            ;;
        prisma|supabase)
            # prisma migrate dev -> prisma-migrate-dev.log
            local second_arg=$(echo "$cmd" | awk '{print $3}')
            if [[ -n "$second_arg" && "$second_arg" != -* ]]; then
                filename="${main_cmd}-${first_arg}-${second_arg}.log"
            else
                filename="${main_cmd}-${first_arg}.log"
            fi
            ;;
        drizzle-kit|sequelize|typeorm)
            filename="${main_cmd}-${first_arg}.log"
            ;;

        # Linters/formatters
        eslint|prettier|biome|black|ruff|rustfmt|gofmt|rubocop)
            filename="${main_cmd}-${first_arg}.log"
            ;;

        # Package managers (extend)
        pip|pip3|poetry|pipenv|composer)
            filename="${main_cmd}-${first_arg}.log"
            ;;
        mvn|maven|gradle|gem|mix|dotnet)
            filename="${main_cmd}-${first_arg}.log"
            ;;

        # Framework CLIs
        next|nuxt|astro|remix|expo)
            filename="${main_cmd}-${first_arg}.log"
            ;;
        ng|vue)
            # ng serve -> ng-serve.log
            filename="${main_cmd}-${first_arg}.log"
            ;;
        rails|symfony)
            filename="${main_cmd}-${first_arg}.log"
            ;;
        nx)
            # nx run dev -> nx-run-dev.log or nx-run.log
            filename="${main_cmd}-${first_arg}.log"
            ;;

        # Infrastructure
        terraform)
            filename="${main_cmd}-${first_arg}.log"
            ;;
        ansible-playbook)
            # ansible-playbook deploy.yml -> ansible-playbook-deploy.log
            local playbook=$(basename "$first_arg" .yml 2>/dev/null || basename "$first_arg" .yaml 2>/dev/null || echo "$first_arg")
            filename="ansible-playbook-${playbook}.log"
            ;;
        vagrant)
            filename="${main_cmd}-${first_arg}.log"
            ;;

        # Version control
        gh)
            # gh pr list -> gh-pr-list.log
            # gh issue create -> gh-issue-create.log
            local second_arg=$(echo "$cmd" | awk '{print $3}')
            if [[ -n "$second_arg" && "$second_arg" != -* ]]; then
                filename="${main_cmd}-${first_arg}-${second_arg}.log"
            else
                filename="${main_cmd}-${first_arg}.log"
            fi
            ;;

        # Other dev tools
        make|cmake)
            filename="${main_cmd}-${first_arg}.log"
            ;;
        nodemon|ts-node)
            local script=$(basename "$first_arg" | sed 's/\.[^.]*$//' 2>/dev/null || echo "script")
            filename="${main_cmd}-${script}.log"
            ;;
        storybook|tailwindcss|sass|protoc)
            filename="${main_cmd}-${first_arg}.log"
            ;;

        *)
            # Default: command-arg.log or just command.log
            if [[ -n "$first_arg" && "$first_arg" != -* ]]; then
                filename="${main_cmd}-${first_arg}.log"
            else
                filename="${main_cmd}.log"
            fi
            ;;
    esac

    echo "$filename"
}

# Enable logging
log-enable() {
    _auto_logger_init

    if [[ $# -eq 0 ]]; then
        echo "Usage: log-enable <name|auto>"
        echo "  log-enable frontend  - All commands log to logs/frontend.log"
        echo "  log-enable auto      - Auto-detect log filename per command"
        return 1
    fi

    local mode="$1"

    if [[ "$mode" == "auto" ]]; then
        export AUTO_LOGGER_ENABLED=1
        export AUTO_LOGGER_MODE="auto"
        export AUTO_LOGGER_NAME=""
        _auto_logger_setup_aliases
        echo "📝 Auto-logging enabled → $AUTO_LOGGER_DIR/<command>.log"
    else
        export AUTO_LOGGER_ENABLED=1
        export AUTO_LOGGER_MODE="manual"
        export AUTO_LOGGER_NAME="$mode"
        _auto_logger_setup_aliases
        echo "📝 Logging enabled → $AUTO_LOGGER_DIR/${mode}.log"
    fi

    # Warn if in silent mode
    if [[ "$AUTO_LOGGER_FORMAT" == "silent" ]]; then
        echo "⚠️  Format is set to 'silent' - command output will NOT appear on screen"
        echo "   Run 'log-fmt default' to see output while logging"
    fi
}

# Disable logging
log-disable() {
    export AUTO_LOGGER_ENABLED=0
    export AUTO_LOGGER_MODE=""
    export AUTO_LOGGER_NAME=""
    _auto_logger_remove_aliases
    echo "✓ Logging disabled"
}

# Show current logging status
log-status() {
    if [[ $AUTO_LOGGER_ENABLED -eq 1 ]]; then
        if [[ "$AUTO_LOGGER_MODE" == "auto" ]]; then
            echo "📝 Auto-logging is ENABLED"
            echo "   Mode: Auto-detection"
            echo "   Directory: $AUTO_LOGGER_DIR"
        else
            echo "📝 Logging is ENABLED"
            echo "   Mode: Manual"
            echo "   File: $AUTO_LOGGER_DIR/${AUTO_LOGGER_NAME}.log"
        fi
        echo "   Format: $AUTO_LOGGER_FORMAT"
    else
        echo "✗ Logging is DISABLED"
    fi
}

# Set output format
log-fmt() {
    if [[ $# -eq 0 ]]; then
        echo "Current format: $AUTO_LOGGER_FORMAT"
        echo ""
        echo "Usage: log-fmt <format>"
        echo "  default    - Raw output (no formatting)"
        echo "  compact    - One-line summaries"
        echo "  json       - Pretty-print JSON"
        echo "  silent     - No terminal output, only file"
        echo "  timestamps - Add timestamps to each line"
        return 1
    fi

    local format="$1"
    case "$format" in
        default|compact|json|silent|timestamps)
            export AUTO_LOGGER_FORMAT="$format"
            echo "📋 Output format set to: $format"
            ;;
        *)
            echo "⚠️  Invalid format: $format"
            echo "Valid formats: default, compact, json, silent, timestamps"
            return 1
            ;;
    esac
}

# Format output for terminal display
_auto_logger_format_output() {
    local format="$1"

    case "$format" in
        silent)
            # No terminal output
            cat > /dev/null
            ;;
        compact)
            # Compact format - try to extract key info
            while IFS= read -r line; do
                # Check if it's JSON (wrangler tail format)
                if echo "$line" | jq -e . >/dev/null 2>&1; then
                    # Extract timestamp, method, URL, status from JSON
                    local timestamp=$(echo "$line" | jq -r '.eventTimestamp // empty' 2>/dev/null)
                    local method=$(echo "$line" | jq -r '.event.request.method // empty' 2>/dev/null)
                    local url=$(echo "$line" | jq -r '.event.request.url // empty' 2>/dev/null | sed 's/https\?:\/\/[^/]*//')
                    local status=$(echo "$line" | jq -r '.event.response.status // empty' 2>/dev/null)
                    local wall_time=$(echo "$line" | jq -r '.wallTime // empty' 2>/dev/null)

                    if [[ -n "$method" && -n "$url" ]]; then
                        local time_str=""
                        if [[ -n "$timestamp" ]]; then
                            time_str="[$(date -r "$((timestamp / 1000))" '+%H:%M:%S' 2>/dev/null || echo "$timestamp")]"
                        fi
                        printf "%s %s %s → %s (%sms)\n" "$time_str" "$method" "$url" "${status:-?}" "${wall_time:-?}"
                    else
                        # Not a recognizable format, show first 100 chars
                        echo "$line" | cut -c1-100
                    fi
                else
                    # Not JSON, show as-is
                    echo "$line"
                fi
            done
            ;;
        json)
            # Pretty-print JSON
            while IFS= read -r line; do
                if echo "$line" | jq -e . >/dev/null 2>&1; then
                    echo "$line" | jq -C .
                else
                    echo "$line"
                fi
            done
            ;;
        timestamps)
            # Add timestamps to each line
            while IFS= read -r line; do
                printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$line"
            done
            ;;
        default|*)
            # No formatting, pass through
            cat
            ;;
    esac
}

# Generic command logger
_auto_logger_exec() {
    local cmd_name="$1"
    shift
    local full_cmd="$cmd_name $*"
    local logfile=""

    if [[ "$AUTO_LOGGER_MODE" == "auto" ]]; then
        local filename=$(_auto_logger_get_filename "$full_cmd")
        logfile="$AUTO_LOGGER_DIR/$filename"
    else
        logfile="$AUTO_LOGGER_DIR/${AUTO_LOGGER_NAME}.log"
    fi

    # Write session header
    {
        echo ""
        echo "=== Log started at $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "Command: $full_cmd"
        echo "---"
    } >> "$logfile"

    # Execute command with hybrid logging
    # Raw output goes to file, formatted output goes to terminal
    if [[ "$AUTO_LOGGER_FORMAT" == "default" ]]; then
        # Default: simple tee (same as before)
        command "$cmd_name" "$@" 2>&1 | tee -a "$logfile"
        local exit_code=${PIPESTATUS[0]}
    else
        # Hybrid: raw to file, formatted to terminal
        # Use process substitution to split the stream
        command "$cmd_name" "$@" 2>&1 | tee -a "$logfile" | _auto_logger_format_output "$AUTO_LOGGER_FORMAT"
        local exit_code=${PIPESTATUS[0]}
    fi

    # Write session footer
    {
        echo "---"
        echo "=== Log ended at $(date '+%Y-%m-%d %H:%M:%S') (exit code: $exit_code) ==="
        echo ""
    } >> "$logfile"

    return $exit_code
}

# Setup command aliases/functions
_auto_logger_setup_aliases() {
    # Package managers
    npm() { _auto_logger_exec npm "$@"; }
    pnpm() { _auto_logger_exec pnpm "$@"; }
    yarn() { _auto_logger_exec yarn "$@"; }
    bun() { _auto_logger_exec bun "$@"; }
    npx() { _auto_logger_exec npx "$@"; }
    pip() { _auto_logger_exec pip "$@"; }
    pip3() { _auto_logger_exec pip3 "$@"; }
    poetry() { _auto_logger_exec poetry "$@"; }
    pipenv() { _auto_logger_exec pipenv "$@"; }
    composer() { _auto_logger_exec composer "$@"; }
    mvn() { _auto_logger_exec mvn "$@"; }
    maven() { _auto_logger_exec maven "$@"; }
    gradle() { _auto_logger_exec gradle "$@"; }
    gem() { _auto_logger_exec gem "$@"; }
    mix() { _auto_logger_exec mix "$@"; }
    dotnet() { _auto_logger_exec dotnet "$@"; }

    # Build tools
    wrangler() { _auto_logger_exec wrangler "$@"; }
    vite() { _auto_logger_exec vite "$@"; }
    webpack() { _auto_logger_exec webpack "$@"; }
    esbuild() { _auto_logger_exec esbuild "$@"; }
    rollup() { _auto_logger_exec rollup "$@"; }
    parcel() { _auto_logger_exec parcel "$@"; }
    turbo() { _auto_logger_exec turbo "$@"; }
    swc() { _auto_logger_exec swc "$@"; }
    tsc() { _auto_logger_exec tsc "$@"; }
    tsup() { _auto_logger_exec tsup "$@"; }

    # Testing frameworks
    jest() { _auto_logger_exec jest "$@"; }
    vitest() { _auto_logger_exec vitest "$@"; }
    playwright() { _auto_logger_exec playwright "$@"; }
    cypress() { _auto_logger_exec cypress "$@"; }
    pytest() { _auto_logger_exec pytest "$@"; }
    mocha() { _auto_logger_exec mocha "$@"; }
    phpunit() { _auto_logger_exec phpunit "$@"; }
    rspec() { _auto_logger_exec rspec "$@"; }

    # Cloud platforms
    vercel() { _auto_logger_exec vercel "$@"; }
    netlify() { _auto_logger_exec netlify "$@"; }
    railway() { _auto_logger_exec railway "$@"; }
    fly() { _auto_logger_exec fly "$@"; }
    flyctl() { _auto_logger_exec flyctl "$@"; }
    render() { _auto_logger_exec render "$@"; }
    aws() { _auto_logger_exec aws "$@"; }
    gcloud() { _auto_logger_exec gcloud "$@"; }
    az() { _auto_logger_exec az "$@"; }
    pulumi() { _auto_logger_exec pulumi "$@"; }
    serverless() { _auto_logger_exec serverless "$@"; }
    sst() { _auto_logger_exec sst "$@"; }
    amplify() { _auto_logger_exec amplify "$@"; }

    # Containers
    docker() { _auto_logger_exec docker "$@"; }
    docker-compose() { _auto_logger_exec docker-compose "$@"; }
    podman() { _auto_logger_exec podman "$@"; }
    kubectl() { _auto_logger_exec kubectl "$@"; }
    helm() { _auto_logger_exec helm "$@"; }
    minikube() { _auto_logger_exec minikube "$@"; }
    k9s() { _auto_logger_exec k9s "$@"; }
    skaffold() { _auto_logger_exec skaffold "$@"; }

    # Databases
    psql() { _auto_logger_exec psql "$@"; }
    mysql() { _auto_logger_exec mysql "$@"; }
    mongosh() { _auto_logger_exec mongosh "$@"; }
    redis-cli() { _auto_logger_exec redis-cli "$@"; }
    sqlite3() { _auto_logger_exec sqlite3 "$@"; }
    prisma() { _auto_logger_exec prisma "$@"; }
    supabase() { _auto_logger_exec supabase "$@"; }
    drizzle-kit() { _auto_logger_exec drizzle-kit "$@"; }
    sequelize() { _auto_logger_exec sequelize "$@"; }
    typeorm() { _auto_logger_exec typeorm "$@"; }

    # Linters/formatters
    eslint() { _auto_logger_exec eslint "$@"; }
    prettier() { _auto_logger_exec prettier "$@"; }
    biome() { _auto_logger_exec biome "$@"; }
    black() { _auto_logger_exec black "$@"; }
    ruff() { _auto_logger_exec ruff "$@"; }
    rustfmt() { _auto_logger_exec rustfmt "$@"; }
    gofmt() { _auto_logger_exec gofmt "$@"; }
    rubocop() { _auto_logger_exec rubocop "$@"; }

    # Framework CLIs
    next() { _auto_logger_exec next "$@"; }
    nuxt() { _auto_logger_exec nuxt "$@"; }
    astro() { _auto_logger_exec astro "$@"; }
    remix() { _auto_logger_exec remix "$@"; }
    expo() { _auto_logger_exec expo "$@"; }
    ng() { _auto_logger_exec ng "$@"; }
    vue() { _auto_logger_exec vue "$@"; }
    rails() { _auto_logger_exec rails "$@"; }
    symfony() { _auto_logger_exec symfony "$@"; }
    nx() { _auto_logger_exec nx "$@"; }

    # Languages
    python() { _auto_logger_exec python "$@"; }
    python3() { _auto_logger_exec python3 "$@"; }
    node() { _auto_logger_exec node "$@"; }
    deno() { _auto_logger_exec deno "$@"; }
    go() { _auto_logger_exec go "$@"; }
    cargo() { _auto_logger_exec cargo "$@"; }
    flutter() { _auto_logger_exec flutter "$@"; }
    ruby() { _auto_logger_exec ruby "$@"; }
    php() { _auto_logger_exec php "$@"; }

    # Infrastructure
    terraform() { _auto_logger_exec terraform "$@"; }
    ansible-playbook() { _auto_logger_exec ansible-playbook "$@"; }
    vagrant() { _auto_logger_exec vagrant "$@"; }

    # Version control
    gh() { _auto_logger_exec gh "$@"; }

    # Other dev tools
    make() { _auto_logger_exec make "$@"; }
    cmake() { _auto_logger_exec cmake "$@"; }
    nodemon() { _auto_logger_exec nodemon "$@"; }
    ts-node() { _auto_logger_exec ts-node "$@"; }
    storybook() { _auto_logger_exec storybook "$@"; }
    tailwindcss() { _auto_logger_exec tailwindcss "$@"; }
    sass() { _auto_logger_exec sass "$@"; }
    protoc() { _auto_logger_exec protoc "$@"; }
    curl() { _auto_logger_exec curl "$@"; }
    wget() { _auto_logger_exec wget "$@"; }
}

# Remove aliases/functions
_auto_logger_remove_aliases() {
    # Package managers
    unset -f npm pnpm yarn bun npx pip pip3 poetry pipenv composer mvn maven gradle gem mix dotnet 2>/dev/null
    # Build tools
    unset -f wrangler vite webpack esbuild rollup parcel turbo swc tsc tsup 2>/dev/null
    # Testing
    unset -f jest vitest playwright cypress pytest mocha phpunit rspec 2>/dev/null
    # Cloud
    unset -f vercel netlify railway fly flyctl render aws gcloud az pulumi serverless sst amplify 2>/dev/null
    # Containers
    unset -f docker docker-compose podman kubectl helm minikube k9s skaffold 2>/dev/null
    # Databases
    unset -f psql mysql mongosh redis-cli sqlite3 prisma supabase drizzle-kit sequelize typeorm 2>/dev/null
    # Linters
    unset -f eslint prettier biome black ruff rustfmt gofmt rubocop 2>/dev/null
    # Frameworks
    unset -f next nuxt astro remix expo ng vue rails symfony nx 2>/dev/null
    # Languages
    unset -f python python3 node deno go cargo flutter ruby php 2>/dev/null
    # Infrastructure
    unset -f terraform ansible-playbook vagrant 2>/dev/null
    # Version control
    unset -f gh 2>/dev/null
    # Other tools
    unset -f make cmake nodemon ts-node storybook tailwindcss sass protoc curl wget 2>/dev/null
}

# Manual wrapper for any command
log-run() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: log-run <command> [args...]"
        echo "Example: log-run npm run dev"
        return 1
    fi

    if [[ $AUTO_LOGGER_ENABLED -eq 0 ]]; then
        echo "⚠️  Logging is disabled. Enable it first with: log-enable <name|auto>"
        return 1
    fi

    _auto_logger_exec "$@"
}

# List recent logs
log-list() {
    _auto_logger_init
    echo "Recent logs in $AUTO_LOGGER_DIR:"
    echo ""
    if [[ -d "$AUTO_LOGGER_DIR" ]]; then
        ls -lht "$AUTO_LOGGER_DIR"/*.log 2>/dev/null | head -10 || echo "No logs found"
    else
        echo "No logs directory found"
    fi
}

# View a log file
log-view() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: log-view <logname>"
        echo "Example: log-view frontend"
        return 1
    fi

    # Strip .log extension if present, then add it
    local logname="${1%.log}"
    local logfile="$AUTO_LOGGER_DIR/${logname}.log"
    if [[ -f "$logfile" ]]; then
        cat "$logfile"
    else
        echo "Log file not found: $logfile"
        return 1
    fi
}

# Clear a specific log or all logs
log-clear() {
    if [[ $# -eq 0 ]]; then
        read -p "Clear all logs in $AUTO_LOGGER_DIR? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$AUTO_LOGGER_DIR"/*.log
            echo "✓ All logs cleared"
        fi
    else
        # Strip .log extension if present, then add it
        local logname="${1%.log}"
        local logfile="$AUTO_LOGGER_DIR/${logname}.log"
        if [[ -f "$logfile" ]]; then
            rm "$logfile"
            echo "✓ Cleared ${logname}.log"
        else
            echo "Log file not found: $logfile"
            return 1
        fi
    fi
}

# Copy log file path to clipboard
log-copy() {
    local logfile=""

    if [[ $# -eq 0 ]]; then
        # No argument - try to find most recent log
        if [[ $AUTO_LOGGER_ENABLED -eq 1 ]]; then
            # Logging is active - use current log
            if [[ "$AUTO_LOGGER_MODE" == "auto" ]]; then
                echo "⚠️  Auto mode is active. Specify which log file:"
                log-list
                echo ""
                echo "Usage: log-copy <logname>"
                return 1
            else
                logfile="$AUTO_LOGGER_DIR/${AUTO_LOGGER_NAME}.log"
            fi
        else
            # Logging is disabled - find most recent browser session or log
            # Try browser sessions first (directories starting with browser-)
            local recent_browser=$(ls -td "$AUTO_LOGGER_DIR"/browser-* 2>/dev/null | head -1)
            if [[ -n "$recent_browser" && -d "$recent_browser" ]]; then
                logfile="$recent_browser"
            else
                # Fall back to most recent .log file
                local recent_log=$(ls -t "$AUTO_LOGGER_DIR"/*.log 2>/dev/null | head -1)
                if [[ -n "$recent_log" ]]; then
                    logfile="$recent_log"
                else
                    echo "⚠️  No logs found in $AUTO_LOGGER_DIR"
                    echo "Usage: log-copy [logname]"
                    return 1
                fi
            fi
        fi
    else
        # Specific log name provided
        # Check if it's a directory (browser session) or a file
        if [[ -d "$AUTO_LOGGER_DIR/$1" ]]; then
            logfile="$AUTO_LOGGER_DIR/$1"
        else
            # Strip .log extension if present, then add it
            local logname="${1%.log}"
            logfile="$AUTO_LOGGER_DIR/${logname}.log"
        fi
    fi

    # Check if file or directory exists
    if [[ ! -e "$logfile" ]]; then
        echo "⚠️  Log not found: $logfile"
        echo "Available logs:"
        log-list
        return 1
    fi

    # Detect clipboard command based on platform
    local clip_cmd=""
    if command -v pbcopy &> /dev/null; then
        # macOS
        clip_cmd="pbcopy"
    elif command -v xclip &> /dev/null; then
        # Linux with xclip
        clip_cmd="xclip -selection clipboard"
    elif command -v xsel &> /dev/null; then
        # Linux with xsel
        clip_cmd="xsel --clipboard --input"
    elif command -v clip.exe &> /dev/null; then
        # Windows (WSL)
        clip_cmd="clip.exe"
    else
        echo "⚠️  No clipboard command found"
        echo "Install: pbcopy (macOS), xclip/xsel (Linux), or use WSL"
        echo ""
        echo "Path: $logfile"
        return 1
    fi

    # Convert to absolute path
    local absolute_path
    if [[ "$logfile" = /* ]]; then
        # Already absolute
        absolute_path="$logfile"
    else
        # Convert relative to absolute
        if [[ -d "$logfile" ]]; then
            # It's a directory
            absolute_path="$(cd "$logfile" 2>/dev/null && pwd)"
        else
            # It's a file
            absolute_path="$(cd "$(dirname "$logfile")" 2>/dev/null && pwd)/$(basename "$logfile")"
        fi
    fi

    # Copy to clipboard (add trailing slash for directories)
    if [[ -d "$absolute_path" ]]; then
        echo -n "${absolute_path}/" | eval $clip_cmd
        echo "📋 Copied to clipboard: ${absolute_path}/"
    else
        echo -n "$absolute_path" | eval $clip_cmd
        echo "📋 Copied to clipboard: $absolute_path"
    fi
}

# Show help
log-help() {
    cat << 'EOF'
auto-logger - Automatic CLI & Browser Logging

CORE COMMANDS:
  log-enable <name|auto>          Enable CLI logging
                                  - log-enable frontend       (all commands → frontend.log)
                                  - log-enable auto           (auto-detect files)

  log-disable                     Disable logging

  log-status                      Show current logging status

  log-fmt <format>                Set output display format
                                  - default, compact, json, silent, timestamps

BROWSER LOGGING (NEW!):
  log-browser [name]              Launch Chrome with DevTools Protocol logging
                                  - Captures console.log(), network requests, errors
                                  - Zero setup required - no extensions!
                                  - Press Ctrl+C to stop and save

  Example:
    log-browser my-app
    # Chrome opens → navigate to localhost:3000
    # All console & network activity captured
    # Press Ctrl+C to save logs

CENTRALIZED MODE (NEW!):
  log-centralize enable           Enable project-based logging
  log-centralize disable          Disable centralized mode
  log-centralize status           Show current mode

  log-projects                    List all projects with logs
  log-projects <name>             List logs for specific project
  log-projects <name> --clean     Delete all logs for project

UTILITY COMMANDS:
  log-list                List recent log files
  log-view <name>         View a log file
  log-copy [name]         Copy log path to clipboard
  log-clear [name]        Clear specific log or all logs
  log-help                Show this help

QUICK START (CLI):
  log-enable frontend     # Start logging to frontend.log
  npm run dev             # Your commands are logged
  log-copy                # Copy log path to clipboard
  log-disable             # Stop logging

QUICK START (Browser):
  log-browser             # Launches Chrome with logging
  # Navigate to your app, debug normally
  # Press Ctrl+C to stop
  log-copy                # Share with Claude Code

EXAMPLES:
  # CLI logging - Manual mode
  log-enable frontend
  npm run dev
  wrangler tail
  # Everything → logs/frontend.log

  # CLI logging - Auto mode
  log-enable auto
  npm run dev       # → logs/npm-dev.log
  wrangler tail     # → logs/wrangler-tail.log

  # Browser logging
  log-browser debug-auth
  # Chrome opens, navigate to localhost:3000
  # Test your auth flow
  # Ctrl+C when done → logs/browser-debug-auth.log

  # Centralized project organization
  log-centralize enable
  cd ~/projects/my-app
  log-enable frontend
  # Saves to: ~/auto-logger-logs/my-app/frontend.log
  log-projects my-app  # View all logs for this project

CONFIGURATION:
  Logs directory: Smart auto-detection
    - If centralized mode: ~/auto-logger-logs/{project-name}/
    - If ./logs exists → use it (per-project)
    - Otherwise → use ~/logs (global)

  Override: export AUTO_LOGGER_DIR="/custom/path"

For full documentation, see:
  https://github.com/naor64/Auto-Logger
EOF
}

# Centralized logging mode control
log-centralize() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local cli_tool="$script_dir/bin/auto-logger.js"

    if [[ -x "$cli_tool" ]] && command -v node &> /dev/null; then
        node "$cli_tool" centralize "$@"
    else
        echo "Error: Node.js CLI tool not found or Node.js not installed"
        echo "Please ensure auto-logger is properly installed via npm"
        return 1
    fi
}

# Initialize logger on load
_auto_logger_init

echo "✓ auto-logger loaded"
echo "  Commands: log-enable, log-disable, log-status, log-fmt, log-list, log-view, log-clear, log-copy, log-help"
echo "           log-centralize, log-projects"
echo "  Logs directory: $AUTO_LOGGER_DIR"
echo "  Type 'log-help' for usage info"
