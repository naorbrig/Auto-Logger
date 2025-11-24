#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');
const centralManager = require('./centralized-manager');

/**
 * Resolve log file path using smart detection
 * Priority:
 * 1. Centralized directory (if enabled) → ~/auto-logger-logs/{project}/
 * 2. AUTO_LOGGER_DIR environment variable (if set)
 * 3. ./logs (if exists in current directory)
 * 4. ~/logs (global fallback)
 */
function resolveLogPath(filename) {
  // Priority 1: Centralized mode
  if (centralManager.isCentralizedMode()) {
    const projectDir = centralManager.ensureProjectDirectory();
    return path.join(projectDir, filename);
  }

  // Priority 2: Environment variable
  if (process.env.AUTO_LOGGER_DIR) {
    const customDir = path.resolve(process.env.AUTO_LOGGER_DIR);
    if (!fs.existsSync(customDir)) {
      fs.mkdirSync(customDir, { recursive: true });
    }
    return path.join(customDir, filename);
  }

  // Priority 3: Local ./logs directory
  const localLogs = path.join(process.cwd(), 'logs');
  if (fs.existsSync(localLogs)) {
    return path.join(localLogs, filename);
  }

  // Priority 4: Global ~/logs directory
  const globalLogs = path.join(os.homedir(), 'logs');
  if (!fs.existsSync(globalLogs)) {
    fs.mkdirSync(globalLogs, { recursive: true });
  }
  return path.join(globalLogs, filename);
}

/**
 * Get the log directory (without filename)
 * Returns the directory where logs will be saved
 */
function getLogDirectory() {
  // Priority 1: Centralized mode
  if (centralManager.isCentralizedMode()) {
    return centralManager.ensureProjectDirectory();
  }

  // Priority 2: Environment variable
  if (process.env.AUTO_LOGGER_DIR) {
    const customDir = path.resolve(process.env.AUTO_LOGGER_DIR);
    if (!fs.existsSync(customDir)) {
      fs.mkdirSync(customDir, { recursive: true });
    }
    return customDir;
  }

  // Priority 3: Local ./logs directory
  const localLogs = path.join(process.cwd(), 'logs');
  if (fs.existsSync(localLogs)) {
    return localLogs;
  }

  // Priority 4: Global ~/logs directory
  const globalLogs = path.join(os.homedir(), 'logs');
  if (!fs.existsSync(globalLogs)) {
    fs.mkdirSync(globalLogs, { recursive: true });
  }
  return globalLogs;
}

/**
 * Get log directory description for display
 * Shows where logs are being saved with reason
 */
function getLogDirectoryInfo() {
  if (centralManager.isCentralizedMode()) {
    const projectName = centralManager.getProjectName();
    const projectDir = centralManager.getProjectDirectory();
    return {
      path: projectDir,
      mode: 'centralized',
      reason: `Centralized mode (project: ${projectName})`
    };
  }

  if (process.env.AUTO_LOGGER_DIR) {
    return {
      path: process.env.AUTO_LOGGER_DIR,
      mode: 'custom',
      reason: 'AUTO_LOGGER_DIR environment variable'
    };
  }

  const localLogs = path.join(process.cwd(), 'logs');
  if (fs.existsSync(localLogs)) {
    return {
      path: localLogs,
      mode: 'local',
      reason: 'Local ./logs directory exists'
    };
  }

  const globalLogs = path.join(os.homedir(), 'logs');
  return {
    path: globalLogs,
    mode: 'global',
    reason: 'Global ~/logs fallback'
  };
}

/**
 * List all log files in current log directory
 * Returns array of log file objects with stats
 */
function listLogFiles() {
  const logDir = getLogDirectory();

  if (!fs.existsSync(logDir)) {
    return [];
  }

  try {
    const files = fs.readdirSync(logDir);
    const logs = [];

    for (const file of files) {
      if (file.endsWith('.log') || file.endsWith('.har')) {
        const filePath = path.join(logDir, file);
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
    console.error(`Error listing log files: ${err.message}`);
    return [];
  }
}

/**
 * Find a log file by partial name match
 * Useful for commands like: log-view frontend (matches frontend.log)
 */
function findLogFile(partialName) {
  const logs = listLogFiles();

  // Exact match first (with or without .log extension)
  const exactName = partialName.endsWith('.log') ? partialName : `${partialName}.log`;
  const exact = logs.find(log => log.name === exactName);
  if (exact) return exact.path;

  // Partial match (contains)
  const partial = logs.find(log => log.name.includes(partialName));
  if (partial) return partial.path;

  return null;
}

/**
 * Clear a specific log file
 */
function clearLogFile(filename) {
  const filePath = findLogFile(filename);
  if (!filePath) {
    return false;
  }

  try {
    fs.unlinkSync(filePath);
    return true;
  } catch (err) {
    console.error(`Error deleting log file: ${err.message}`);
    return false;
  }
}

/**
 * Clear all log files in current directory
 */
function clearAllLogs() {
  const logs = listLogFiles();
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

module.exports = {
  resolveLogPath,
  getLogDirectory,
  getLogDirectoryInfo,
  listLogFiles,
  findLogFile,
  clearLogFile,
  clearAllLogs
};
