'use strict';

function getRequestId(event, context) {
  const headers = event && (event.headers || event.requestContext?.http?.headers);
  const headerId = headers && (headers['x-correlation-id'] || headers['X-Correlation-Id']);
  const apiGwId = event?.requestContext?.requestId || event?.requestContext?.requestId;
  const awsId = context?.awsRequestId;
  return headerId || apiGwId || awsId || randomId();
}

function withCorrelationHeaders(headers, requestId) {
  return {
    ...(headers || {}),
    'x-correlation-id': requestId,
  };
}

function randomId() {
  // Simple RFC4122-ish ID generator for fallback
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

module.exports = { getRequestId, withCorrelationHeaders };


