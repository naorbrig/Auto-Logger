#!/bin/bash
# Uninstallation script for auto-logger

set -e

echo "🗑️  Uninstalling auto-logger..."
echo ""

# Detect shell RC file
SHELL_NAME=$(basename "$SHELL")
RC_FILE=""

case "$SHELL_NAME" in
    bash)
        RC_FILE="$HOME/.bashrc"
        if [[ "$OSTYPE" == "darwin"* ]] && [[ ! -f "$RC_FILE" ]]; then
            RC_FILE="$HOME/.bash_profile"
        fi
        ;;
    zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
    *)
        echo "⚠️  Unsupported shell: $SHELL_NAME"
        RC_FILE=""
        ;;
esac

# Remove from RC file
if [[ -f "$RC_FILE" ]]; then
    # Create backup
    cp "$RC_FILE" "${RC_FILE}.backup"
    echo "✓ Created backup: ${RC_FILE}.backup"

    # Remove auto-logger lines
    sed -i.tmp '/# auto-logger/,/auto-logger.sh/d' "$RC_FILE"
    rm -f "${RC_FILE}.tmp"
    echo "✓ Removed auto-logger from $RC_FILE"
fi

# Remove installation directory
if [[ -d "$HOME/.auto-logger" ]]; then
    rm -rf "$HOME/.auto-logger"
    echo "✓ Removed $HOME/.auto-logger"
fi

# Ask about logs directory
if [[ -d "$HOME/logs" ]]; then
    echo ""
    read -p "Remove logs directory ($HOME/logs)? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/logs"
        echo "✓ Removed $HOME/logs"
    else
        echo "ℹ️  Kept logs directory"
    fi
fi

echo ""
echo "✅ Uninstallation complete!"
echo ""
echo "Please restart your terminal or run:"
echo "  source $RC_FILE"
