#!/usr/bin/env node

/**
 * Browser logging CLI wrapper
 * Handles log-enable browser and related commands
 */

const BrowserLogger = require('../lib/browser-logger');
const pathResolver = require('../lib/path-resolver');
const path = require('path');

/**
 * Show help
 */
function showHelp() {
  console.log(`
Usage: log-browser [name] [options]

Start browser logging with Chrome DevTools Protocol.
Captures console logs, network requests, and JavaScript errors.
Creates a directory with separate log files for console and network activity.

Arguments:
  name                Session name (optional, generates timestamp if not provided)

Options:
  --preview           Show logs in terminal in addition to file
  --silent            No terminal output, only save to file
  --format=FORMAT     Output format (default, json)
  --browser=PATH      Path to Chrome/Chromium executable

Examples:
  log-browser
  # Launches Chrome and starts logging
  # Saves to: logs/browser-2025-11-23-14-30-45/
  #   - console.log  (console messages)
  #   - network.log  (network requests & responses)

  log-browser debug-session
  # Named session
  # Saves to: logs/browser-debug-session/
  #   - console.log
  #   - network.log

  log-browser --preview
  # Show logs in terminal while capturing

Supported Browsers (Chromium-based only):
  - Google Chrome
  - Microsoft Edge
  - Brave Browser
  - Arc
  - Any Chromium-based browser

Note: Firefox and Safari are not supported (different protocols).

After starting, navigate to your application and debug.
Press Ctrl+C to stop logging and close browser.
`);
}

/**
 * Generate log directory name
 */
function generateLogDirName(name) {
  if (name) {
    return `browser-${name}`;
  }

  // Generate timestamp-based directory name
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  const hour = String(now.getHours()).padStart(2, '0');
  const minute = String(now.getMinutes()).padStart(2, '0');
  const second = String(now.getSeconds()).padStart(2, '0');

  return `browser-${year}-${month}-${day}-${hour}-${minute}-${second}`;
}

/**
 * Parse command line arguments
 */
function parseArgs(args) {
  const options = {
    name: null,
    preview: false,
    silent: false,
    format: 'default',
    browserPath: null
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if (arg === '--help' || arg === '-h') {
      showHelp();
      process.exit(0);
    } else if (arg === '--preview') {
      options.preview = true;
    } else if (arg === '--silent') {
      options.silent = true;
    } else if (arg.startsWith('--format=')) {
      options.format = arg.split('=')[1];
    } else if (arg.startsWith('--browser=')) {
      options.browserPath = arg.split('=')[1];
    } else if (!arg.startsWith('--')) {
      // Assume it's the session name
      options.name = arg;
    }
  }

  return options;
}

/**
 * Main function
 */
async function main() {
  const args = process.argv.slice(2);

  // Parse arguments
  const options = parseArgs(args);

  // Generate log directory name
  const dirname = generateLogDirName(options.name);
  const logDir = pathResolver.resolveLogPath(dirname);

  // Create browser logger
  const logger = new BrowserLogger({
    logDir,
    browserPath: options.browserPath,
    preview: options.preview && !options.silent,
    format: options.format
  });

  // Handle Ctrl+C
  process.on('SIGINT', async () => {
    console.log('');
    console.log('Stopping browser logging...');
    await logger.stop();
    process.exit(0);
  });

  // Handle uncaught errors
  process.on('uncaughtException', async (err) => {
    console.error('');
    console.error(`❌ Error: ${err.message}`);
    if (logger.browser) {
      await logger.stop();
    }
    process.exit(1);
  });

  // Start logging
  try {
    await logger.start();

    // Keep process alive
    await new Promise(() => {});

  } catch (err) {
    console.error(`❌ Failed to start browser logging: ${err.message}`);
    console.error('');
    console.error('Make sure you have Chrome, Edge, or Brave installed.');
    console.error('Or specify browser path with: --browser=/path/to/chrome');
    process.exit(1);
  }
}

// Run
main().catch(err => {
  console.error(`❌ Fatal error: ${err.message}`);
  process.exit(1);
});
