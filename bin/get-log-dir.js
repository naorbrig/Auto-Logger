#!/usr/bin/env node

/**
 * Helper script for bash/PowerShell to get log directory
 * Usage: get-log-dir.js
 * Outputs: path to log directory
 */

const pathResolver = require('../lib/path-resolver');

// Get and print the log directory
const logDir = pathResolver.getLogDirectory();
console.log(logDir);
