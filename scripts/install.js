#!/usr/bin/env node

/**
 * auto-logger installer
 * Runs on npm postinstall to set up shell integration
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const HOME = os.homedir();
const INSTALL_DIR = path.join(HOME, '.auto-logger');
const CONFIG_FILE = path.join(HOME, '.auto-logger-config.json');
const LOGS_DIR = path.join(HOME, 'logs');
const CENTRAL_LOGS_DIR = path.join(HOME, 'auto-logger-logs');

/**
 * Detect shell type
 */
function detectShell() {
  const platform = process.platform;

  if (platform === 'win32') {
    // Windows - check if PowerShell is available
    try {
      execSync('powershell -v', { stdio: 'ignore' });
      return { type: 'powershell', configFile: null }; // PowerShell $PROFILE is dynamic
    } catch (err) {
      // Fall back to bash (WSL/Git Bash)
      const bashrc = path.join(HOME, '.bashrc');
      return { type: 'bash', configFile: bashrc };
    }
  }

  // Unix/macOS - detect bash or zsh
  const shell = process.env.SHELL || '';

  if (shell.includes('zsh')) {
    return { type: 'zsh', configFile: path.join(HOME, '.zshrc') };
  } else {
    return { type: 'bash', configFile: path.join(HOME, '.bashrc') };
  }
}

/**
 * Copy script file to install directory
 */
function copyScript(shellType) {
  const scriptName = shellType === 'powershell' ? 'auto-logger.ps1' : 'auto-logger.sh';
  const source = path.join(__dirname, scriptName);
  const dest = path.join(INSTALL_DIR, scriptName);

  // Check if source exists
  if (!fs.existsSync(source)) {
    if (shellType === 'powershell') {
      console.warn(`⚠ PowerShell script not found: ${source}`);
      console.warn('  PowerShell support coming soon. Using bash for WSL/Git Bash.');
      return copyScript('bash');
    }
    throw new Error(`Source script not found: ${source}`);
  }

  fs.copyFileSync(source, dest);
  return scriptName;
}

/**
 * Add source line to shell config file
 */
function addToShellConfig(shellType, configFile, scriptName) {
  const scriptPath = path.join(INSTALL_DIR, scriptName);

  if (shellType === 'powershell') {
    console.log('ℹ PowerShell detected');
    console.log('  To enable auto-logger in PowerShell, add this to your $PROFILE:');
    console.log(`  . "${scriptPath}"`);
    console.log('');
    console.log('  Or run: notepad $PROFILE');
    return;
  }

  // Bash/Zsh - add source line
  const sourceLine = `source "${scriptPath}"`;

  // Check if config file exists
  if (!fs.existsSync(configFile)) {
    console.log(`Creating ${configFile}...`);
    fs.writeFileSync(configFile, '', 'utf8');
  }

  // Check if already added
  const content = fs.readFileSync(configFile, 'utf8');
  if (content.includes(scriptPath) || content.includes('auto-logger')) {
    console.log(`✓ auto-logger already configured in ${configFile}`);
    return;
  }

  // Append source line
  const newContent = content + `\n# auto-logger\n${sourceLine}\n`;
  fs.writeFileSync(configFile, newContent, 'utf8');
  console.log(`✓ Added auto-logger to ${configFile}`);
}

/**
 * Create directories
 */
function createDirectories() {
  const dirs = [INSTALL_DIR, LOGS_DIR, CENTRAL_LOGS_DIR];

  for (const dir of dirs) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
      console.log(`✓ Created directory: ${dir}`);
    }
  }
}

/**
 * Create default config
 */
function createConfig() {
  if (fs.existsSync(CONFIG_FILE)) {
    console.log(`✓ Config file already exists: ${CONFIG_FILE}`);
    return;
  }

  const defaultConfig = {
    centralizedMode: false,
    centralDirectory: CENTRAL_LOGS_DIR,
    version: '1.0.0'
  };

  fs.writeFileSync(CONFIG_FILE, JSON.stringify(defaultConfig, null, 2), 'utf8');
  console.log(`✓ Created config file: ${CONFIG_FILE}`);
}

/**
 * Main installation
 */
function install() {
  console.log('');
  console.log('=== Installing auto-logger ===');
  console.log('');

  try {
    // Create directories
    createDirectories();

    // Detect shell
    const shell = detectShell();
    console.log(`✓ Detected shell: ${shell.type}`);

    // Copy script
    const scriptName = copyScript(shell.type);
    console.log(`✓ Copied ${scriptName} to ${INSTALL_DIR}`);

    // Add to shell config
    if (shell.configFile) {
      addToShellConfig(shell.type, shell.configFile, scriptName);
    }

    // Create config
    createConfig();

    console.log('');
    console.log('=== Installation Complete ===');
    console.log('');
    console.log('Next steps:');

    if (shell.type === 'powershell') {
      console.log('  1. Add auto-logger to your PowerShell $PROFILE (see instructions above)');
      console.log('  2. Restart PowerShell');
    } else {
      console.log(`  1. Restart your terminal or run: source ${shell.configFile}`);
    }

    console.log('  2. Run: log-help');
    console.log('');
    console.log('Documentation: https://github.com/naorbrig/Auto-Logger');
    console.log('');

  } catch (err) {
    console.error('');
    console.error('❌ Installation failed:', err.message);
    console.error('');
    console.error('Please report this issue at:');
    console.error('https://github.com/naorbrig/Auto-Logger/issues');
    console.error('');
    process.exit(1);
  }
}

// Run installer
install();
