#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scaleway.sh <image-file>
# Requires: aws cli (for S3 and SQS), terraform output from ../scaleway

if [ $# -lt 1 ]; then
  echo "Usage: $0 <image-file>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../scaleway"

IMAGE_FILE="$1"
IMAGE_KEY="$(basename "$IMAGE_FILE")"
THUMB_KEY="thumbnails/${IMAGE_KEY}"

# read from terraform output
INPUT_BUCKET=$(terraform -chdir="$TF_DIR" output -raw input_bucket)
OUTPUT_BUCKET=$(terraform -chdir="$TF_DIR" output -raw output_bucket)
SQS_QUEUE_URL=$(terraform -chdir="$TF_DIR" output -raw sqs_queue_url)
SQS_ENDPOINT=$(terraform -chdir="$TF_DIR" output -raw sqs_endpoint)
SQS_ACCESS_KEY=$(terraform -chdir="$TF_DIR" output -raw sqs_publisher_access_key)
SQS_SECRET_KEY=$(terraform -chdir="$TF_DIR" output -raw sqs_publisher_secret_key)

S3_ENDPOINT="https://s3.fr-par.scw.cloud"

# step 1: upload the image
echo "Uploading ${IMAGE_FILE} to s3://${INPUT_BUCKET}/${IMAGE_KEY}..."
aws s3 cp "$IMAGE_FILE" "s3://${INPUT_BUCKET}/${IMAGE_KEY}" \
  --endpoint-url "$S3_ENDPOINT"

# step 2: send the SQS notification (this is what S3 does natively on AWS)
echo "Sending SQS notification..."
AWS_ACCESS_KEY_ID="$SQS_ACCESS_KEY" \
AWS_SECRET_ACCESS_KEY="$SQS_SECRET_KEY" \
aws sqs send-message \
  --queue-url "$SQS_QUEUE_URL" \
  --message-body "{\"bucket\": \"${INPUT_BUCKET}\", \"key\": \"${IMAGE_KEY}\"}" \
  --endpoint-url "$SQS_ENDPOINT"

# step 3: poll for the thumbnail
echo "Waiting for thumbnail at s3://${OUTPUT_BUCKET}/${THUMB_KEY}..."
MAX_ATTEMPTS=30
for i in $(seq 1 $MAX_ATTEMPTS); do
  if aws s3api head-object \
    --bucket "$OUTPUT_BUCKET" \
    --key "$THUMB_KEY" \
    --endpoint-url "$S3_ENDPOINT" &>/dev/null; then
    echo "Thumbnail ready! Downloading..."
    aws s3 cp "s3://${OUTPUT_BUCKET}/${THUMB_KEY}" "./thumb_${IMAGE_KEY}" \
      --endpoint-url "$S3_ENDPOINT"
    echo "Saved to ./thumb_${IMAGE_KEY}"
    exit 0
  fi
  echo "  Attempt ${i}/${MAX_ATTEMPTS} - not ready yet..."
  sleep 2
done

echo "Timed out waiting for thumbnail."
exit 1
