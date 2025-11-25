#!/usr/bin/env node

/**
 * auto-logger uninstaller
 * Runs on npm uninstall to clean up
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');

const HOME = os.homedir();
const INSTALL_DIR = path.join(HOME, '.auto-logger');
const CONFIG_FILE = path.join(HOME, '.auto-logger-config.json');
const LOGS_DIR = path.join(HOME, 'logs');
const CENTRAL_LOGS_DIR = path.join(HOME, 'auto-logger-logs');

// List of all bin commands we create
const BIN_COMMANDS = [
  'log-enable', 'log-disable', 'log-status', 'log-fmt', 'log-append', 'log-filter',
  'log-list', 'log-view', 'log-clear', 'log-copy', 'log-help',
  'log-centralize', 'log-projects', 'log-run', 'log-browser', 'log-export-har'
];

/**
 * Remove source line from shell config
 */
function removeFromShellConfig(configFile) {
  if (!fs.existsSync(configFile)) {
    return;
  }

  const content = fs.readFileSync(configFile, 'utf8');
  const lines = content.split('\n');
  const filtered = lines.filter(line => {
    return !line.includes('auto-logger') && !line.includes('.auto-logger');
  });

  if (filtered.length !== lines.length) {
    fs.writeFileSync(configFile, filtered.join('\n'), 'utf8');
    console.log(`✓ Removed auto-logger from ${configFile}`);
  }
}

/**
 * Remove directory recursively
 */
function removeDirectory(dir) {
  if (!fs.existsSync(dir)) {
    return;
  }

  try {
    fs.rmSync(dir, { recursive: true, force: true });
    console.log(`✓ Removed: ${dir}`);
  } catch (err) {
    console.warn(`⚠ Failed to remove ${dir}: ${err.message}`);
  }
}

/**
 * Get npm global bin directory
 */
function getNpmBinDir() {
  const { execSync } = require('child_process');

  try {
    // Try to get npm prefix
    const prefix = execSync('npm config get prefix', { encoding: 'utf8' }).trim();

    // On macOS with Homebrew, npm is in /opt/homebrew
    // On Linux, it's usually /usr/local
    // On Windows, it's in AppData
    const binDir = path.join(prefix, 'bin');

    if (fs.existsSync(binDir)) {
      return binDir;
    }

    // Fallback for Windows
    if (process.platform === 'win32') {
      return prefix;
    }

    return null;
  } catch (err) {
    console.warn('⚠ Could not determine npm bin directory');
    return null;
  }
}

/**
 * Check if a symlink belongs to our package
 */
function isOurSymlink(symlinkPath) {
  try {
    if (!fs.existsSync(symlinkPath)) {
      return false;
    }

    const stats = fs.lstatSync(symlinkPath);
    if (!stats.isSymbolicLink()) {
      return false;
    }

    const target = fs.readlinkSync(symlinkPath);

    // Check if target contains our package name
    return target.includes('auto-logger') &&
           (target.includes('@naorbrig/auto-logger') ||
            target.includes('node_modules/auto-logger/'));
  } catch (err) {
    return false;
  }
}

/**
 * Remove bin symlinks safely
 */
function removeBinSymlinks() {
  const binDir = getNpmBinDir();

  if (!binDir) {
    console.warn('⚠ Skipping bin symlink cleanup (could not find npm bin directory)');
    return;
  }

  console.log(`Checking bin directory: ${binDir}`);

  let removedCount = 0;

  for (const command of BIN_COMMANDS) {
    const symlinkPath = path.join(binDir, command);

    if (isOurSymlink(symlinkPath)) {
      try {
        fs.unlinkSync(symlinkPath);
        console.log(`✓ Removed symlink: ${command}`);
        removedCount++;
      } catch (err) {
        console.warn(`⚠ Failed to remove ${command}: ${err.message}`);
      }
    }
  }

  if (removedCount > 0) {
    console.log(`✓ Removed ${removedCount} bin symlink(s)`);
  } else {
    console.log('No bin symlinks to remove');
  }
}

/**
 * Main uninstallation
 */
function uninstall() {
  console.log('');
  console.log('=== Uninstalling auto-logger ===');
  console.log('');

  try {
    // Remove bin symlinks first
    removeBinSymlinks();
    console.log('');

    // Remove from shell configs
    const configs = [
      path.join(HOME, '.bashrc'),
      path.join(HOME, '.zshrc')
    ];

    for (const config of configs) {
      removeFromShellConfig(config);
    }

    // Remove install directory
    removeDirectory(INSTALL_DIR);

    // Remove config file
    if (fs.existsSync(CONFIG_FILE)) {
      fs.unlinkSync(CONFIG_FILE);
      console.log(`✓ Removed config: ${CONFIG_FILE}`);
    }

    console.log('');
    console.log('=== Uninstallation Complete ===');
    console.log('');
    console.log('Note: Log files were NOT deleted:');
    console.log(`  - ${LOGS_DIR}`);
    console.log(`  - ${CENTRAL_LOGS_DIR}`);
    console.log('');
    console.log('To remove logs manually, run:');
    console.log(`  rm -rf ${LOGS_DIR}`);
    console.log(`  rm -rf ${CENTRAL_LOGS_DIR}`);
    console.log('');

  } catch (err) {
    console.error('');
    console.error('❌ Uninstallation failed:', err.message);
    console.error('');
    process.exit(1);
  }
}

// Run uninstaller
uninstall();
