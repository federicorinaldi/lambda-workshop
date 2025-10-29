// Shared utilities for correlation ID tracking and logging
// NOTE: In production, these would typically be in a Lambda Layer (see /layers folder)
// or published as an internal npm package. For this workshop, we include them
// directly in each service for simplicity.

export function getRequestId(event: any, context: any): string {
  const headers = event && (event.headers || event.requestContext?.http?.headers);
  const headerId = headers && (headers['x-correlation-id'] || headers['X-Correlation-Id']);
  const apiGwId = event?.requestContext?.requestId;
  const awsId = context?.awsRequestId;
  return headerId || apiGwId || awsId || randomId();
}

export function withCorrelationHeaders(headers: any, requestId: string) {
  return {
    ...(headers || {}),
    'x-correlation-id': requestId,
  };
}

function randomId(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

export interface LogContext {
  service?: string;
  version?: string;
  requestId?: string;
  functionName?: string;
  [key: string]: any;
}

export interface Logger {
  child(extra: Record<string, any>): Logger;
  debug(message: string, extra?: Record<string, any>): void;
  info(message: string, extra?: Record<string, any>): void;
  warn(message: string, extra?: Record<string, any>): void;
  error(message: string, extra?: Record<string, any>): void;
}

export function createLogger(baseContext: LogContext): Logger {
  const context = { ...baseContext };

  function logLine(level: string, message: string, extra?: Record<string, any>) {
    const line = {
      timestamp: new Date().toISOString(),
      level,
      message,
      ...context,
      ...(extra || {}),
    };
    process.stdout.write(JSON.stringify(line) + '\n');
  }

  return {
    child(extra: Record<string, any>) {
      return createLogger({ ...context, ...extra });
    },
    debug(message: string, extra?: Record<string, any>) {
      logLine('DEBUG', message, extra);
    },
    info(message: string, extra?: Record<string, any>) {
      logLine('INFO', message, extra);
    },
    warn(message: string, extra?: Record<string, any>) {
      logLine('WARN', message, extra);
    },
    error(message: string, extra?: Record<string, any>) {
      logLine('ERROR', message, extra);
    },
  };
}
