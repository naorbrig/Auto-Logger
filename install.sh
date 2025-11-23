#!/bin/bash
# Installation script for auto-logger

set -e

echo "🔧 Installing auto-logger..."
echo ""

# Detect shell
SHELL_NAME=$(basename "$SHELL")
INSTALL_DIR="$HOME/.auto-logger"
RC_FILE=""

case "$SHELL_NAME" in
    bash)
        RC_FILE="$HOME/.bashrc"
        # On macOS, use .bash_profile if .bashrc doesn't exist
        if [[ "$OSTYPE" == "darwin"* ]] && [[ ! -f "$RC_FILE" ]]; then
            RC_FILE="$HOME/.bash_profile"
        fi
        ;;
    zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
    *)
        echo "⚠️  Unsupported shell: $SHELL_NAME"
        echo "Supported shells: bash, zsh"
        exit 1
        ;;
esac

echo "Detected shell: $SHELL_NAME"
echo "RC file: $RC_FILE"
echo ""

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Copy auto-logger script
cp auto-logger.sh "$INSTALL_DIR/auto-logger.sh"
chmod +x "$INSTALL_DIR/auto-logger.sh"

echo "✓ Copied auto-logger.sh to $INSTALL_DIR"

# Add source line to RC file if not already present
SOURCE_LINE="source \$HOME/.auto-logger/auto-logger.sh"

if grep -q "auto-logger.sh" "$RC_FILE" 2>/dev/null; then
    echo "✓ auto-logger already configured in $RC_FILE"
else
    echo "" >> "$RC_FILE"
    echo "# auto-logger - Automatic command logging" >> "$RC_FILE"
    echo "$SOURCE_LINE" >> "$RC_FILE"
    echo "✓ Added auto-logger to $RC_FILE"
fi

# Create logs directory
mkdir -p "$HOME/logs"
echo "✓ Created logs directory at $HOME/logs"

echo ""
echo "✅ Installation complete!"
echo ""
echo "To start using auto-logger, either:"
echo "  1. Restart your terminal"
echo "  2. Run: source $RC_FILE"
echo ""
echo "Quick start:"
echo "  log-enable frontend    # Enable logging to frontend.log"
echo "  npm run dev            # This will be logged"
echo "  log-disable            # Stop logging"
echo ""
echo "  log-enable auto        # Enable auto-detection mode"
echo "  npm run dev            # → logs/npm-dev.log"
echo "  wrangler tail          # → logs/wrangler-tail.log"
echo ""
echo "See README.md for more information."
