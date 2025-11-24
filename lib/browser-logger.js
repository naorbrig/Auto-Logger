#!/usr/bin/env node

/**
 * Browser Logger - Chrome DevTools Protocol Implementation
 * Captures console logs, network requests, and errors from Chromium browsers
 */

const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

class BrowserLogger {
  constructor(options = {}) {
    this.logDir = options.logDir;
    this.browserPath = options.browserPath;
    this.preview = options.preview || false;
    this.format = options.format || 'default';
    this.browser = null;
    this.page = null;
    this.cdpSession = null;
    this.consoleStream = null;
    this.networkStream = null;
    this.networkLog = [];
    this.startTime = Date.now();
    this.networkStats = {
      total: 0,
      logged: 0,
      filtered: 0
    };
  }

  /**
   * Find Chrome/Chromium executable
   */
  static findChrome() {
    const platform = process.platform;
    const paths = [];

    if (platform === 'darwin') {
      paths.push(
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
        '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
        '/Applications/Arc.app/Contents/MacOS/Arc'
      );
    } else if (platform === 'win32') {
      paths.push(
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
        'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe'
      );
    } else {
      // Linux
      paths.push(
        '/usr/bin/google-chrome',
        '/usr/bin/chromium-browser',
        '/usr/bin/chromium',
        '/snap/bin/chromium'
      );
    }

    for (const p of paths) {
      if (fs.existsSync(p)) {
        return p;
      }
    }

    return null;
  }

  /**
   * Format timestamp
   */
  formatTimestamp() {
    const now = new Date();
    const elapsed = Date.now() - this.startTime;
    const seconds = (elapsed / 1000).toFixed(3);

    return {
      iso: now.toISOString(),
      time: now.toLocaleTimeString(),
      elapsed: `+${seconds}s`
    };
  }

  /**
   * Write to console log file
   */
  writeConsoleLog(message) {
    if (this.consoleStream) {
      this.consoleStream.write(message + '\n');
    }

    if (this.preview) {
      console.log(message);
    }
  }

  /**
   * Write to network log file
   */
  writeNetworkLog(message) {
    if (this.networkStream) {
      this.networkStream.write(message + '\n');
    }

    if (this.preview) {
      console.log(message);
    }
  }

  /**
   * Format console message
   */
  formatConsoleMessage(type, text, location) {
    const ts = this.formatTimestamp();
    const typeUpper = type.toUpperCase().padEnd(7);

    let message = `[${ts.time}] CONSOLE.${typeUpper} ${text}`;

    if (location) {
      message += `\n  Source: ${location}`;
    }

    return message;
  }

  /**
   * Format network request
   */
  formatNetworkRequest(method, url, headers) {
    const ts = this.formatTimestamp();
    return `[${ts.time}] NETWORK REQUEST\n  ${method} ${url}`;
  }

  /**
   * Format network response
   */
  formatNetworkResponse(method, url, status, statusText, duration, size, body) {
    const ts = this.formatTimestamp();
    const sizeStr = size ? ` | Size: ${this.formatBytes(size)}` : '';

    let message = `[${ts.time}] NETWORK RESPONSE\n`;
    message += `  ${method} ${url}\n`;
    message += `  Status: ${status} ${statusText} (${duration}ms)${sizeStr}`;

    if (body && body.length < 1000) {
      message += `\n  Body: ${body}`;
    }

    return message;
  }

  /**
   * Format bytes
   */
  formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
  }

  /**
   * Determine if a network request should be logged
   */
  shouldLogRequest(url, method, status, pageUrl) {
    // Always log mutations
    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
      return true;
    }

    // Always log failed requests
    if (status && (status >= 400)) {
      return true;
    }

    // Parse URLs
    let requestUrl, requestOrigin;
    try {
      requestUrl = new URL(url);
      requestOrigin = requestUrl.origin;
    } catch {
      return true; // Log if we can't parse
    }

    let pageOrigin;
    try {
      if (pageUrl && pageUrl !== 'about:blank') {
        pageOrigin = new URL(pageUrl).origin;
      }
    } catch {
      // Ignore
    }

    // Always log cross-origin requests (likely APIs)
    if (pageOrigin && requestOrigin !== pageOrigin) {
      return true;
    }

    // Filter static assets
    const staticExtensions = [
      '.js', '.mjs', '.jsx', '.ts', '.tsx',
      '.css', '.scss', '.sass',
      '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.webp',
      '.woff', '.woff2', '.ttf', '.otf', '.eot',
      '.map'
    ];

    const pathname = requestUrl.pathname.toLowerCase();
    for (const ext of staticExtensions) {
      if (pathname.endsWith(ext)) {
        return false; // Filter out
      }
    }

    // Filter Vite HMR and module imports
    if (pathname.includes('/@vite/') || pathname.includes('/node_modules/.vite/')) {
      return false;
    }

    // Log everything else (HTML, API endpoints, etc.)
    return true;
  }

  /**
   * Initialize log directory and files
   */
  initLogFile() {
    // Create log directory if it doesn't exist
    if (!fs.existsSync(this.logDir)) {
      fs.mkdirSync(this.logDir, { recursive: true });
    }

    const consoleFile = path.join(this.logDir, 'console.log');
    const networkFile = path.join(this.logDir, 'network.log');

    // Console log header
    const consoleHeader = `=== Auto-Logger Browser Session - Console Output ===
Started: ${new Date().toISOString()}
Log Directory: ${this.logDir}
---

`;

    // Network log header
    const networkHeader = `=== Auto-Logger Browser Session - Network Activity ===
Started: ${new Date().toISOString()}
Log Directory: ${this.logDir}
---

`;

    this.consoleStream = fs.createWriteStream(consoleFile, { flags: 'w' });
    this.consoleStream.write(consoleHeader);

    this.networkStream = fs.createWriteStream(networkFile, { flags: 'w' });
    this.networkStream.write(networkHeader);

    console.log(`✓ Browser logging enabled`);
    console.log(`→ Logging to: ${this.logDir}/`);
    console.log(`  - console.log  (console messages)`);
    console.log(`  - network.log  (network requests & responses)`);
    console.log(`→ Launching browser...`);
    console.log('');
  }

  /**
   * Attach listeners to a page
   */
  async attachToPage(page) {
    try {
      const target = page.target();
      const session = await target.createCDPSession();

      // Enable domains
      await session.send('Network.enable');
      await session.send('Runtime.enable');
      await session.send('Log.enable');

      // Set up event listeners for this page
      this.setupConsoleListenerForSession(session);
      this.setupNetworkListenersForSession(session, page);
      this.setupErrorListenerForSession(session);

      // Write to both logs that we're monitoring a new page
      const infoMsg = `\n[INFO] Monitoring new page/tab: ${page.url() || 'about:blank'}`;
      this.writeConsoleLog(infoMsg);
      this.writeNetworkLog(infoMsg);
    } catch (err) {
      console.error(`Warning: Failed to attach to page: ${err.message}`);
    }
  }

  /**
   * Start browser logging
   */
  async start() {
    try {
      this.initLogFile();

      // Find Chrome
      const chromePath = this.browserPath || BrowserLogger.findChrome();

      if (!chromePath) {
        throw new Error('Chrome/Chromium not found. Please install Chrome, Edge, or Brave.');
      }

      // Launch browser
      this.browser = await puppeteer.launch({
        executablePath: chromePath,
        headless: false,
        devtools: false,
        defaultViewport: null, // Use window size instead of fixed viewport
        args: [
          '--no-first-run',
          '--no-default-browser-check',
          '--window-size=1920,1080', // Large window size
        ]
      });

      console.log(`✓ Browser launched`);
      console.log(`✓ Chrome DevTools Protocol connected`);
      console.log('');
      console.log('Navigate to your application and start debugging!');
      console.log('Press Ctrl+C to stop logging and close browser.');
      console.log('');

      // Attach to all existing pages
      const pages = await this.browser.pages();
      for (const page of pages) {
        await this.attachToPage(page);
      }

      // Monitor new pages/tabs
      this.browser.on('targetcreated', async (target) => {
        if (target.type() === 'page') {
          try {
            const page = await target.page();
            if (page) {
              await this.attachToPage(page);
            }
          } catch (err) {
            console.error(`Warning: Failed to monitor new page: ${err.message}`);
          }
        }
      });

      // Handle browser close
      this.browser.on('disconnected', () => {
        this.stop(false);
      });

    } catch (err) {
      console.error(`❌ Failed to start browser logging: ${err.message}`);
      throw err;
    }
  }

  /**
   * Setup console listener for a CDP session
   */
  setupConsoleListenerForSession(session) {
    session.on('Runtime.consoleAPICalled', (params) => {
      const { type, args, stackTrace } = params;

      // Extract console message text from args
      let text = '';
      if (args && args.length > 0) {
        text = args.map(arg => {
          if (arg.value !== undefined) {
            return String(arg.value);
          } else if (arg.description) {
            return arg.description;
          }
          return '[Object]';
        }).join(' ');
      }

      // Get location from stack trace
      let locationStr = null;
      if (stackTrace && stackTrace.callFrames && stackTrace.callFrames.length > 0) {
        const frame = stackTrace.callFrames[0];
        locationStr = `${frame.url}:${frame.lineNumber}:${frame.columnNumber}`;
      }

      const formatted = this.formatConsoleMessage(type, text, locationStr);
      this.writeConsoleLog(formatted);
    });
  }

  /**
   * Setup network listeners for a CDP session
   */
  setupNetworkListenersForSession(session, page) {
    const requests = new Map();

    // Request started
    session.on('Network.requestWillBeSent', params => {
      const { requestId, request, timestamp } = params;

      this.networkStats.total++;

      // Check if we should log this request
      const pageUrl = page.url();
      const shouldLog = this.shouldLogRequest(request.url, request.method, null, pageUrl);

      requests.set(requestId, {
        method: request.method,
        url: request.url,
        headers: request.headers,
        postData: request.postData,
        timestamp: timestamp * 1000,
        shouldLog: shouldLog
      });

      if (!shouldLog) {
        this.networkStats.filtered++;
        return; // Skip logging
      }

      this.networkStats.logged++;

      // Log request with full headers
      const ts = this.formatTimestamp();
      let message = `\n[${ts.time}] ========================================\n`;
      message += `REQUEST: ${request.method} ${request.url}\n`;

      // Request headers
      if (request.headers && Object.keys(request.headers).length > 0) {
        message += `Headers:\n`;
        for (const [key, value] of Object.entries(request.headers)) {
          message += `  ${key}: ${value}\n`;
        }
      }

      // Request body (for POST/PUT/PATCH)
      if (request.postData) {
        message += `Body:\n  ${request.postData}\n`;
      }

      this.writeNetworkLog(message);

      // Store for HAR export
      this.networkLog.push({
        type: 'request',
        requestId,
        ...params
      });
    });

    // Response received
    session.on('Network.responseReceived', params => {
      const { requestId, response, timestamp } = params;
      const req = requests.get(requestId);

      if (!req) {
        return; // Request not tracked
      }

      // Skip if request was filtered
      if (!req.shouldLog) {
        requests.delete(requestId);
        return;
      }

      const duration = Math.round(timestamp * 1000 - req.timestamp);
      const status = response.status;
      const statusText = response.statusText;

      // Write basic response info immediately (before trying to get body)
      const ts = this.formatTimestamp();
      let message = `\n[${ts.time}] RESPONSE: ${status} ${statusText} (${duration}ms)\n`;

      // Response headers
      if (response.headers && Object.keys(response.headers).length > 0) {
        message += `Headers:\n`;
        for (const [key, value] of Object.entries(response.headers)) {
          message += `  ${key}: ${value}\n`;
        }
      }

      // Write basic response immediately
      this.writeNetworkLog(message);

      // Try to get response body (async) and append it
      session.send('Network.getResponseBody', { requestId })
        .then(({ body, base64Encoded }) => {
            let responseBody = body;
            if (base64Encoded) {
              responseBody = '[Base64 Encoded Data]';
            }

            // Append body to log
            if (responseBody) {
              const bodySize = Buffer.byteLength(responseBody, 'utf8');
              let bodyMsg = `Body (${this.formatBytes(bodySize)}):\n`;
              bodyMsg += `  ${responseBody}\n`;
              bodyMsg += `========================================\n`;
              this.writeNetworkLog(bodyMsg);
            } else {
              this.writeNetworkLog(`Body: [Empty]\n========================================\n`);
            }
          })
          .catch(() => {
            // Body not available (e.g., 204 No Content, CORS error)
            this.writeNetworkLog(`Body: [Not Available]\n========================================\n`);
          });

      requests.delete(requestId);

      // Store for HAR export
      this.networkLog.push({
        type: 'response',
        requestId,
        ...params
      });
    });
  }

  /**
   * Setup error listener for a CDP session
   */
  setupErrorListenerForSession(session) {
    session.on('Runtime.exceptionThrown', params => {
      const { exceptionDetails } = params;
      const { text, exception, stackTrace } = exceptionDetails;

      let message = `[${this.formatTimestamp().time}] JAVASCRIPT ERROR\n`;
      message += `  ${text || exception.description || 'Unknown error'}\n`;

      if (stackTrace && stackTrace.callFrames.length > 0) {
        message += '  Stack Trace:\n';
        for (const frame of stackTrace.callFrames) {
          message += `    at ${frame.functionName || '(anonymous)'} (${frame.url}:${frame.lineNumber}:${frame.columnNumber})\n`;
        }
      }

      this.writeConsoleLog(message);
    });
  }

  /**
   * Stop browser logging
   */
  async stop(closeBrowser = true) {
    const consoleFooter = `\n---\n=== Session Ended: ${new Date().toISOString()} ===\n`;
    const networkFooter = `\n---\n=== Session Ended: ${new Date().toISOString()} ===\n=== Network Statistics ===\nTotal Requests: ${this.networkStats.total}\nLogged: ${this.networkStats.logged}\nFiltered: ${this.networkStats.filtered}\n`;

    if (this.consoleStream) {
      this.consoleStream.write(consoleFooter);
      this.consoleStream.end();
    }

    if (this.networkStream) {
      this.networkStream.write(networkFooter);
      this.networkStream.end();
    }

    if (closeBrowser && this.browser) {
      await this.browser.close();
    }

    console.log('');
    console.log('✓ Browser logging stopped');
    console.log(`→ Session saved to: ${this.logDir}/`);
    console.log(`  - console.log`);
    console.log(`  - network.log`);
  }

  /**
   * Export network logs as HAR
   */
  exportHAR(outputFile) {
    // HAR format export (simplified)
    const har = {
      log: {
        version: '1.2',
        creator: {
          name: 'auto-logger',
          version: '1.0.0'
        },
        entries: []
      }
    };

    // Convert network log to HAR format
    // This is a simplified version - full HAR export would be more complex

    fs.writeFileSync(outputFile, JSON.stringify(har, null, 2), 'utf8');
    console.log(`✓ HAR exported: ${outputFile}`);
  }
}

module.exports = BrowserLogger;
