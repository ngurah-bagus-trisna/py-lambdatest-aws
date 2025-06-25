import boto3
import pymysql
import os
import json
import time
from datetime import datetime
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    print("🚀 Lambda started.")

    # Step 1: Load env vars
    try:
        secret_name = os.environ['SECRET_NAME']
        bucket_name = os.environ['BUCKET_NAME']
        db_host = os.environ['DB_HOST']
        db_user = os.environ['DB_USER']
        db_name = os.environ['DB_NAME']
        print(f"✅ Env vars loaded:\n  DB_HOST={db_host}\n  DB_USER={db_user}\n  DB_NAME={db_name}\n  BUCKET={bucket_name}")
    except KeyError as e:
        print(f"❌ Missing environment variable: {str(e)}")
        return {"statusCode": 500, "body": "Missing environment variable"}

    # Step 2: Get DB password from Secrets Manager
    try:
        secrets_client = boto3.client('secretsmanager')
        print("🔍 Fetching password from Secrets Manager...")
        start_time = time.time()
        secret_value = secrets_client.get_secret_value(SecretId=secret_name)
        password = json.loads(secret_value['SecretString'])['password']
        print(f"✅ Password fetched in {round(time.time() - start_time, 2)}s")
    except ClientError as e:
        print(f"❌ Failed to get secret: {e.response['Error']['Message']}")
        return {"statusCode": 500, "body": "Failed to get DB password"}
    except Exception as e:
        print(f"❌ Unexpected error getting secret: {str(e)}")
        return {"statusCode": 500, "body": "Error while retrieving secret"}

    # Step 3: Connect to DB
    try:
        print("🔌 Connecting to DB...")
        start_time = time.time()
        conn = pymysql.connect(
            host=db_host,
            user=db_user,
            password=password,
            db=db_name,
            connect_timeout=5
        )
        print(f"✅ Connected to DB in {round(time.time() - start_time, 2)}s")
    except Exception as e:
        print(f"❌ DB connection failed: {str(e)}")
        return {"statusCode": 500, "body": "Failed to connect to database"}

    # Step 4: Run SELECT NOW()
    try:
        print("📡 Executing query...")
        start_time = time.time()
        with conn.cursor() as cursor:
            cursor.execute("SELECT NOW();")
            result = cursor.fetchone()
        conn.close()
        print(f"✅ Query result: {result[0]} in {round(time.time() - start_time, 2)}s")
    except Exception as e:
        print(f"❌ Query failed: {str(e)}")
        return {"statusCode": 500, "body": "DB query failed"}

    # Step 5: Upload to S3
    try:
        print("☁️ Uploading to S3...")
        start_time = time.time()
        s3_client = boto3.client('s3')
        payload = json.dumps({"timestamp": str(result[0])})
        filename = f"timestamp_{datetime.utcnow().isoformat()}.json"

        s3_client.put_object(
            Bucket=bucket_name,
            Key=filename,
            Body=payload
        )
        print(f"✅ Uploaded to S3: {filename} in {round(time.time() - start_time, 2)}s")
    except Exception as e:
        print(f"❌ Failed to upload to S3: {str(e)}")
        return {"statusCode": 500, "body": "S3 upload failed"}

    return {
        "statusCode": 200,
        "body": f"Saved to S3 as {filename}"
    }