#!/usr/bin/env node

const centralManager = require('../lib/centralized-manager');

/**
 * Display help for log-projects command
 */
function showHelp() {
  console.log(`
Usage: log-projects [project-name] [options]

Manage projects in centralized logging mode.

Commands:
  log-projects                    List all projects
  log-projects <name>             List logs for specific project
  log-projects <name> --clean     Delete all logs for project

Examples:
  log-projects
  # Projects in ~/auto-logger-logs:
  #   my-frontend-app     (5 logs, 12.3 MB, last: 5m ago)
  #   another-project     (3 logs, 4.1 MB, last: 2h ago)

  log-projects my-frontend-app
  # Logs for my-frontend-app:
  #   frontend.log                      (2.3 MB, 5m ago)
  #   npm-dev.log                       (1.1 MB, 10m ago)
  #   browser-2025-11-23-14-30-45.log   (8.9 MB, 15m ago)

  log-projects my-frontend-app --clean
  # Deleted 5 log files for my-frontend-app
`);
}

/**
 * List all projects
 */
function listAllProjects() {
  if (!centralManager.isCentralizedMode()) {
    console.log('⚠ Centralized mode is not enabled.');
    console.log('Enable it with: log-centralize enable');
    return;
  }

  const projects = centralManager.listProjects();

  if (projects.length === 0) {
    console.log(`No projects found in ${centralManager.getCentralDirectory()}`);
    console.log('\nProjects will appear here when you enable logging in centralized mode.');
    return;
  }

  console.log(`Projects in ${centralManager.getCentralDirectory()}:`);
  console.log('');

  for (const project of projects) {
    const size = centralManager.formatBytes(project.totalSize);
    const time = centralManager.formatRelativeTime(project.lastModified);
    const logs = project.logCount === 1 ? 'log' : 'logs';

    console.log(`  ${project.name.padEnd(30)} (${project.logCount} ${logs}, ${size}, last: ${time})`);
  }

  console.log('');
  console.log(`Total projects: ${projects.length}`);
}

/**
 * List logs for a specific project
 */
function listProjectLogs(projectName) {
  const logs = centralManager.listProjectLogs(projectName);

  if (logs.length === 0) {
    console.log(`No logs found for project: ${projectName}`);
    return;
  }

  console.log(`Logs for ${projectName}:`);
  console.log('');

  for (const log of logs) {
    const size = centralManager.formatBytes(log.size);
    const time = centralManager.formatRelativeTime(log.modified);

    console.log(`  ${log.name.padEnd(40)} (${size}, ${time})`);
  }

  console.log('');
  console.log(`Total logs: ${logs.length}`);
}

/**
 * Clean logs for a specific project
 */
function cleanProjectLogs(projectName) {
  const logs = centralManager.listProjectLogs(projectName);

  if (logs.length === 0) {
    console.log(`No logs found for project: ${projectName}`);
    return;
  }

  console.log(`Deleting ${logs.length} log file(s) for ${projectName}...`);

  const deleted = centralManager.cleanProject(projectName);

  if (deleted > 0) {
    console.log(`✓ Deleted ${deleted} log file(s) for ${projectName}`);
  } else {
    console.log(`⚠ No files were deleted`);
  }
}

/**
 * Main function
 */
function main() {
  const args = process.argv.slice(2);

  // No arguments - list all projects
  if (args.length === 0) {
    listAllProjects();
    return;
  }

  // Help flag
  if (args[0] === '--help' || args[0] === '-h') {
    showHelp();
    return;
  }

  const projectName = args[0];
  const cleanFlag = args.includes('--clean');

  // Clean project logs
  if (cleanFlag) {
    cleanProjectLogs(projectName);
    return;
  }

  // List logs for specific project
  listProjectLogs(projectName);
}

// Run
main();
