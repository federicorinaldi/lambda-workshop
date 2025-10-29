import type { APIGatewayProxyEventV2, Context, APIGatewayProxyResultV2 } from 'aws-lambda';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';
import { getRequestId, createLogger } from './shared-utils';

const sqs = new SQSClient({
  ...(process.env.AWS_ENDPOINT_URL && { endpoint: process.env.AWS_ENDPOINT_URL }),
});
const queueUrl = process.env.QUEUE_URL as string;

export const handler = async (
  event: APIGatewayProxyEventV2,
  context: Context
): Promise<APIGatewayProxyResultV2> => {
  const requestId: string = getRequestId(event, context);
  const log = createLogger({
    service: process.env.SERVICE_NAME || 'LambdaWorkshopSample',
    version: process.env.SERVICE_VERSION || '1.0.0',
    requestId,
    functionName: context.functionName,
  });

  try {
    const body = event.body ? safeJsonParse(event.body) : {};
    const payload = {
      id: body?.id || requestId,
      createdAt: new Date().toISOString(),
      data: body?.data ?? null,
      requestId,
    };

    await sqs.send(
      new SendMessageCommand({
        QueueUrl: queueUrl,
        MessageBody: JSON.stringify(payload),
        MessageAttributes: {
          'x-correlation-id': { DataType: 'String', StringValue: requestId },
        },
      })
    );

    log.info('Enqueued message to SQS', { id: payload.id });

    return {
      statusCode: 202,
      headers: {
        'content-type': 'application/json',
        'x-correlation-id': requestId,
      },
      body: JSON.stringify({ accepted: true, id: payload.id, requestId }),
    };
  } catch (err: any) {
    log.error('Failed to enqueue', { error: serializeError(err) });
    return {
      statusCode: 500,
      headers: { 'content-type': 'application/json', 'x-correlation-id': requestId },
      body: JSON.stringify({ ok: false, error: err?.message ?? 'Unknown error', requestId }),
    };
  }
};

function safeJsonParse(s: string): any {
  try { return JSON.parse(s); } catch { return {}; }
}

function serializeError(err: any) {
  return { message: err?.message, name: err?.name, stack: err?.stack };
}


