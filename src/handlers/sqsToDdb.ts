import type { SQSBatchResponse, SQSHandler, SQSRecord } from 'aws-lambda';
import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';
// @ts-ignore
import { createLogger } from '/opt/nodejs/shared/logger';

const ddb = new DynamoDBClient({});
const tableName = process.env.TABLE_NAME as string;

export const handler: SQSHandler = async (event, context) => {
  const baseLog = createLogger({
    service: process.env.SERVICE_NAME || 'LambdaWorkshopSample',
    version: process.env.SERVICE_VERSION || '1.0.0',
    functionName: context.functionName,
  });

  const failures: string[] = [];

  for (const record of event.Records) {
    const log = baseLog.child({ messageId: record.messageId });
    try {
      const payload = parseRecord(record, log);
      await ddb.send(
        new PutItemCommand({
          TableName: tableName,
          Item: {
            id: { S: payload.id },
            createdAt: { S: payload.createdAt },
            requestId: { S: payload.requestId ?? '' },
            data: { S: JSON.stringify(payload.data ?? null) },
          },
          ConditionExpression: 'attribute_not_exists(id)',
        })
      );
      log.info('Wrote item to DynamoDB', { id: payload.id });
    } catch (err: any) {
      log.error('Failed processing SQS record', { error: serializeError(err) });
      failures.push(record.messageId);
    }
  }

  const response: SQSBatchResponse = {
    batchItemFailures: failures.map((id) => ({ itemIdentifier: id })),
  };
  baseLog.info('Batch complete', { failedCount: failures.length });
  return response;
};

function parseRecord(record: SQSRecord, log: any): any {
  try {
    return JSON.parse(record.body);
  } catch {
    log.warn('Non-JSON body, storing as raw string');
    return { id: record.messageId, createdAt: new Date().toISOString(), data: record.body };
  }
}

function serializeError(err: any) {
  return { message: err?.message, name: err?.name, stack: err?.stack };
}


