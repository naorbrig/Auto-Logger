#!/usr/bin/env node

/**
 * Helper script for bash/PowerShell to resolve log paths
 * Usage: resolve-path.js <filename>
 * Outputs: full path to log file
 */

const pathResolver = require('../lib/path-resolver');

const filename = process.argv[2];

if (!filename) {
  console.error('Usage: resolve-path.js <filename>');
  process.exit(1);
}

// Resolve and print the path
const logPath = pathResolver.resolveLogPath(filename);
console.log(logPath);
