'use strict';

// Minimal JSON logger for Lambda, designed for structured logs and child contexts

function createLogger(baseContext) {
  const context = { ...baseContext };

  return {
    child(extra) {
      return createLogger({ ...context, ...extra });
    },
    debug(message, extra) {
      logLine('DEBUG', message, context, extra);
    },
    info(message, extra) {
      logLine('INFO', message, context, extra);
    },
    warn(message, extra) {
      logLine('WARN', message, context, extra);
    },
    error(message, extra) {
      logLine('ERROR', message, context, extra);
    },
  };
}

function logLine(level, message, context, extra) {
  const line = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...context,
    ...(extra || {}),
  };
  // Ensure a single line of JSON per log entry
  process.stdout.write(JSON.stringify(line) + '\n');
}

module.exports = { createLogger };


