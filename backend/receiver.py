import json
import boto3
from datetime import datetime, timedelta, timezone
import os

s3 = boto3.client('s3')


def handler(event, context):
    try:
        s3_bucket = os.environ.get('S3_BUCKET')
        s3_key_prefix = os.environ.get('S3_KEY_PREFIX', 'machine_durations/')

        if not s3_bucket:
            raise ValueError("Environment variable S3_BUCKET is missing.")

        # IoT Core rule passes MQTT payload directly as the event
        machine_id = event.get('machine_id', 'unknown')
        vibration_duration_seconds = event.get('vibration_duration_seconds')

        if vibration_duration_seconds is None:
            raise ValueError("Missing 'vibration_duration_seconds' in the payload.")

        vibration_duration_seconds = float(vibration_duration_seconds)
        if vibration_duration_seconds < 0:
            raise ValueError(f"Invalid vibration_duration_seconds: {vibration_duration_seconds}")

        now = datetime.now(timezone.utc)
        start_time = now - timedelta(seconds=vibration_duration_seconds)

        date_str = now.strftime('%Y-%m-%d')
        timestamp_str = now.strftime('%Y%m%dT%H%M%SZ')

        csv_header = "machine_id,start_time,end_time,vibration_duration_seconds\n"
        csv_row = f"{machine_id},{start_time.isoformat()},{now.isoformat()},{vibration_duration_seconds}\n"

        s3_key = f"{s3_key_prefix}{machine_id}/{date_str}/{timestamp_str}.csv"

        s3.put_object(
            Bucket=s3_bucket,
            Key=s3_key,
            Body=(csv_header + csv_row).encode('utf-8'),
            ContentType='text/csv'
        )

        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Data processed and stored successfully.'})
        }

    except Exception as e:
        print(f"Error processing data: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
