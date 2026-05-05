import json
import boto3
import os
from concurrent.futures import ThreadPoolExecutor

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

TABLE_NAME = os.environ['TABLE_NAME']
BUCKET_NAME = os.environ['BUCKET_NAME']

table = dynamodb.Table(TABLE_NAME)

def process_object(key):
    obj = s3.get_object(Bucket=BUCKET_NAME, Key=key)
    data = json.loads(obj['Body'].read())

    return {
        "PutRequest": {
            "Item": {
                "id": key,
                "value": str(data.get("value", 0))
            }
        }
    }

def lambda_handler(event, context):

    response = s3.list_objects_v2(Bucket=BUCKET_NAME)
    objects = response.get('Contents', [])

    keys = [obj['Key'] for obj in objects[:1000]]

    with ThreadPoolExecutor(max_workers=10) as executor:
        results = list(executor.map(process_object, keys))

    # Batch write (25 max per request)
    for i in range(0, len(results), 25):
        batch = results[i:i+25]
        table.batch_writer().put_item

        with table.batch_writer() as batch_writer:
            for item in batch:
                batch_writer.put_item(Item=item["PutRequest"]["Item"])

    return {
        "statusCode": 200,
        "processed": len(keys)
    }