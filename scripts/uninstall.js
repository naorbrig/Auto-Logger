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
 * Main uninstallation
 */
function uninstall() {
  console.log('');
  console.log('=== Uninstalling auto-logger ===');
  console.log('');

  try {
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
