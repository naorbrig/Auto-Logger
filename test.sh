#!/bin/bash
# Quick test script for auto-logger

set -e

echo "🧪 Testing auto-logger..."
echo ""

# Source the script
source ./auto-logger.sh

# Test 1: Manual mode
echo "Test 1: Manual mode"
echo "-------------------"
log-enable test
echo "Test output 123" > /dev/null
sleep 1
log-status
log-disable
echo "✓ Manual mode works"
echo ""

# Test 2: Auto mode
echo "Test 2: Auto mode"
echo "-----------------"
log-enable auto
log-status
log-disable
echo "✓ Auto mode works"
echo ""

# Test 3: log-path (if clipboard available)
echo "Test 3: log-path"
echo "----------------"
# Create a test log
mkdir -p "$HOME/logs"
echo "test" > "$HOME/logs/test.log"

if command -v pbcopy &> /dev/null || command -v xclip &> /dev/null || command -v xsel &> /dev/null; then
    log-path test
    echo "✓ log-path works (check clipboard)"
else
    echo "⚠️  No clipboard utility found (install pbcopy/xclip/xsel)"
fi
echo ""

# Test 4: log-list
echo "Test 4: log-list"
echo "----------------"
log-list
echo "✓ log-list works"
echo ""

echo "✅ All tests passed!"
