import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { DynamoDBClient, GetItemCommand } from '@aws-sdk/client-dynamodb';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
// @ts-ignore
import { getRequestId } from '/opt/nodejs/shared/correlation';
// @ts-ignore
import { createLogger } from '/opt/nodejs/shared/logger';

const ddb = new DynamoDBClient({});
const s3 = new S3Client({});

const tableName = process.env.TABLE_NAME as string;
const bucketName = process.env.BUCKET_NAME as string;

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
    const id = event.pathParameters?.id;
    if (!id) {
      return { statusCode: 400, body: JSON.stringify({ ok: false, message: 'id is required' }) };
    }

    const getRes = await ddb.send(new GetItemCommand({ TableName: tableName, Key: { id: { S: id } } }));
    if (!getRes.Item) {
      return { statusCode: 404, body: JSON.stringify({ ok: false, message: 'not found' }) };
    }

    const exported = {
      id,
      createdAt: getRes.Item.createdAt?.S,
      requestId: getRes.Item.requestId?.S,
      data: safeParse(getRes.Item.data?.S ?? 'null'),
      exportedAt: new Date().toISOString(),
    };

    await s3.send(
      new PutObjectCommand({
        Bucket: bucketName,
        Key: `exports/${id}.json`,
        Body: JSON.stringify(exported),
        ContentType: 'application/json',
      })
    );

    log.info('Exported item to S3', { key: `exports/${id}.json` });

    return {
      statusCode: 200,
      headers: { 'content-type': 'application/json', 'x-correlation-id': requestId },
      body: JSON.stringify({ ok: true, id, s3Key: `exports/${id}.json`, requestId }),
    };
  } catch (err: any) {
    log.error('Export failed', { error: serializeError(err) });
    return { statusCode: 500, body: JSON.stringify({ ok: false, error: err?.message || 'error' }) };
  }
};

function safeParse(s: string): any { try { return JSON.parse(s); } catch { return s; } }
function serializeError(err: any) { return { message: err?.message, name: err?.name, stack: err?.stack }; }


