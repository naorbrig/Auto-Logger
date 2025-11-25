#!/usr/bin/env node

/**
 * auto-logger - Main CLI router
 * Routes commands to appropriate handlers
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const centralManager = require('../lib/centralized-manager');

// Get the command that was used to invoke this script
const invokedCommand = path.basename(process.argv[1]);
const args = process.argv.slice(2);

/**
 * Get shell script path based on platform
 */
function getShellScript() {
  const platform = process.platform;

  if (platform === 'win32') {
    // Windows - try PowerShell first, fall back to bash (WSL/Git Bash)
    const psScript = path.join(__dirname, '../scripts/auto-logger.ps1');
    if (fs.existsSync(psScript)) {
      return { script: psScript, shell: 'powershell' };
    }
  }

  // Unix/macOS or Windows fallback
  const bashScript = path.join(__dirname, '../scripts/auto-logger.sh');
  return { script: bashScript, shell: 'bash' };
}

/**
 * Execute shell command
 */
function execShellCommand(command, args) {
  const { script, shell } = getShellScript();

  // Source the script and run the command
  let shellCmd;
  let shellArgs;

  if (shell === 'powershell') {
    shellCmd = 'powershell';
    shellArgs = ['-NoProfile', '-File', script, command, ...args];
  } else {
    shellCmd = 'bash';
    shellArgs = ['-c', `source "${script}" && ${command} ${args.join(' ')}`];
  }

  const proc = spawn(shellCmd, shellArgs, {
    stdio: 'inherit',
    shell: false
  });

  proc.on('exit', (code) => {
    process.exit(code || 0);
  });
}

/**
 * Handle centralize command
 */
function handleCentralize() {
  const subcommand = args[0];

  switch (subcommand) {
    case 'enable':
      if (centralManager.enableCentralizedMode()) {
        console.log('✓ Centralized logging enabled');
        console.log(`→ All logs will be saved to: ${centralManager.getCentralDirectory()}/{project-name}/`);
        console.log('');
        console.log('Projects will be auto-detected from your current directory name.');
        console.log('Use log-projects to view all projects.');
      } else {
        console.error('❌ Failed to enable centralized mode');
        process.exit(1);
      }
      break;

    case 'disable':
      if (centralManager.disableCentralizedMode()) {
        console.log('✓ Centralized logging disabled');
        console.log('→ Using default mode (./logs or ~/logs)');
      } else {
        console.error('❌ Failed to disable centralized mode');
        process.exit(1);
      }
      break;

    case 'status':
      const config = centralManager.getConfig();
      console.log(`Centralized logging: ${config.centralizedMode ? 'enabled' : 'disabled'}`);
      console.log(`Central directory: ${config.centralDirectory}`);

      if (config.centralizedMode) {
        const projectName = centralManager.getProjectName();
        const projectDir = centralManager.getProjectDirectory();
        console.log(`Current project: ${projectName}`);
        console.log(`Logs location: ${projectDir}`);
      }
      break;

    default:
      console.error('Usage: log-centralize <enable|disable|status>');
      console.error('');
      console.error('Commands:');
      console.error('  enable   Enable centralized project-based logging');
      console.error('  disable  Disable centralized mode (use default)');
      console.error('  status   Show current centralized mode status');
      process.exit(1);
  }
}

/**
 * Route command to appropriate handler
 */
function route() {
  // Special case: if invoked as log-centralize
  if (invokedCommand === 'log-centralize' || args[0] === 'centralize') {
    // Remove 'centralize' from args if present
    if (args[0] === 'centralize') {
      args.shift();
    }
    handleCentralize();
    return;
  }

  // Special case: if invoked as log-projects
  if (invokedCommand === 'log-projects' || args[0] === 'projects') {
    // Delegate to log-projects.js
    const logProjects = path.join(__dirname, 'log-projects.js');
    const proc = spawn('node', [logProjects, ...args.slice(args[0] === 'projects' ? 1 : 0)], {
      stdio: 'inherit'
    });
    proc.on('exit', (code) => process.exit(code || 0));
    return;
  }

  // Special case: browser logging
  if (invokedCommand === 'log-browser' || (invokedCommand === 'log-enable' && args[0] === 'browser')) {
    // Delegate to log-browser.js
    const logBrowser = path.join(__dirname, 'log-browser.js');
    // If invoked as log-browser, pass all args; if log-enable browser, skip 'browser'
    const browserArgs = invokedCommand === 'log-browser' ? args : args.slice(1);
    const proc = spawn('node', [logBrowser, ...browserArgs], {
      stdio: 'inherit'
    });
    proc.on('exit', (code) => process.exit(code || 0));
    return;
  }

  // Map command names to shell function names
  const commandMap = {
    'log-enable': 'log-enable',
    'log-disable': 'log-disable',
    'log-status': 'log-status',
    'log-fmt': 'log-fmt',
    'log-append': 'log-append',
    'log-filter': 'log-filter',
    'log-list': 'log-list',
    'log-view': 'log-view',
    'log-clear': 'log-clear',
    'log-copy': 'log-copy',
    'log-help': 'log-help',
    'log-run': 'log-run'
  };

  const shellCommand = commandMap[invokedCommand];

  if (!shellCommand) {
    console.error(`Unknown command: ${invokedCommand}`);
    console.error('Try: log-help');
    process.exit(1);
  }

  // Execute shell command
  execShellCommand(shellCommand, args);
}

// Run
route();
