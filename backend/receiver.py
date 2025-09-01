import json
import csv
import boto3
from datetime import datetime, timedelta
import os
import uuid

# Initialize an S3 client
s3 = boto3.client('s3')

def handler(event, context):
    try:
        # Extract bucket and object key from environment variables
        s3_bucket = os.environ.get('S3_BUCKET')
        s3_key_prefix = os.environ.get('S3_KEY_PREFIX', 'machine_durations/')

        if not s3_bucket or not s3_key_prefix:
            raise ValueError("Environment variables S3_BUCKET or S3_KEY_PREFIX are missing.")

        # Parse the incoming JSON event
        payload = event['body'] if isinstance(event['body'], dict) else json.loads(event['body'])

        # Extract vibration duration from the payload
        vibration_duration_seconds = payload.get('vibration_duration_seconds')

        if vibration_duration_seconds is None:
            raise ValueError("Missing 'vibration_duration_seconds' in the payload.")

        # Use current time as the timestamp when this event was processed (assumed to be end time)
        now = datetime.now()
        event_timestamp_str = now.isoformat()

        # Calculate start time: end_time - duration
        start_time = now - timedelta(seconds=vibration_duration_seconds)
        start_time_str = start_time.isoformat()

        # Prepare CSV row data
        csv_data = {
            'machine_id': payload.get('machine_id', 'unknown'),
            'start_time': start_time_str,
            'end_time': event_timestamp_str,
            'vibration_duration_seconds': vibration_duration_seconds
        }

        # Format as a CSV string (single line for each record)
        csv_row = f"{csv_data['machine_id']},{csv_data['start_time']},{csv_data['end_time']},{csv_data['vibration_duration_seconds']}\n"

        # Define the S3 object key using the prefix and current date
        s3_key = f"{s3_key_prefix}{uuid.uuid4()}.csv"

        # Upload CSV row to S3
        s3.put_object(
            Bucket=s3_bucket,
            Key=s3_key,
            Body=csv_row.encode('utf-8'),
            ContentType='text/csv'
        )

        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Data processed and stored successfully.'})
        }

    except Exception as e:
        # Log error (optional: use CloudWatch logs)
        print(f"Error processing data: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f'Failed to process data. Error: {str(e)}'})
        }
