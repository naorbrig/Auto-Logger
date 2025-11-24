#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

// Config file location
const CONFIG_FILE = path.join(os.homedir(), '.auto-logger-config.json');
const DEFAULT_CENTRAL_DIR = path.join(os.homedir(), 'auto-logger-logs');

/**
 * Get config from ~/.auto-logger-config.json
 * Creates default config if doesn't exist
 */
function getConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      const data = fs.readFileSync(CONFIG_FILE, 'utf8');
      return JSON.parse(data);
    }
  } catch (err) {
    // Ignore errors, return default
  }

  // Return default config
  return {
    centralizedMode: false,
    centralDirectory: DEFAULT_CENTRAL_DIR,
    version: '1.0.0'
  };
}

/**
 * Save config to ~/.auto-logger-config.json
 */
function saveConfig(config) {
  try {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2), 'utf8');
    return true;
  } catch (err) {
    console.error(`Error saving config: ${err.message}`);
    return false;
  }
}

/**
 * Check if centralized mode is enabled
 */
function isCentralizedMode() {
  const config = getConfig();
  return config.centralizedMode === true;
}

/**
 * Enable centralized mode
 */
function enableCentralizedMode() {
  const config = getConfig();
  config.centralizedMode = true;

  // Ensure central directory exists
  if (!fs.existsSync(config.centralDirectory)) {
    fs.mkdirSync(config.centralDirectory, { recursive: true });
  }

  return saveConfig(config);
}

/**
 * Disable centralized mode
 */
function disableCentralizedMode() {
  const config = getConfig();
  config.centralizedMode = false;
  return saveConfig(config);
}

/**
 * Get central directory path
 */
function getCentralDirectory() {
  const config = getConfig();
  return config.centralDirectory || DEFAULT_CENTRAL_DIR;
}

/**
 * Set custom central directory
 */
function setCentralDirectory(dir) {
  const config = getConfig();
  config.centralDirectory = path.resolve(dir);

  // Create directory if doesn't exist
  if (!fs.existsSync(config.centralDirectory)) {
    fs.mkdirSync(config.centralDirectory, { recursive: true });
  }

  return saveConfig(config);
}

/**
 * Get current project name from directory
 * Sanitizes the name to be filesystem-safe
 */
function getProjectName() {
  const cwd = process.cwd();
  const projectName = path.basename(cwd);
  return sanitizeProjectName(projectName);
}

/**
 * Sanitize project name for use in filesystem
 * - Replace spaces with dashes
 * - Remove special characters
 * - Lowercase
 */
function sanitizeProjectName(name) {
  return name
    .toLowerCase()
    .replace(/\s+/g, '-')           // Replace spaces with dashes
    .replace(/[^a-z0-9\-_]/g, '')   // Remove special chars
    .replace(/--+/g, '-')           // Replace multiple dashes with single
    .replace(/^-+|-+$/g, '');       // Remove leading/trailing dashes
}

/**
 * Get project directory path in centralized location
 */
function getProjectDirectory(projectName) {
  const centralDir = getCentralDirectory();
  const name = projectName || getProjectName();
  return path.join(centralDir, name);
}

/**
 * Ensure project directory exists
 */
function ensureProjectDirectory(projectName) {
  const projectDir = getProjectDirectory(projectName);
  if (!fs.existsSync(projectDir)) {
    fs.mkdirSync(projectDir, { recursive: true });
  }
  return projectDir;
}

/**
 * List all projects in centralized location
 * Returns array of project objects with stats
 */
function listProjects() {
  const centralDir = getCentralDirectory();

  if (!fs.existsSync(centralDir)) {
    return [];
  }

  try {
    const entries = fs.readdirSync(centralDir, { withFileTypes: true });
    const projects = [];

    for (const entry of entries) {
      if (entry.isDirectory()) {
        const projectPath = path.join(centralDir, entry.name);
        const stats = getProjectStats(projectPath);

        projects.push({
          name: entry.name,
          path: projectPath,
          logCount: stats.logCount,
          totalSize: stats.totalSize,
          lastModified: stats.lastModified
        });
      }
    }

    // Sort by last modified (newest first)
    projects.sort((a, b) => b.lastModified - a.lastModified);

    return projects;
  } catch (err) {
    console.error(`Error listing projects: ${err.message}`);
    return [];
  }
}

/**
 * Get stats for a project directory
 */
function getProjectStats(projectPath) {
  let logCount = 0;
  let totalSize = 0;
  let lastModified = 0;

  try {
    const files = fs.readdirSync(projectPath);

    for (const file of files) {
      if (file.endsWith('.log') || file.endsWith('.har')) {
        const filePath = path.join(projectPath, file);
        const stat = fs.statSync(filePath);

        logCount++;
        totalSize += stat.size;

        if (stat.mtimeMs > lastModified) {
          lastModified = stat.mtimeMs;
        }
      }
    }
  } catch (err) {
    // Ignore errors
  }

  return { logCount, totalSize, lastModified };
}

/**
 * List log files for a specific project
 */
function listProjectLogs(projectName) {
  const projectPath = getProjectDirectory(projectName);

  if (!fs.existsSync(projectPath)) {
    return [];
  }

  try {
    const files = fs.readdirSync(projectPath);
    const logs = [];

    for (const file of files) {
      if (file.endsWith('.log') || file.endsWith('.har')) {
        const filePath = path.join(projectPath, file);
        const stat = fs.statSync(filePath);

        logs.push({
          name: file,
          path: filePath,
          size: stat.size,
          modified: stat.mtimeMs
        });
      }
    }

    // Sort by modified time (newest first)
    logs.sort((a, b) => b.modified - a.modified);

    return logs;
  } catch (err) {
    console.error(`Error listing logs for project ${projectName}: ${err.message}`);
    return [];
  }
}

/**
 * Delete all logs for a project
 */
function cleanProject(projectName) {
  const logs = listProjectLogs(projectName);
  let deleted = 0;

  for (const log of logs) {
    try {
      fs.unlinkSync(log.path);
      deleted++;
    } catch (err) {
      console.error(`Error deleting ${log.name}: ${err.message}`);
    }
  }

  return deleted;
}

/**
 * Format bytes to human-readable size
 */
function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

/**
 * Format timestamp to relative time
 */
function formatRelativeTime(timestamp) {
  const now = Date.now();
  const diff = now - timestamp;
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (seconds < 60) return `${seconds}s ago`;
  if (minutes < 60) return `${minutes}m ago`;
  if (hours < 24) return `${hours}h ago`;
  if (days < 7) return `${days}d ago`;

  const date = new Date(timestamp);
  return date.toLocaleDateString();
}

module.exports = {
  getConfig,
  saveConfig,
  isCentralizedMode,
  enableCentralizedMode,
  disableCentralizedMode,
  getCentralDirectory,
  setCentralDirectory,
  getProjectName,
  sanitizeProjectName,
  getProjectDirectory,
  ensureProjectDirectory,
  listProjects,
  getProjectStats,
  listProjectLogs,
  cleanProject,
  formatBytes,
  formatRelativeTime
};
