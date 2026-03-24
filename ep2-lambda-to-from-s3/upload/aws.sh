#!/usr/bin/env bash
set -euo pipefail

# Usage: ./aws.sh <image-file>
# Requires: aws cli, terraform output from ../aws

if [ $# -lt 1 ]; then
  echo "Usage: $0 <image-file>"
  exit 1
fi

IMAGE_FILE="$1"
IMAGE_KEY="$(basename "$IMAGE_FILE")"
THUMB_KEY="thumbnails/${IMAGE_KEY}"

# read bucket names from terraform output
INPUT_BUCKET=$(terraform -chdir=../aws output -raw input_bucket)
OUTPUT_BUCKET=$(terraform -chdir=../aws output -raw output_bucket)

echo "Uploading ${IMAGE_FILE} to s3://${INPUT_BUCKET}/${IMAGE_KEY}..."
aws s3 cp "$IMAGE_FILE" "s3://${INPUT_BUCKET}/${IMAGE_KEY}"

echo "Waiting for thumbnail at s3://${OUTPUT_BUCKET}/${THUMB_KEY}..."
MAX_ATTEMPTS=30
for i in $(seq 1 $MAX_ATTEMPTS); do
  if aws s3api head-object --bucket "$OUTPUT_BUCKET" --key "$THUMB_KEY" &>/dev/null; then
    echo "Thumbnail ready! Downloading..."
    aws s3 cp "s3://${OUTPUT_BUCKET}/${THUMB_KEY}" "./thumb_${IMAGE_KEY}"
    echo "Saved to ./thumb_${IMAGE_KEY}"
    exit 0
  fi
  echo "  Attempt ${i}/${MAX_ATTEMPTS} - not ready yet..."
  sleep 2
done

echo "Timed out waiting for thumbnail."
exit 1
