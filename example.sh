#!/bin/bash
# Example usage of auto-logger
# This script demonstrates how auto-logger works

echo "📝 auto-logger Demo"
echo "==================="
echo ""

# Source the auto-logger script
source ./auto-logger.sh

echo ""
echo "1️⃣  Testing Manual Mode"
echo "----------------------"
echo "$ log-enable demo"
log-enable demo

echo ""
echo "$ echo 'Hello from manual mode'"
echo "Hello from manual mode"

echo ""
echo "$ log-status"
log-status

echo ""
echo "$ log-disable"
log-disable

echo ""
echo "2️⃣  Testing Auto Mode"
echo "--------------------"
echo "$ log-enable auto"
log-enable auto

echo ""
echo "Simulating commands (not actually running to avoid dependencies):"
echo "  npm run dev → would log to logs/npm-dev.log"
echo "  python app.py → would log to logs/python-app.log"
echo "  wrangler tail → would log to logs/wrangler-tail.log"

echo ""
echo "$ log-status"
log-status

echo ""
echo "$ log-disable"
log-disable

echo ""
echo "3️⃣  Utility Commands"
echo "-------------------"
echo "$ log-list"
log-list

echo ""
echo "Demo complete! ✨"
echo ""
echo "To use auto-logger:"
echo "  1. Run ./install.sh to install"
echo "  2. Restart your terminal"
echo "  3. Use log-enable, log-disable, etc."
echo ""
echo "See README.md for full documentation"
