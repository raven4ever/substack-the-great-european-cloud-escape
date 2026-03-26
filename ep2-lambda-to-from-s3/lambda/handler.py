import json
import os
from io import BytesIO
from urllib.parse import unquote_plus

import boto3
from PIL import Image

THUMBNAIL_WIDTH = int(os.environ.get("THUMBNAIL_WIDTH", "200"))
THUMBNAIL_HEIGHT = int(os.environ.get("THUMBNAIL_HEIGHT", "200"))
DEST_BUCKET = os.environ.get("DEST_BUCKET")
S3_ENDPOINT = os.environ.get("S3_ENDPOINT")


def get_s3_client():
    """Create an S3 client. Works against both AWS and Scaleway."""
    kwargs = {}
    if S3_ENDPOINT:
        kwargs["endpoint_url"] = S3_ENDPOINT
    return boto3.client("s3", **kwargs)


def resize_image(s3, source_bucket, key):
    """Download an image from S3, resize it, and upload the thumbnail."""
    response = s3.get_object(Bucket=source_bucket, Key=key)
    image = Image.open(response["Body"])

    image.thumbnail((THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT))

    buffer = BytesIO()
    image_format = image.format or "JPEG"
    image.save(buffer, format=image_format)
    buffer.seek(0)

    dest_bucket = DEST_BUCKET or source_bucket
    dest_key = f"thumbnails/{key}"

    s3.put_object(
        Bucket=dest_bucket,
        Key=dest_key,
        Body=buffer,
        ContentType=f"image/{image_format.lower()}",
    )

    return {"bucket": dest_bucket, "key": dest_key}


# --- AWS Lambda handler ---

def aws_handler(event, context):
    """Triggered by S3 event notification."""
    s3 = get_s3_client()

    for record in event["Records"]:
        source_bucket = record["s3"]["bucket"]["name"]
        key = unquote_plus(record["s3"]["object"]["key"])
        result = resize_image(s3, source_bucket, key)
        print(f"Created thumbnail: s3://{result['bucket']}/{result['key']}")

    return {"statusCode": 200, "body": json.dumps("OK")}


# --- Scaleway Serverless handler ---

def scaleway_handler(event, context):
    """Triggered by SQS message containing bucket and key."""
    s3 = get_s3_client()

    body = event["body"]
    if isinstance(body, str):
        body = json.loads(body)

    source_bucket = body["bucket"]
    key = body["key"]
    result = resize_image(s3, source_bucket, key)
    print(f"Created thumbnail: s3://{result['bucket']}/{result['key']}")

    return {"statusCode": 200, "body": json.dumps("OK")}
